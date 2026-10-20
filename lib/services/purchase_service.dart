import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/offline_maps.dart';
import '../config/test_mode.dart';

/// What happened to a purchase or restore, as reported by the store.
enum PurchaseEventType { purchased, pending, canceled, error }

class PurchaseEvent {
  const PurchaseEvent(this.type, {this.productId = PurchaseService.productId, this.message});
  final PurchaseEventType type;

  /// Which product this is about: [PurchaseService.productId] (Then & Now
  /// Plus) or [PurchaseService.offlineProductId] (Offline Maps).
  final String productId;

  /// Human-readable detail for [PurchaseEventType.error].
  final String? message;
}

/// Manages the app's one-time (non-consumable) purchases. The core app is
/// free; two separate upgrades can be bought:
///  - **Then & Now Plus** ([productId]): name stories & pronunciation, facts about airports, dams and passes,
///    recording / adding names.
///  - **Offline Maps** ([offlineProductId], higher price): download map
///    packs to use the map with no signal. Only offered when
///    [kOfflineMapsEnabled] is on (see lib/config/offline_maps.dart).
///
/// Uses the official `in_app_purchase` plugin, which talks to StoreKit
/// on iOS and Play Billing on Android through one API. This is the
/// correct/compliant way to sell digital unlocks inside an app on both
/// stores - a custom checkout (Stripe, PayPal, etc.) is not permitted
/// for this on iOS, and is generally against Play policy too.
///
/// IMPORTANT - this file alone is not enough to take real payments.
/// Before it will work you must:
///  1. Create the **non-consumable** in-app products in App Store Connect
///     and Google Play Console, using exactly the product IDs below.
///  2. Enable the "In-App Purchase" capability for the iOS target in
///     Xcode.
///  3. For production, verify each purchase receipt on your own server
///     before treating it as trusted - see the note in
///     [_onPurchaseUpdates]. This class only does the on-device check,
///     which is enough to get started/test with but can be bypassed.
/// Full walkthrough is in the README.
///
/// This is an app-lifetime singleton: it is never disposed, and [init]
/// is safe to call from any number of screens - the store listener is
/// only ever attached once.
class PurchaseService {
  PurchaseService._internal();
  static final PurchaseService instance = PurchaseService._internal();

  /// Then & Now Plus. Must exactly match the product ID in both stores.
  static const String productId = 'sa_town_names_full_unlock';

  /// Offline Maps. Must exactly match the product ID in both stores.
  static const String offlineProductId = 'sa_town_names_offline_maps';

  static const Map<String, String> _prefsKeys = {
    productId: 'has_purchased_full_unlock',
    offlineProductId: 'has_purchased_offline_maps',
  };

  /// How long [restore] waits for the store to report a previous
  /// purchase before concluding there isn't one.
  static const Duration restoreTimeout = Duration(seconds: 8);

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  Future<void>? _initFuture;
  final Map<String, Completer<bool>> _restoreCompleters = {};

  final _eventsController = StreamController<PurchaseEvent>.broadcast();

  /// Every store outcome (purchased, pending, cancelled, error), with
  /// [PurchaseEvent.productId] saying which product it's about.
  Stream<PurchaseEvent> get events => _eventsController.stream;

  final Map<String, ProductDetails> _products = {};

  /// Then & Now Plus product details (price etc.), once loaded.
  ProductDetails? get product => _products[productId];

  /// Offline Maps product details, once loaded.
  ProductDetails? get offlineProduct => _products[offlineProductId];

  /// Whether Then & Now Plus is unlocked on this phone. Screens listen to
  /// this so locked features open up the moment a purchase or restore
  /// succeeds.
  final ValueNotifier<bool> unlocked = ValueNotifier<bool>(false);
  bool get isPurchased => unlocked.value;

  /// Whether the Offline Maps add-on is unlocked on this phone.
  final ValueNotifier<bool> offlineUnlocked = ValueNotifier<bool>(false);
  bool get hasOfflineMaps => offlineUnlocked.value;

