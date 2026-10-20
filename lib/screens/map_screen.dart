import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_map_mbtiles/flutter_map_mbtiles.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_info.dart';
import '../config/map_tiles.dart';
import '../config/offline_maps.dart';
import '../config/test_mode.dart';
import '../models/map_outline.dart';
import '../models/name_story.dart';
import '../models/place_facts.dart';
import '../models/town.dart';
import '../services/app_update_service.dart';
import '../services/database_helper.dart';
import '../services/location_service.dart';
import '../services/offline_maps_service.dart';
import '../services/purchase_service.dart';
import '../services/remote_data_service.dart';
import '../utils/nearest_town.dart';
import '../utils/refresh_time.dart';
import '../widgets/app_promo_card.dart';
import '../widgets/map_attribution.dart';
import '../widgets/name_story_section.dart';
import '../widgets/dam_level_tile.dart';
import '../widgets/place_facts_section.dart';
import '../widgets/plus_teaser.dart';
import '../widgets/scroll_more_hint.dart';
import '../widgets/share_card.dart';
import '../widgets/timeline_panel.dart';
import '../widgets/where_am_i_sheet.dart';
import 'about_screen.dart';
import 'edit_town_sheet.dart';
import 'offline_maps_screen.dart';
import 'paywall_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  // Roughly centres South Africa on first load.
  static const LatLng _southAfricaCenter = LatLng(-29.0, 24.5);
  static const double _initialZoom = 5.2;

  final MapController _mapController = MapController();

  /// Glides the map back to the opening view (all of South Africa).
  late final AnimationController _homeAnimation =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 600));

  void _zoomToStart() {
    final camera = _mapController.camera;
    final from = camera.center;
    final fromZoom = camera.zoom;
    final curve = CurvedAnimation(parent: _homeAnimation, curve: Curves.easeInOut);
    void step() {
      final t = curve.value;
      _mapController.move(
        LatLng(
          from.latitude + (_southAfricaCenter.latitude - from.latitude) * t,
          from.longitude + (_southAfricaCenter.longitude - from.longitude) * t,
        ),
        fromZoom + (_initialZoom - fromZoom) * t,
      );
    }

    _homeAnimation
      ..stop()
      ..reset();
    curve.addListener(step);
    _homeAnimation.forward().whenCompleteOrCancel(() {
      curve.removeListener(step);
      curve.dispose();
    });
  }

  /// Background map tiles, chosen at build time (see lib/config/map_tiles.dart).
  final MapTileSource _tiles = MapTileSource.fromEnvironment();

  /// Created once and reused across rebuilds (the TileLayer disposes it
  /// with the map). flutter_map's built-in cache stores tiles on the
  /// device, which the OpenStreetMap tile policy requires and which saves
  /// mobile data when people pan back over areas they've already seen.
  late final NetworkTileProvider _tileProvider = NetworkTileProvider(
    cachingProvider: BuiltInMapCachingProvider.getOrCreateInstance(
      maxCacheSize: 200 * 1000 * 1000, // 200 MB; flutter_map's default is 1 GB
    ),
  );

  List<Town> _towns = [];

  /// Bumped whenever [_towns] changes (loaded, edited, added, removed), so
  /// the cached map markers know to rebuild.
  int _townsRevision = 0;

  /// The town markers, built once and reused until something they show
  /// changes. Rebuilding ~1,000 markers on every screen update made the
  /// cluster layer regroup them all each time, which is slow on
  /// entry-level phones.
  List<Marker> _markers = const [];
  (int, bool, PlaceFilter, bool, int?)? _markersKey;

  List<Marker> _currentMarkers() {
    final key = (_townsRevision, _renamedOnly, _placeFilter, _showOldNames && _isPlus, _timelineYear);
    if (key != _markersKey) {
      _markersKey = key;
      _markers = _visibleTowns.map(_buildMarker).toList(growable: false);
    }
    return _markers;
  }

  /// Name stories and pronunciation guides, keyed by town key.
  Map<String, NameStory> _stories = const {};

  /// Facts about airports, dams and passes (Plus), keyed by place key.
  Map<String, PlaceFacts> _facts = const {};

  /// Where each dam's weekly level is published (Plus), keyed by dam key.
  Map<String, DamStation> _damStations = const {};

  /// Province/neighbour outline drawn under the tiles (shows where tiles
  /// can't load). Empty until loaded; the map works without it.
  List<Polygon> _outline = const [];

  Future<void> _loadOutline() async {
    try {
      final outline = await MapOutline.load();
      if (mounted) setState(() => _outline = outline.polygons);
    } catch (e) {
      debugPrint('Could not load map outline: $e');
    }
  }

  /// Offline Maps add-on: downloaded packs drawn over the online tiles,
  /// each with its own tile provider (created once per load, because the
  /// TileLayer closes its provider when it goes away). [_packGeneration]
  /// changes with every reload so layers and providers are replaced together.
  List<InstalledPack> _offlinePacks = const [];
  Map<String, MbTilesTileProvider> _packProviders = const {};
  int _packGeneration = 0;

  Future<void> _loadOfflinePacks() async {
    if (!kOfflineMapsEnabled) return;
    final service = OfflineMapsService.instance;
    final packs = PurchaseService.instance.hasOfflineMaps && await service.useOffline()
        ? await service.installed()
        : const <InstalledPack>[];
    if (!mounted) return;
    setState(() {
      _packGeneration++;
      _offlinePacks = packs;
      _packProviders = {
        for (final p in packs) p.pack.id: MbTilesTileProvider.fromPath(path: p.path, silenceTileNotFound: true),
      };
    });
  }

  void _onOfflineChanged() => _loadOfflinePacks();

  Future<void> _openOfflineMaps() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (context) => const OfflineMapsScreen()));
    await _loadOfflinePacks();
  }

  /// Map credits: the tile provider's, plus those of any offline packs in use.
  List<TileCredit> get _credits {
    final credits = [..._tiles.credits];
    for (final p in _offlinePacks) {
      if (!credits.any((c) => c.text == p.pack.attribution)) {
        credits.add(TileCredit(p.pack.attribution, 'https://www.openstreetmap.org/copyright'));
      }
    }
    return credits;
  }

  /// For the "last refreshed" indicator (⋮ menu and About screen).
  DateTime? _lastRefreshed;
  int _dataVersion = 0;
  bool _loading = true;
  String? _loadingError;

  /// false = showing current names, true = showing previous names.
  bool _showOldNames = false;

  /// "Renamed towns only" filter - hides places with no name change on
  /// record. The app always opens with it on (testers' request), so the
  /// first thing people see is what the app is about.
  bool _renamedOnly = true;

  /// Which kinds of place are on the map. The app always opens with all.
  PlaceFilter _placeFilter = PlaceFilter.all;

  /// The places currently on the map (search and "Where am I?" still use
  /// every place).
  List<Town> get _visibleTowns =>
      _towns.where((t) => _placeFilter.includes(t) && (!_renamedOnly || t.hasKnownRename)).toList();

  void _setRenamedOnly(bool value) => setState(() => _renamedOnly = value);

  /// Whether the person has tapped "Got it" in Help. Until then a flashing
  /// reminder sits in the middle of the map (testers kept asking things the
  /// Help answers). Starts true so the reminder doesn't flash up before the
  /// saved answer has loaded.
  bool _helpRead = true;
  static const _helpReadKey = 'help_read';

  /// Set when Help was opened but closed without "Got it". Help then opens
  /// by itself the next time the app is opened, until "Got it" is tapped.
  bool _helpOpenedUnread = false;
  static const _helpOpenedKey = 'help_opened_unread';

  /// So Help is never stacked on top of itself.
  bool _helpShowing = false;

  /// When the app last went to the background (see [didChangeAppLifecycleState]).
  DateTime? _backgroundedAt;

  /// Away at least this long counts as closing and reopening the app.
  static const _reopenAfter = Duration(minutes: 1);

  Future<void> _loadHelpRead() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final read = prefs.getBool(_helpReadKey) ?? false;
      _helpOpenedUnread = !read && (prefs.getBool(_helpOpenedKey) ?? false);
      if (mounted && read != _helpRead) setState(() => _helpRead = read);
      // Opened before but never "Got it": open it again now the app has
      // been reopened (once the first screen is drawn).
      if (_helpOpenedUnread) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showHelp();
        });
      }
    } catch (_) {
      // Can't tell - better not to nag.
    }
  }

  Future<void> _markHelpOpened() async {
    if (_helpRead || _helpOpenedUnread) return;
    _helpOpenedUnread = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_helpOpenedKey, true);
    } catch (_) {}
  }

  Future<void> _markHelpRead() async {
    _helpOpenedUnread = false;
    if (!_helpRead) setState(() => _helpRead = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_helpReadKey, true);
      await prefs.remove(_helpOpenedKey);
    } catch (_) {}
  }

  /// Android often keeps the app in memory when it's "closed", so coming
  /// back after a while counts as reopening it too. Short trips away (the
  /// share sheet, the store's payment screen) don't.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _backgroundedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final away = _backgroundedAt == null ? Duration.zero : DateTime.now().difference(_backgroundedAt!);
      _backgroundedAt = null;
      if (away >= _reopenAfter && !_helpRead && _helpOpenedUnread && !_helpShowing && mounted) {
        _showHelp();
      }
    }
  }

  void _setPlaceFilter(PlaceFilter value) => setState(() => _placeFilter = value);

  /// The person's position from the last "Where am I?" (shown as a blue
  /// dot), and whether a lookup is in progress.
  LatLng? _myLocation;
  bool _locating = false;

  /// Timeline: the year the map shows, or null when the timeline is closed
  /// (then the plain old/current toggle applies). [_timelineStart] is the
  /// "Then" stop; the last stop is this year ("Today").
  static const int _timelineStart = 1993;
  final int _todayYear = DateTime.now().year;
  int? _timelineYear;
  Timer? _playTimer;

  @override
  void initState() {
    super.initState();
    MapTileSource.warnIfPlaceholderAppId();
    WidgetsBinding.instance.addObserver(this);
    _loadHelpRead();
    // A newer version on Google Play? Asked a little after opening, so it
    // doesn't pop up while the map and Help are still appearing.
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) AppUpdateService.checkForUpdate(ScaffoldMessenger.of(context));
    });
    _loadOutline();
    _loadTowns();
    _loadOfflinePacks();
    PurchaseService.instance.unlocked.addListener(_onPlusChanged);
    PurchaseService.instance.offlineUnlocked.addListener(_onOfflineChanged);
    OfflineMapsService.instance.changes.addListener(_onOfflineChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _homeAnimation.dispose();
    _playTimer?.cancel();
    PurchaseService.instance.unlocked.removeListener(_onPlusChanged);
    PurchaseService.instance.offlineUnlocked.removeListener(_onOfflineChanged);
    OfflineMapsService.instance.changes.removeListener(_onOfflineChanged);
    super.dispose();
  }

  /// Whether Then & Now Plus is unlocked: previous names (the map toggle,
  /// a town's old name, the timeline's "Then", old-name search,
  /// share cards), name stories & pronunciation, recording and adding names.
  bool get _isPlus => PurchaseService.instance.isPurchased;

  /// The timeline's first year: "Then" with Plus, the year after without.
  int get _timelineFirst => _isPlus ? _timelineStart : _timelineStart + 1;

  /// Plus as it was last time we looked, to spot the moment it unlocks -
  /// from the Plus screen, a restore, or a code redeemed in the store.
  late bool _wasPlus = PurchaseService.instance.isPurchased;

  void _onPlusChanged() {
    if (!mounted) return;
    final nowPlus = _isPlus;
    if (nowPlus && !_wasPlus) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('$kPlusName is unlocked - thank you!')),
      );
    }
    _wasPlus = nowPlus;
    setState(() {
      // If Plus goes away (e.g. a refunded purchase), drop back to what's free.
      if (!nowPlus) {
        _showOldNames = false;
        final year = _timelineYear;
        if (year != null && year < _timelineFirst) _timelineYear = _timelineFirst;
      }
    });
  }

  Future<void> _openPaywall() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PaywallScreen(
          dismissible: true,
          // The "unlocked" message comes from _onPlusChanged.
          onUnlocked: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  Future<void> _loadTowns() async {
    try {
      await DatabaseHelper.instance.reseedIfNeeded();
      await _readTownsAndStories();
      if (!mounted) return;
      setState(() => _loading = false);
      // Quietly check for newer town data about once a week - a little
      // later, so downloading and checking it doesn't slow down the first
      // seconds of using the map on slower phones.
      Future.delayed(const Duration(seconds: 10), () {
        if (mounted) unawaited(_autoRefresh());
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingError = 'Could not load town data: $e';
        _loading = false;
      });
    }
  }

  /// (Re)reads towns from the database and name stories (from the last
  /// downloaded update if newer, otherwise the bundled ones).
  Future<void> _readTownsAndStories() async {
    final towns = await DatabaseHelper.instance.getAllTowns();
    // Stories are extra: if they fail to load, the map still works.
    Map<String, NameStory> stories = const {};
    try {
      stories = await RemoteDataService.instance.cachedStoriesIfNewer() ?? await NameStory.loadAll();
    } catch (e) {
      debugPrint('Could not load name stories: $e');
    }
    // Facts are extra too.
    Map<String, PlaceFacts> facts = const {};
    try {
      facts = await RemoteDataService.instance.cachedFactsIfNewer() ?? await PlaceFacts.loadAll();
    } catch (e) {
      debugPrint('Could not load place facts: $e');
    }
    Map<String, DamStation> damStations = const {};
    try {
      damStations = await RemoteDataService.instance.cachedDamStationsIfNewer() ?? await DamStation.loadAll();
    } catch (e) {
      debugPrint('Could not load dam stations: $e');
    }
    final lastRefreshed = await RemoteDataService.instance.lastRefreshed();
    final dataVersion = await DatabaseHelper.instance.dataVersion();
    if (!mounted) return;
    setState(() {
      _towns = towns;
      _townsRevision++;
      _stories = stories;
      _facts = facts;
      _damStations = damStations;
      _lastRefreshed = lastRefreshed;
      _dataVersion = dataVersion;
    });
  }

  /// Re-reads only the refresh time and data version (after a check that
  /// found nothing new).
  Future<void> _readRefreshInfo() async {
    final lastRefreshed = await RemoteDataService.instance.lastRefreshed();
    final dataVersion = await DatabaseHelper.instance.dataVersion();
    if (!mounted) return;
    setState(() {
      _lastRefreshed = lastRefreshed;
      _dataVersion = dataVersion;
    });
  }

  Future<void> _autoRefresh() async {
    final result = await RemoteDataService.instance.autoRefreshIfDue();
    if (!mounted) return;
    if (result == null) {
      // A quiet check may still have succeeded with nothing new.
      await _readRefreshInfo();
      return;
    }
    await _readTownsAndStories();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Town names have been updated.'),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(label: "What's new", onPressed: () => _showWhatsNew(result)),
      ),
    );
  }

  bool _refreshing = false;

  /// "Refresh data" from the menu.
  Future<void> _refreshData() async {
    if (_refreshing) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _refreshing = true);
    messenger.showSnackBar(const SnackBar(
      content: Text('Checking for town name updates…'),
      duration: Duration(seconds: 30),
    ));
    final result = await RemoteDataService.instance.refresh();
    if (result.status == RefreshStatus.updated) {
      await _readTownsAndStories();
    } else {
      await _readRefreshInfo();
    }
    if (!mounted) return;
    setState(() => _refreshing = false);
    messenger.hideCurrentSnackBar();
    switch (result.status) {
      case RefreshStatus.updated:
        _showWhatsNew(result);
        break;
      case RefreshStatus.upToDate:
        messenger.showSnackBar(SnackBar(
          content: Text('You have the latest town names (data version ${result.version}).'),
        ));
        break;
      case RefreshStatus.failed:
        messenger.showSnackBar(SnackBar(content: Text(result.message ?? 'Could not check for updates.')));
        break;
    }
  }

  void _showWhatsNew(RefreshResult result) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Town names updated'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (result.changes.isEmpty)
                const Text('The map now has the latest town names.')
              else
                for (final change in result.changes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('•  '),
                        Expanded(child: Text(change)),
                      ],
                    ),
                  ),
              const SizedBox(height: 4),
              Text(
                'Data version ${result.version}. Towns you edited or added yourself were not changed.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
        ],
      ),
    );
  }

  /// The name story for [town], if there is one and it still matches the
  /// town's current name (a user may have renamed it since).
  /// Facts for an airport, dam or pass (towns have none).
  PlaceFacts? _factsFor(Town town) => town.isTown || town.sourceKey == null ? null : _facts[town.sourceKey];

  /// Where a dam's weekly level is published, if it's in the weekly report.
  DamStation? _damStationFor(Town town) =>
      town.kind != 'dam' || town.sourceKey == null ? null : _damStations[town.sourceKey];

  NameStory? _storyFor(Town town) {
    final key = town.sourceKey;
    if (key == null) return null;
    final story = _stories[key];
    if (story == null || story.name != town.currentName) return null;
    return story;
  }

  /// The label a town shows right now: by timeline year when the
  /// timeline is open, otherwise by the old/current toggle.
  String _labelFor(Town town) {
    final year = _timelineYear;
    if (year != null) return town.nameInYear(year, todayYear: _todayYear);
    return town.displayName(_showOldNames && _isPlus);
  }

  /// Whether [town] is currently showing its old name (decides which name
  /// the town sheet leads with).
  bool _isShowingOldName(Town town) => town.hasDifferentOldName && _labelFor(town) == town.oldName;

  void _openTimeline() {
    setState(() => _timelineYear = _timelineFirst);
  }

  void _closeTimeline() {
    _stopPlaying();
    setState(() => _timelineYear = null);
  }

  void _setTimelineYear(int year) {
    _stopPlaying();
    setState(() => _timelineYear = year);
  }

  void _stopPlaying() {
    _playTimer?.cancel();
    _playTimer = null;
  }

  void _togglePlay() {
    if (_playTimer != null) {
      setState(_stopPlaying);
      return;
    }
    // Start from the beginning if we're already at "Today".
    if ((_timelineYear ?? _timelineFirst) >= _todayYear) _timelineYear = _timelineFirst;
    setState(() {});
    _playTimer = Timer.periodic(const Duration(milliseconds: 700), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final next = (_timelineYear ?? _timelineFirst) + 1;
      setState(() {
        _timelineYear = next;
        if (next >= _todayYear) _stopPlaying();
      });
    });
  }

  /// Renames with a known year that had happened by [year].
  int _renamedBy(int year) =>
      _towns.where((t) => t.hasDifferentOldName && t.renamedYear != null && t.renamedYear! <= year).length;

  /// The "Show previous names" button. Part of Plus: without it, the
  /// button opens the Plus screen.
  void _toggleNameMode() {
    if (!_isPlus) {
      _openPaywall();
      return;
    }
    setState(() => _showOldNames = !_showOldNames);
  }

  /// "Where am I?": find the person's town and tell them its old name.
  Future<void> _whereAmI() async {
    if (_locating || _loading || _towns.isEmpty) return;
    setState(() => _locating = true);
    final outcome = await LocationService.currentLocation();
    if (!mounted) return;
    setState(() => _locating = false);

    if (!outcome.isFound) {
      _showLocationProblem(outcome.problem!);
      return;
    }

    final here = LatLng(outcome.latitude!, outcome.longitude!);
    // Only towns - you're "in" a town, not in an airport or a dam.
    final result = findWhereAmI(_towns.where((t) => t.isTown).toList(), here.latitude, here.longitude);
    if (result == null) return;

    setState(() => _myLocation = here);
    if (result.proximity != Proximity.outsideSouthAfrica) {
      _mapController.move(here, 11);
    }

    final town = await showModalBottomSheet<Town>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => WhereAmISheet(
        result: result,
        story: _storyFor(result.nearest.town),
        isPlus: _isPlus,
        onGetPlus: _openPaywall,
      ),
    );
    if (town != null && mounted) _goToTown(town);
  }

  void _showLocationProblem(LocationProblem problem) {
    final messenger = ScaffoldMessenger.of(context);
    final SnackBar snackBar;
    switch (problem) {
      case LocationProblem.serviceDisabled:
        snackBar = const SnackBar(
          content: Text('Location is switched off on this phone.'),
          action: SnackBarAction(label: 'Turn on', onPressed: LocationService.openLocationSettings),
        );
        break;
      case LocationProblem.denied:
        snackBar = const SnackBar(
          content: Text("Allow location access to see which town you're in. "
              'Your location stays on this phone.'),
        );
        break;
      case LocationProblem.deniedForever:
        snackBar = const SnackBar(
          content: Text('Location access is turned off for this app.'),
          action: SnackBarAction(label: 'Settings', onPressed: LocationService.openAppSettings),
        );
        break;
      case LocationProblem.unavailable:
        snackBar = const SnackBar(
          content: Text("Couldn't find your location just now. Please try again in a moment."),
        );
        break;
    }
    messenger.showSnackBar(snackBar);
  }

  void _goToTown(Town town) {
    _mapController.move(LatLng(town.latitude, town.longitude), 12);
    _onTownTap(town);
  }

  Future<void> _onTownTap(Town town) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      // Lets the sheet grow to fit its content (up to 85% of the screen)
      // instead of stopping at about half, so facts aren't hidden below.
      isScrollControlled: true,
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
      // The grab bar shows it can be swiped down to close.
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _TownDetailSheet(
        town: town,
        showOldNames: _isShowingOldName(town),
        story: _storyFor(town),
        facts: _factsFor(town),
        damStation: _damStationFor(town),
        isPlus: _isPlus,
      ),
    );

    if (action == 'plus' && mounted) {
      await _openPaywall();
      return;
    }
    if (action == 'share' && mounted) {
      // Shared info shows the old name, so sharing is part of Plus too.
      if (!_isPlus) {
        await _openPaywall();
      } else {
        // The same info, the same way round, as the sheet just showed.
        await showShareCard(context,
            town: town, story: _storyFor(town), facts: _factsFor(town), showOldNames: _isShowingOldName(town));
      }
      return;
    }
    if (action == 'edit' && mounted && !_isPlus) {
      await _openPaywall();
      return;
    }
    if (action == 'edit' && mounted) {
      final result = await showEditRenameSheet(context, existingTown: town);
      if (result == null || !mounted) return;
      setState(() {
        if (result.deleted) {
          _towns.removeWhere((t) => t.id == town.id);
          _townsRevision++;
        } else if (result.town != null) {
          final idx = _towns.indexWhere((t) => t.id == result.town!.id);
          if (idx != -1) _towns[idx] = result.town!;
          _townsRevision++;
        }
      });
    }
  }

  Future<void> _handleLongPress(LatLng point) async {
    // Adding places is part of Plus.
    if (!_isPlus) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Adding missing places is part of $kPlusName.'),
        action: SnackBarAction(label: 'Learn more', onPressed: _openPaywall),
      ));
      return;
    }
    final added = await showAddNewTownSheet(context, latitude: point.latitude, longitude: point.longitude);
    if (added == null || !mounted) return;
    setState(() {
      _towns.add(added);
      _townsRevision++;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added ${added.currentName}')),
    );
  }

  void _openAbout() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AboutScreen(
          tileSource: _tiles,
          lastRefreshed: _lastRefreshed,
          dataVersion: _dataVersion,
        ),
      ),
    );
  }

  Future<void> _showHelp() async {
    if (_helpShowing) return;
    _helpShowing = true;
    _markHelpOpened();
    // "Got it" is the only way out: tapping outside or the back button do
    // nothing, so nobody closes Help by accident and then wonders why it
    // keeps coming back. The button stays in view below the scrolling text.
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Help'),
          content: ScrollWithMoreHint(
            fadeColor: Theme.of(context).colorScheme.surfaceContainerHigh,
            child: const _HelpText(),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          actions: [
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  _markHelpRead();
                },
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Got it – start using the app'),
              ),
            ),
          ],
        ),
      ),
    );
    _helpShowing = false;
  }

  @override
  Widget build(BuildContext context) {
    final visibleCount = _visibleTowns.length;
    return Scaffold(
      appBar: AppBar(
        // Test builds (TEST_PLUS) stand out, so one is never mistaken for a
        // real build.
        title: const Text(kTestPlus ? '$kAppShortName · TEST' : kAppShortName),
        backgroundColor: kTestPlus ? Colors.orange.shade300 : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share this app',
            onPressed: () => showAppPromo(context),
          ),
          IconButton(
            icon: Icon(_timelineYear == null ? Icons.timeline : Icons.timeline_outlined),
            tooltip: _timelineYear == null ? 'Timeline' : 'Close timeline',
            isSelected: _timelineYear != null,
            onPressed: _loading ? null : (_timelineYear == null ? _openTimeline : _closeTimeline),
          ),
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search towns',
            onPressed: _loading
                ? null
                : () async {
                    final result = await showSearch<Object?>(
                      context: context,
                      delegate: _TownSearchDelegate(_towns, isPlus: _isPlus),
                    );
                    if (result == _TownSearchDelegate.getPlus) {
                      _openPaywall();
                    } else if (result is Town) {
                      _goToTown(result);
                    }
                  },
          ),
          PopupMenuButton<String>(
            tooltip: isRefreshStale(_lastRefreshed, DateTime.now()) ? 'More (town names need a refresh)' : 'More',
            // A small dot when the town data hasn't been refreshed for a month.
            icon: Badge(
              isLabelVisible: !_loading && isRefreshStale(_lastRefreshed, DateTime.now()),
              smallSize: 8,
              child: const Icon(Icons.more_vert),
            ),
            onSelected: (value) {
              if (value == 'refresh') _refreshData();
              if (value == 'plus') _openPaywall();
              if (value == 'offline') _openOfflineMaps();
              if (value == 'help') _showHelp();
              if (value == 'about') _openAbout();
              if (value == 'test-plus') PurchaseService.instance.setTestPlus(!_isPlus);
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'refresh',
                child: _RefreshMenuTile(lastRefreshed: _lastRefreshed, refreshing: _refreshing),
              ),
              PopupMenuItem(
                value: 'plus',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.workspace_premium_outlined),
                  title: const Text(kPlusName),
                  subtitle: Text(_isPlus ? 'Unlocked - thank you!' : 'Previous names, name stories, record & add names'),
                ),
              ),
              if (kOfflineMapsEnabled)
                PopupMenuItem(
                  value: 'offline',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.download_for_offline_outlined),
                    title: const Text(kOfflineName),
                    subtitle: Text(
                      PurchaseService.instance.hasOfflineMaps
                          ? '${_offlinePacks.length} pack(s) in use'
                          : 'Use the map with no signal',
                    ),
                  ),
                ),
              const PopupMenuItem(
                value: 'help',
                child: ListTile(leading: Icon(Icons.help_outline), title: Text('Help'), contentPadding: EdgeInsets.zero),
              ),
              const PopupMenuItem(
                value: 'about',
                child: ListTile(
                    leading: Icon(Icons.info_outline), title: Text('About & credits'), contentPadding: EdgeInsets.zero),
              ),
              if (kTestPlus)
                PopupMenuItem(
                  value: 'test-plus',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(_isPlus ? Icons.toggle_on : Icons.toggle_off, color: Colors.orange.shade800),
                    title: Text('TEST: Plus is ${_isPlus ? 'ON' : 'OFF'}'),
                    subtitle: Text('Tap to switch Plus ${_isPlus ? 'off' : 'on'} (test builds only)'),
                  ),
                ),
            ],
          ),
        ],
      ),
      // The map shows straight away (so tiles start loading) and the towns
      // appear on it as soon as they're read.
      body: _loadingError != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_loadingError!)))
              : Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _southAfricaCenter,
                        // Sea colour behind the outline, for areas without tiles.
                        backgroundColor: MapOutline.seaColour,
                        initialZoom: _initialZoom,
                        minZoom: 4,
                        maxZoom: 18,
                        // Drag, pinch, scroll and double-tap to move and
                        // zoom - but no two-finger rotation: it was easy to
                        // turn the map by accident while pinching, so the
                        // map always stays north-up.
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                        ),
                        onLongPress: (tapPosition, point) => _handleLongPress(point),
                      ),
                      children: [
                        // Drawn first, so loaded tiles cover it: it only shows
                        // where tiles are missing (offline, never viewed).
                        if (_outline.isNotEmpty) PolygonLayer(polygons: _outline, polygonCulling: true),
                        // Raster tiles (OpenStreetMap-based) - already render
                        // roads, rivers, and topography for the whole country.
                        TileLayer(
                          urlTemplate: _tiles.urlTemplate,
                          additionalOptions: _tiles.additionalOptions,
                          maxNativeZoom: _tiles.maxNativeZoom,
                          userAgentPackageName: kAppId,
                          tileProvider: _tileProvider,
                          // While the map glides (e.g. after tapping a
                          // cluster), only fetch tiles a few times a second
                          // instead of for every frame and every in-between
                          // zoom level - much lighter on slow phones and
                          // slow connections.
                          tileUpdateTransformer: TileUpdateTransformers.throttle(const Duration(milliseconds: 150)),
                        ),
                        // Offline Maps add-on: downloaded packs on top of the
                        // online tiles (overview packs first, detailed last).
                        for (final p in _offlinePacks)
                          if (_packProviders[p.pack.id] != null)
                            TileLayer(
                              key: ValueKey('pack-${p.pack.id}-${p.pack.version}-$_packGeneration'),
                              tileProvider: _packProviders[p.pack.id]!,
                              minNativeZoom: p.pack.minZoom,
                              maxNativeZoom: p.pack.maxZoom,
                              // Shown from the pack's first zoom level to two
                              // levels past its last (enlarged), so zooming in
                              // further switches to sharper online/cached tiles
                              // instead of a blurry overview stretched to fit.
                              minZoom: p.pack.minZoom.toDouble(),
                              maxZoom: (p.pack.maxZoom + 2).toDouble(),
                              tileBounds: p.pack.bounds == null
                                  ? null
                                  : LatLngBounds(
                                      LatLng(p.pack.bounds![1], p.pack.bounds![0]),
                                      LatLng(p.pack.bounds![3], p.pack.bounds![2]),
                                    ),
                              userAgentPackageName: kAppId,
                            ),
                        MarkerClusterLayerWidget(
                          options: MarkerClusterLayerOptions(
                            maxClusterRadius: 60,
                            disableClusteringAtZoom: 11,
                            size: const Size(42, 42),
                            // Lighter on entry-level phones: no outline
                            // drawn around a tapped cluster, shorter zoom and
                            // split animations, and tapping a pin opens its
                            // details without first sliding the map.
                            showPolygon: false,
                            centerMarkerOnClick: false,
                            // Tapping a circle zooms to fit its places. The
                            // package's defaults (no margin, up to zoom 17)
                            // zoomed so far that two places sat right at the
                            // screen edges, under the banner, filters and
                            // buttons. Keep clear of those (each pin with its
                            // label is 140 x 60), and stop at town level:
                            // circles split up from zoom 11 anyway.
                            padding: const EdgeInsets.fromLTRB(80, 170, 80, 130),
                            maxZoom: 13,
                            animationsOptions: const AnimationsOptions(
                              zoom: Duration(milliseconds: 250),
                              fitBound: Duration(milliseconds: 350),
                              spiderfy: Duration(milliseconds: 250),
                            ),
                            markers: _loading ? const [] : _currentMarkers(),
                            builder: (context, markers) => CircleAvatar(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              child: Text(
                                '${markers.length}',
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ),
                          ),
                        ),
                        // Drawn last so it sits on top of town pins.
                        if (_myLocation != null)
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: _myLocation!,
                                width: 22,
                                height: 22,
                                child: Semantics(
                                  label: 'Your location',
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade600,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 3),
                                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    Positioned(
                      top: 12,
                      left: 12,
                      right: 12,
                      child: _loading
                          ? const _LoadingBanner()
                          : _NameModeBanner(
                              showOldNames: _showOldNames && _isPlus,
                              townCount: visibleCount,
                              timelineYear: _timelineYear,
                              timelineStart: _timelineStart,
                              todayYear: _todayYear,
                            ),
                    ),
                    // Left of the zoom-out button; on narrow phones the
                    // second filter drops to a row of its own.
                    Positioned(
                      top: 60,
                      left: 12,
                      right: 64,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilterChip(
                            label: Text(_placeFilter.renamedOnlyLabel),
                            selected: _renamedOnly,
                            onSelected: _setRenamedOnly,
                            backgroundColor: Theme.of(context).colorScheme.surface,
                            selectedColor: Theme.of(context).colorScheme.primaryContainer,
                            elevation: 2,
                            pressElevation: 4,
                            tooltip: _renamedOnly ? 'Also show places with no name change' : 'Show only places with a name change',
                          ),
                          _PlaceFilterButton(value: _placeFilter, onChanged: _setPlaceFilter),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 60,
                      right: 12,
                      child: FloatingActionButton.small(
                        heroTag: 'zoomToStart',
                        tooltip: 'Show all of South Africa',
                        onPressed: _zoomToStart,
                        child: const Icon(Icons.zoom_out_map),
                      ),
                    ),
                    MapAttribution(credits: _credits),
                    // Flashing in the middle of the map until Help's "Got it".
                    if (!_helpRead && !_loading)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: _HelpReminder(onTap: _showHelp),
                        ),
                      ),
                    if (_timelineYear != null)
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: MapAttribution.reservedHeight + 8,
                        child: SafeArea(
                          top: false,
                          child: TimelinePanel(
                            year: _timelineYear!,
                            minYear: _timelineStart,
                            firstYear: _timelineFirst,
                            onUnlockEarlier: () {
                              _stopPlaying();
                              _openPaywall();
                            },
                            maxYear: _todayYear,
                            renamedByYear: _renamedBy(_timelineYear!),
                            totalRenamed: _towns.where((t) => t.hasDifferentOldName).length,
                            playing: _playTimer != null,
                            onChanged: _setTimelineYear,
                            onPlayPause: _togglePlay,
                            onClose: _closeTimeline,
                          ),
                        ),
                      ),
                  ],
                ),
      // Lifted clear of the map attribution strip along the bottom edge.
      // Hidden while the timeline panel takes the bottom of the screen.
      floatingActionButton: _timelineYear != null
          ? null
          : Padding(
            padding: const EdgeInsets.only(bottom: MapAttribution.reservedHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Two FABs on one screen need distinct hero tags, or route
                // transitions throw "multiple heroes share the same tag".
                FloatingActionButton.small(
                  heroTag: 'whereAmI',
                  tooltip: 'Where am I?',
                  onPressed: (_loading || _locating) ? null : _whereAmI,
                  child: _locating
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.my_location),
                ),
                const SizedBox(height: 12),
                FloatingActionButton.extended(
                  heroTag: 'nameMode',
                  onPressed: _loading ? null : _toggleNameMode,
                  tooltip: _isPlus ? null : 'Previous names are part of $kPlusName',
                  icon: Icon(!_isPlus
                      ? Icons.lock_outline
                      : (_showOldNames ? Icons.history_toggle_off : Icons.update)),
                  label: Text(_showOldNames && _isPlus ? 'Show current names' : 'Show previous names'),
                ),
              ],
            ),
          ),
    );
  }

  /// Pin shape by place type, so airports, dams and passes stand out from
  /// towns without relying on colour alone.
  static IconData _markerIcon(Town town) {
    switch (town.kind) {
      case 'airport':
        return Icons.local_airport;
      case 'dam':
        return Icons.water;
      case 'pass':
        return Icons.terrain;
      default:
        return town.isUserEdited ? Icons.edit_location_alt : Icons.location_on;
    }
  }

  Marker _buildMarker(Town town) {
    return Marker(
      point: LatLng(town.latitude, town.longitude),
      width: 140,
      height: 60,
      // topCenter places the whole widget *above* the point, so the pin
      // (last in the column) has its tip on the town's coordinates and the
      // label sits above it.
      alignment: Alignment.topCenter,
      child: GestureDetector(
        onTap: () => _onTownTap(town),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.black12),
              ),
              child: Text(
                _labelFor(town),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
            Icon(
              _markerIcon(town),
              color: town.hasKnownRename
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.secondary,
              size: 26,
            ),
          ],
        ),
      ),
    );
  }
}