  ValueNotifier<bool> _notifierFor(String id) => id == offlineProductId ? offlineUnlocked : unlocked;

  /// The product IDs this build sells.
  Set<String> get _sellableIds => {productId, if (kOfflineMapsEnabled) offlineProductId};

  bool _storeAvailable = true;
  bool get storeAvailable => _storeAvailable;

  /// When [checkStore] last ran, so coming back to the app repeatedly
  /// doesn't query the store every few seconds.
  DateTime? _lastStoreCheck;
  static const Duration storeCheckGap = Duration(minutes: 2);

  /// Starts listening to the store, exactly once for the life of the app.
  /// Purchases made outside the app (a redeemed offer/promo code, a
  /// purchase approved later by a parent, one bought on another device)
  /// arrive on this stream.
  void _listen() {
    _subscription ??= _iap.purchaseStream.listen(
      _onPurchaseUpdates,
      onError: (Object e) {
        debugPrint('Purchase stream error: $e');
        _eventsController.add(PurchaseEvent(PurchaseEventType.error, message: '$e'));
      },
    );
  }

  /// Quietly checks with the store for purchases this phone doesn't know
  /// about yet - e.g. a founder who redeemed a free Plus code in the App
  /// Store or Play Store. Called when the app opens and each time it comes
  /// back to the foreground (at most every [storeCheckGap]). Never shows
  /// anything unless something new is unlocked, and never throws.
  ///
  /// - **iOS:** listening is enough. StoreKit hands the app any new
  ///   transaction (including redeemed offer codes) as soon as it's
  ///   listening. It deliberately does *not* call "restore" here, because
  ///   on iOS that can pop up an Apple ID sign-in, which would be odd
  ///   every time the app opens. ("Restore purchase" stays available.)
  /// - **Android:** Play only reports purchases made outside the app when
  ///   asked, so this asks (a silent query, no UI) - but only while
  ///   something is still locked.
  Future<void> checkStore() async {
    final now = DateTime.now();
    final last = _lastStoreCheck;
    if (last != null && now.difference(last) < storeCheckGap) return;
    _lastStoreCheck = now;
    try {
      if (!await _iap.isAvailable()) return;
      _storeAvailable = true;
      _listen();
      final stillLocked = _sellableIds.any((id) => !_notifierFor(id).value);
      if (stillLocked && defaultTargetPlatform == TargetPlatform.android) {
        await _iap.restorePurchases();
      }
    } catch (e) {
      debugPrint('Store check skipped: $e');
    }
  }

  /// Fast, local-only check (no store round-trip): what's cached from
  /// previous purchases or restores. Called at start-up.
  Future<bool> checkCachedPurchase() async {
    final prefs = await SharedPreferences.getInstance();
    unlocked.value = prefs.getBool(_prefsKeys[productId]!) ?? false;
    offlineUnlocked.value = prefs.getBool(_prefsKeys[offlineProductId]!) ?? false;
    if (kTestPlus) {
      final test = prefs.getBool(_testPlusKey);
      if (test != null) unlocked.value = test;
    }
    return unlocked.value;
  }

  static const _testPlusKey = 'test_plus_unlocked';