class _TownDetailSheet extends StatelessWidget {
  const _TownDetailSheet(
      {required this.town,
      required this.showOldNames,
      this.story,
      this.facts,
      this.damStation,
      required this.isPlus});

  final Town town;
  final bool showOldNames;
  final NameStory? story;

  /// Airport, dam or pass facts, if there are any.
  final PlaceFacts? facts;

  /// For dams in the weekly report: where to get the dam's level.
  final DamStation? damStation;

  /// What the facts are, in a few words, for the Plus teaser.
  static String _factsTeaser(Town town) => switch (town.kind) {
        'airport' => 'Airport codes, height above sea level and who runs it',
        'dam' => 'The river, when it was built, its capacity, wall height and weekly level',
        'pass' => 'Height at the top, mountain range, road and surface',
        _ => 'Facts about this place',
      };

  /// Free users see a teaser instead of the name story and pronunciation.
  final bool isPlus;

  @override
  Widget build(BuildContext context) {
    final headline = town.displayName(showOldNames);
    final revealed = town.tappedName(showOldNames);
    final revealedLabel = showOldNames ? 'Current name' : 'Previous name';

    final story = this.story;

    // Scrolls when a name story makes the sheet taller than the screen
    // allows, with a "More below" marker so people know to.
    return ScrollWithMoreHint(
      // Clear of the phone's navigation bar now the sheet can be tall.
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewPaddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(headline, style: Theme.of(context).textTheme.headlineSmall),
              ),
              if (town.isUserEdited)
                Padding(
                  padding: const EdgeInsets.only(top: 4, right: 4),
                  child: Tooltip(
                    message: 'Added or edited by you',
                    child: Icon(Icons.person, size: 18, color: Theme.of(context).colorScheme.secondary),
                  ),
                ),
              if (town.hasKnownRename)
                IconButton(
                  icon: const Icon(Icons.share_outlined),
                  tooltip: 'Share this town\'s info',
                  // Sharing is part of Plus; the map opens the Plus
                  // screen instead for free users.
                  onPressed: () => Navigator.of(context).pop('share'),
                ),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Record or edit a name change',
                onPressed: () => Navigator.of(context).pop('edit'),
              ),
              // A clear way out, now the sheet can fill most of the screen.
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          Text(
            town.kindLabel == null ? town.province : '${town.kindLabel} · ${town.province}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const Divider(height: 24),
          // Airports, dams and passes: the facts (and a dam's level) come
          // first, so nobody has to scroll to find them; the name history
          // follows.
          if (facts != null || damStation != null) ...[
            if (isPlus) ...[
              if (facts != null) PlaceFactsSection(facts: facts!),
              if (damStation != null) DamLevelTile(station: damStation!),
            ] else
              PlusTeaser(
                title: 'Facts about this ${town.kindLabel?.toLowerCase() ?? 'place'}',
                text: '${_factsTeaser(town)} are part of $kPlusName.',
                onUnlock: () => Navigator.of(context).pop('plus'),
              ),
            const Divider(height: 28),
          ],
          // Free users see that a place was renamed (and when), but its
          // previous name, notes and name story are part of Plus. If the
          // timeline is already showing the old name, the current name is
          // no secret, so that case shows as normal.
          if (revealed != null && !isPlus && !showOldNames) ...[
            if (town.renamedYear != null) ...[
              Text(
                town.reverted ? 'Reverted to this name in ${town.renamedYear}' : 'Renamed in ${town.renamedYear}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
            ],
            PlusTeaser(
              title: 'What was ${town.currentName} called before?',
              text: story == null
                  ? 'Previous names are part of $kPlusName.'
                  : 'Previous names, what the new name means and how to say it are part of $kPlusName.',
              onUnlock: () => Navigator.of(context).pop('plus'),
            ),
          ] else if (revealed != null) ...[
            Text(revealedLabel, style: Theme.of(context).textTheme.labelLarge),
            Text(revealed, style: Theme.of(context).textTheme.titleLarge),
            if (town.renamedYear != null) ...[
              const SizedBox(height: 12),
              Text(
                town.reverted
                    ? 'Reverted to this name in ${town.renamedYear}'
                    : 'Renamed in ${town.renamedYear}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            if (town.notes != null && isPlus) ...[
              const SizedBox(height: 8),
              Text(town.notes!, style: Theme.of(context).textTheme.bodySmall),
            ],
            if (story != null) ...[
              const Divider(height: 28),
              if (isPlus)
                NameStorySection(story: story, townName: town.currentName, oldName: town.oldName)
              else
                PlusTeaser(
                  title: story.say != null
                      ? 'What does ${town.currentName} mean, and how do you say it?'
                      : 'The story behind the name ${town.currentName}',
                  text: 'Name stories and pronunciation guides are part of $kPlusName.',
                  onUnlock: () => Navigator.of(context).pop('plus'),
                ),
            ],
          ] else if (town.hasKnownRename) ...[
            // A rename that was later reverted (e.g. Louis Trichardt): the
            // previous name and today's name are the same.
            Text('Previous name', style: Theme.of(context).textTheme.labelLarge),
            Text('Same as today', style: Theme.of(context).textTheme.titleLarge),
            if (town.renamedYear != null) ...[
              const SizedBox(height: 12),
              Text(
                town.reverted ? 'Reverted to this name in ${town.renamedYear}' : 'Renamed in ${town.renamedYear}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            if (town.notes != null && isPlus) ...[
              const SizedBox(height: 8),
              Text(town.notes!, style: Theme.of(context).textTheme.bodySmall),
            ],
          ] else
            Text(
              'No name change is on record for this ${town.kindLabel?.toLowerCase() ?? 'town'}. '
              'Tap the edit icon above if you know one.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          // Airports, dams and passes: facts (Plus), after the name history.
        ],
      ),
    );
  }
}

/// "Refresh data" in the ⋮ menu, with when it was last done underneath -
/// highlighted once it's over a month ago.
class _RefreshMenuTile extends StatelessWidget {
  const _RefreshMenuTile({required this.lastRefreshed, required this.refreshing});