  /// Test builds only (see lib/config/test_mode.dart): switches Plus on or
  /// off without the store, and remembers it between launches. Does
  /// nothing in normal builds.
  Future<void> setTestPlus(bool on) async {
    if (!kTestPlus) return;
    unlocked.value = on;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_testPlusKey, on);
  }

  /// Connects to the store, loads the products/prices and asks the store
  /// for any earlier purchase. Idempotent: concurrent and repeated calls
  /// share one run. If the run fails, or the store was unreachable, the
  /// next call tries again.
  Future<void> init() {
    final existing = _initFuture;
    if (existing != null) return existing;
    final run = _doInit();
    _initFuture = run;
    run.then((_) {
      if (!_storeAvailable || product == null) _initFuture = null;
    }, onError: (Object _) {
      _initFuture = null;
    });
    return run;
  }

  Future<void> _doInit() async {
    await checkCachedPurchase();

    _storeAvailable = await _iap.isAvailable();
    if (!_storeAvailable) return;

    _listen();

    final response = await _iap.queryProductDetails(_sellableIds);
    if (response.notFoundIDs.isNotEmpty) {
      debugPrint('Product not found in store: ${response.notFoundIDs}. '
          'Check the product IDs match App Store Connect / Play Console exactly.');
    }
    for (final details in response.productDetails) {
      _products[details.id] = details;
    }

    // Ask the store what's already been bought - covers reinstalls and
    // new devices where the local flags above are gone but the purchases
    // are still valid. Any hit arrives via the purchase stream.
    final missing = _sellableIds.where((id) => !_notifierFor(id).value);
    if (missing.isNotEmpty) {
      await _iap.restorePurchases();
    }
  }

  /// Starts the platform purchase sheet for [id] (Then & Now Plus by
  /// default). The outcome arrives asynchronously on [events] - the store
  /// UI can take any amount of time (Face ID, parental approval, etc.).
  Future<void> buy({String id = productId}) async {
    await init();
    final details = _products[id];
    if (details == null) {
      throw StateError('Product details not loaded - is the store reachable and the product configured?');
    }
    final started = await _iap.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: details));
    if (!started) {
      throw StateError('The store did not accept the purchase request.');
    }
  }

  /// Asks the store for earlier purchases and waits (up to
  /// [restoreTimeout]) for [id] to come back. Returns true if [id] is now
  /// unlocked. Other products restored along the way unlock too.
  ///
  /// The store's own `restorePurchases()` returns before any restored
  /// purchase has been delivered, and sends nothing at all when there is
  /// no purchase - so the only way to tell "nothing to restore" apart
  /// from "not delivered yet" is to wait a bounded time.
  Future<bool> restore({String id = productId}) async {
    final notifier = _notifierFor(id);
    if (notifier.value) return true;
    await init();
    if (notifier.value) return true;
    if (!_storeAvailable) return false;

    final completer = _restoreCompleters[id] ??= Completer<bool>();
    await _iap.restorePurchases();
    final restored = await completer.future.timeout(restoreTimeout, onTimeout: () => notifier.value);
    if (identical(_restoreCompleters[id], completer)) _restoreCompleters.remove(id);
    return restored;
  }

  Future<void> _onPurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      final id = purchase.productID;
      if (!_prefsKeys.containsKey(id)) continue;

      switch (purchase.status) {
        case PurchaseStatus.pending:
          _eventsController.add(PurchaseEvent(PurchaseEventType.pending, productId: id));
          break;
        case PurchaseStatus.error:
          debugPrint('Purchase error: ${purchase.error}');
          _eventsController.add(PurchaseEvent(
            PurchaseEventType.error,
            productId: id,
            message: purchase.error?.message ?? 'The purchase could not be completed.',
          ));
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          // Production apps should send purchase.verificationData to
          // their own backend and verify it against Apple/Google's
          // servers before unlocking anything of real value - this
          // on-device check is sufficient to ship an MVP with but can
          // be spoofed on a compromised device.
          await _markPurchased(id);
          break;
        case PurchaseStatus.canceled:
          _eventsController.add(PurchaseEvent(PurchaseEventType.canceled, productId: id));
          break;
      }

      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
  }

  Future<void> _markPurchased(String id) async {
    final notifier = _notifierFor(id);
    final wasPurchased = notifier.value;
    notifier.value = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKeys[id]!, true);
    final completer = _restoreCompleters[id];
    if (completer != null && !completer.isCompleted) completer.complete(true);
    // Restores can deliver the same purchase more than once; only
    // announce the unlock the first time.
    if (!wasPurchased) {
      _eventsController.add(PurchaseEvent(PurchaseEventType.purchased, productId: id));
    }
  }
}