  final DateTime? lastRefreshed;
  final bool refreshing;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final stale = isRefreshStale(lastRefreshed, now);
    final colour = stale ? Theme.of(context).colorScheme.error : null;
    final when = describeLastRefresh(lastRefreshed, now);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Badge(isLabelVisible: stale, smallSize: 8, child: const Icon(Icons.sync)),
      title: const Text('Refresh data'),
      subtitle: Text(
        refreshing ? 'Checking now…' : 'Last refreshed: $when',
        style: TextStyle(color: colour),
      ),
    );
  }
}

/// Shown in place of the name banner while the towns are being read.
class _LoadingBanner extends StatelessWidget {
  const _LoadingBanner();

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(8),
      color: Colors.blue.shade700,
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            SizedBox(width: 10),
            Text('Loading towns…', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _NameModeBanner extends StatelessWidget {
  const _NameModeBanner({
    required this.showOldNames,
    required this.townCount,
    this.timelineYear,
    required this.timelineStart,
    required this.todayYear,
  });

  final bool showOldNames;
  final int townCount;

  /// Set while the timeline is open.
  final int? timelineYear;
  final int timelineStart;
  final int todayYear;

  @override
  Widget build(BuildContext context) {
    final year = timelineYear;
    final String text;
    final bool old;
    if (year == null) {
      old = showOldNames;
      text = showOldNames
          ? 'Displaying PREVIOUS names ($townCount places)'
          : 'Displaying CURRENT names ($townCount places)';
    } else if (year <= timelineStart) {
      old = true;
      text = 'Timeline: previous names';
    } else if (year >= todayYear) {
      old = false;
      text = 'Timeline: names today';
    } else {
      old = true;
      text = 'Timeline: names in $year';
    }

    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(8),
      color: old ? Colors.brown.shade600 : Colors.blue.shade700,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(year != null ? Icons.timeline : (old ? Icons.history : Icons.map), color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                text,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Search by name. With Plus it also finds towns by their previous name;
/// without it, it searches current names only, and offers Plus when the
/// text matches an old name. Closes with a [Town], [getPlus] or null.
class _TownSearchDelegate extends SearchDelegate<Object?> {
  _TownSearchDelegate(this._towns, {required this.isPlus});
  final List<Town> _towns;
  final bool isPlus;

  /// Returned when the person taps "looking for a previous name?".
  static const String getPlus = 'get-plus';

  List<Town> _filter(String q) {
    if (q.trim().isEmpty) return const [];
    final lower = q.toLowerCase();
    final results = _towns
        .where((t) =>
            t.currentName.toLowerCase().contains(lower) ||
            (isPlus && t.oldName.toLowerCase().contains(lower)))
        .toList()
      ..sort((a, b) => b.population.compareTo(a.population));
    return results.take(30).toList();
  }

  /// Without Plus: does the text match an old name we're not searching?
  bool _matchesHiddenOldName(String q) {
    if (isPlus || q.trim().length < 3) return false;
    final lower = q.toLowerCase();
    return _towns.any((t) => t.hasDifferentOldName && t.oldName.toLowerCase().contains(lower));
  }

  @override
  List<Widget> buildActions(BuildContext context) => [
        if (query.isNotEmpty) IconButton(icon: const Icon(Icons.clear), onPressed: () => query = '')
      ];

  @override
  Widget buildLeading(BuildContext context) =>
      IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(context, null));

  @override
  Widget buildResults(BuildContext context) => _buildList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildList(context);

  Widget _buildList(BuildContext context) {
    final results = _filter(query);
    final offerPlus = _matchesHiddenOldName(query);
    return ListView.builder(
      itemCount: results.length + (offerPlus ? 1 : 0),
      itemBuilder: (context, index) {
        if (offerPlus && index == results.length) {
          return ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Looking for a previous name?'),
            subtitle: const Text('Searching by old names is part of $kPlusName.'),
            onTap: () => close(context, getPlus),
          );
        }
        final t = results[index];
        final place = t.kindLabel == null ? t.province : '${t.kindLabel} · ${t.province}';
        final subtitle = t.hasDifferentOldName && isPlus ? '$place · was ${t.oldName}' : place;
        return ListTile(
          title: Text(t.currentName),
          subtitle: Text(subtitle),
          onTap: () => close(context, t),
        );
      },
    );
  }
}

/// The Help dialog: one line per feature, each next to the icon it refers
/// to, so it doubles as a legend for the map.
class _HelpText extends StatelessWidget {
  const _HelpText();

  static const _lines = <(IconData, String)>[
    (Icons.zoom_in, 'Pinch with two fingers to zoom, and drag with one finger to move the map.'),
    (Icons.zoom_out_map, 'The button at the top right takes you back to the whole of South Africa.'),
    (Icons.location_on, 'Red pins are places with a name change on record. Blue-grey pins have none on record yet.'),
    (Icons.local_airport, 'Airports, dams and mountain passes have their own pin shapes. With $kPlusName, tapping one shows facts such as its height, river or capacity, and for big dams how full they are this week.'),
    (Icons.touch_app_outlined, 'Tap a pin to see when the place was renamed. With $kPlusName you see its previous name, what the new name means and how to say it.'),
    (Icons.update, 'With $kPlusName, the button at the bottom switches the whole map between current and previous names.'),
    (Icons.filter_alt_outlined, '"Renamed towns only" (top left) hides places without a name change. It is on each time the app opens; tap it to see every town.'),
    (Icons.filter_list, 'The filter button next to it shows all places, or only towns, airports, dams or mountain passes.'),
    (Icons.my_location, 'The target button finds the town you\'re in, and with $kPlusName tells you what it used to be called.'),
    (Icons.timeline, 'The timeline button (top) lets you slide or play through the years and watch the names change. The "Then" stop at the start, with every previous name, is part of $kPlusName.'),
    (Icons.search, 'Search finds any town by its current name and takes you there. With $kPlusName it finds old names too.'),
    (Icons.share_outlined, 'With $kPlusName, the share button on a renamed town sends its info, as shown, as a picture and a message.'),
    (Icons.sync, '⋮ → Refresh data gets the latest town names, and shows when you last did it.'),
    (Icons.share_outlined, 'The share button in the top bar tells friends about the app and where to get it.'),
    (Icons.edit_outlined, 'With $kPlusName, the pencil on a place lets you record a new name change or fix an old name.'),
    (Icons.add_location_alt_outlined, 'With $kPlusName, long-press an empty spot on the map to add a place that\'s missing.'),
    if (!kOfflineMapsEnabled)
      (Icons.workspace_premium_outlined, '⋮ → $kPlusName: a one-time purchase for previous names, name stories and recording names. Everything else is free.'),
    if (kOfflineMapsEnabled) ...[
      (Icons.workspace_premium_outlined, '⋮ → $kPlusName: a one-time purchase for previous names, name stories and recording names.'),
      (Icons.download_for_offline_outlined, '⋮ → $kOfflineName: a separate one-time purchase to download maps for use with no signal.'),
    ],
    (Icons.map_outlined, 'No signal? Town names still work, and a plain outline of the provinces shows where the map can\'t load.'),
    (Icons.person, 'A person icon means you added or edited that town yourself. Those changes stay on your phone.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Says up front how to close Help (the only way is "Got it").
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text.rich(
            TextSpan(
              children: [
                TextSpan(text: 'Have a quick read, then tap '),
                TextSpan(text: 'Got it', style: TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: ' at the bottom to start.'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'See South Africa\'s towns under their current names and, where a town has been renamed, '
          'under its previous name.',
        ),
        const SizedBox(height: 16),
        // First, because testers didn't know what the numbered circles were.
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Looks like the circles on the map.
              CircleAvatar(
                radius: 11,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: const Text('12', style: TextStyle(color: Colors.white, fontSize: 9)),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: 'Circles with numbers ', style: TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(
                        text: 'are groups of places that are close together, so the map doesn\'t get '
                            'crowded. The number is how many places are in the group. Tap a circle to zoom in '
                            'on it: it splits into smaller groups and pins. Keep zooming in (or pinch) and every '
                            'place shows as its own pin. The filters at the top change which places are '
                            'counted.',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        for (final (icon, text) in _lines)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 18, color: Theme.of(context).colorScheme.secondary),
                const SizedBox(width: 10),
                Expanded(child: Text(text)),
              ],
            ),
          ),
      ],
    );
  }
}

/// The place-type filter (the button next to "Renamed towns only").
enum PlaceFilter {
  all('Show all', 'All places', Icons.layers_outlined),
  towns('Show towns only', 'Towns', Icons.location_city_outlined),
  airports('Show airports only', 'Airports', Icons.flight_outlined),
  dams('Show dams only', 'Dams', Icons.water_outlined),
  passes('Show mountain passes only', 'Mountain passes', Icons.terrain_outlined);

  const PlaceFilter(this.menuLabel, this.chipLabel, this.icon);

  /// The option in the menu.
  final String menuLabel;

  /// The button's label while this option is chosen.
  final String chipLabel;
  final IconData icon;

  bool includes(Town town) => switch (this) {
        PlaceFilter.all => true,
        PlaceFilter.towns => town.kind == 'town',
        PlaceFilter.airports => town.kind == 'airport',
        PlaceFilter.dams => town.kind == 'dam',
        PlaceFilter.passes => town.kind == 'pass',
      };

  /// The "renamed only" chip's label, matching what's being shown.
  String get renamedOnlyLabel => switch (this) {
        PlaceFilter.all => 'Renamed towns only',
        PlaceFilter.towns => 'Renamed towns only',
        PlaceFilter.airports => 'Renamed airports only',
        PlaceFilter.dams => 'Renamed dams only',
        PlaceFilter.passes => 'Renamed passes only',
      };
}

/// Looks like the chip next to it; opens a menu of place types.
class _PlaceFilterButton extends StatelessWidget {
  const _PlaceFilterButton({required this.value, required this.onChanged});

  final PlaceFilter value;
  final ValueChanged<PlaceFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final filtered = value != PlaceFilter.all;
    return PopupMenuButton<PlaceFilter>(
      tooltip: 'Filter places',
      initialValue: value,
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final option in PlaceFilter.values)
          CheckedPopupMenuItem(
            value: option,
            checked: option == value,
            child: Text(option.menuLabel),
          ),
      ],
      child: Chip(
        avatar: Icon(filtered ? value.icon : Icons.filter_list, size: 18),
        label: Text(value.chipLabel),
        backgroundColor: filtered ? scheme.primaryContainer : scheme.surface,
        elevation: 2,
      ),
    );
  }
}

/// Flashing "please read the Help" card in the middle of the map. Tapping
/// it opens Help; it goes away for good once Help's "Got it" is tapped.
/// Fades between two colours about once a second (slow enough to be safe
/// for people sensitive to flashing).
class _HelpReminder extends StatefulWidget {
  const _HelpReminder({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_HelpReminder> createState() => _HelpReminderState();
}

class _HelpReminderState extends State<_HelpReminder> with SingleTickerProviderStateMixin {
  late final AnimationController _flash =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  @override
  void dispose() {
    _flash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: AnimatedBuilder(
        animation: _flash,
        builder: (context, child) => Material(
          color: Color.lerp(Colors.amber.shade300, Colors.deepOrange.shade400, _flash.value),
          elevation: 8,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: child,
        ),
        child: InkWell(
          onTap: widget.onTap,
          child: const Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.help_outline, size: 36, color: Colors.black87),
                SizedBox(height: 8),
                Text(
                  "You haven't read the Help yet",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w800, fontSize: 17),
                ),
                SizedBox(height: 4),
                Text(
                  'Tap here to see how the app works',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black87, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
