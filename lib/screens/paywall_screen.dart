import 'dart:async';

import 'package:flutter/material.dart';

import '../config/app_info.dart';
import '../services/purchase_service.dart';

/// Gate shown until the one-time purchase is confirmed. Calls
/// [onUnlocked] exactly once, the moment a purchase (new or restored)
/// succeeds.
///
/// [dismissible] shows a close button so the person can back out to the
/// (free) app - which is how it's always opened now that the core app is
/// free.
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key, required this.onUnlocked, this.dismissible = false});

  final VoidCallback onUnlocked;
  final bool dismissible;

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

enum _LoadState { loading, ready, buying, pending, restoring }

class _PaywallScreenState extends State<PaywallScreen> {
  final _service = PurchaseService.instance;
  StreamSubscription<PurchaseEvent>? _sub;
  _LoadState _state = _LoadState.loading;
  String? _error;
  bool _unlockHandled = false;

  @override
  void initState() {
    super.initState();
    _sub = _service.events.listen(_onPurchaseEvent);
    _init();
  }

  void _onPurchaseEvent(PurchaseEvent event) {
    // This screen sells Then & Now Plus only.
    if (!mounted || event.productId != PurchaseService.productId) return;
    switch (event.type) {
      case PurchaseEventType.purchased:
        _handleUnlocked();
        break;
      case PurchaseEventType.pending:
        setState(() => _state = _LoadState.pending);
        break;
      case PurchaseEventType.canceled:
        // Only meaningful if we were mid-purchase; a cancelled sheet
        // just returns the person to the paywall with no error.
        if (_state == _LoadState.buying || _state == _LoadState.pending) {
          setState(() {
            _state = _LoadState.ready;
            _error = null;
          });
        }
        break;
      case PurchaseEventType.error:
        setState(() {
          _state = _LoadState.ready;
          _error = event.message ?? 'The purchase could not be completed.';
        });
        break;
    }
  }

  /// Guards against the unlock arriving twice (e.g. once from the stream
  /// and once from the post-init check) - [PaywallScreen.onUnlocked]
  /// usually pops a route, and popping twice would close the wrong one.
  void _handleUnlocked() {
    if (_unlockHandled || !mounted) return;
    _unlockHandled = true;
    widget.onUnlocked();
  }

  Future<void> _init() async {
    if (_state != _LoadState.loading) {
      setState(() {
        _state = _LoadState.loading;
        _error = null;
      });
    }
    try {
      await _service.init();
      if (!mounted) return;
      if (_service.isPurchased) {
        _handleUnlocked();
        return;
      }
      setState(() => _state = _LoadState.ready);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _LoadState.ready;
        _error = 'Could not reach the store: $e';
      });
    }
  }

  Future<void> _buy() async {
    setState(() {
      _state = _LoadState.buying;
      _error = null;
    });
    try {
      await _service.buy();
      // The outcome arrives asynchronously via _onPurchaseEvent.
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _LoadState.ready;
        _error = 'Could not start purchase: $e';
      });
    }
  }

  Future<void> _restore() async {
    setState(() {
      _state = _LoadState.restoring;
      _error = null;
    });
    try {
      final restored = await _service.restore();
      if (!mounted) return;
      if (restored) {
        _handleUnlocked();
      } else {
        setState(() {
          _state = _LoadState.ready;
          _error = _service.storeAvailable
              ? 'No previous purchase found for this store account.'
              : 'The app store is not reachable right now, so the purchase could not be checked.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _LoadState.ready;
        _error = 'Restore failed: $e';
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.dismissible
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: CloseButton(onPressed: () => Navigator.of(context).maybePop()),
            )
          : null,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: SingleChildScrollView(child: _buildBody(context)),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_state == _LoadState.loading) {
      return const CircularProgressIndicator();
    }

    final product = _service.product;
    final storeAvailable = _service.storeAvailable;
    final busy = _state == _LoadState.buying || _state == _LoadState.restoring || _state == _LoadState.pending;

    String? statusText;
    if (_state == _LoadState.pending) {
      statusText = 'Waiting for the store to approve the payment. '
          'The app unlocks automatically once it does - you can leave this screen.';
    } else if (_state == _LoadState.restoring) {
      statusText = 'Checking the store for an earlier purchase…';
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.workspace_premium_outlined, size: 64, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 16),
        Text(
          kPlusName,
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        const _PlusFeature(
          Icons.history,
          'Previous names',
          'Switch the whole map to the previous names, see any town\'s former name, go back to "Then" on '
              'the timeline, search by old names and share a town\'s info.',
        ),
        const _PlusFeature(
          Icons.menu_book_outlined,
          'Name stories & pronunciation',
          'What each new name means or who it honours, where the old name came from, and how to say it.',
        ),
        const _PlusFeature(
          Icons.fact_check_outlined,
          'Facts about airports, dams and passes',
          'Airport codes and height, a dam\'s river, capacity and wall height, and a pass\'s height, road and surface.',
        ),
        const _PlusFeature(
          Icons.edit_location_alt_outlined,
          'Record & add names',
          'Record a new name change, fix an old name, or add a place that\'s missing.',
        ),
        const SizedBox(height: 12),
        Text(
          'One-time purchase - no subscription. The map with today\'s names, search, '
          '"Where am I?", the "Renamed only" filter and most of the timeline stay free.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 28),
        if (!storeAvailable)
          Text(
            'The app store is not reachable on this device right now.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          )
        else
          FilledButton(
            onPressed: (product == null || busy) ? null : _buy,
            child: _state == _LoadState.buying
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(product == null ? 'Price unavailable' : 'Unlock Plus for ${product.price}'),
          ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: busy ? null : _restore,
          child: const Text('Restore purchase'),
        ),
        if (statusText != null) ...[
          const SizedBox(height: 16),
          Text(statusText, textAlign: TextAlign.center),
        ],
        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: _init, child: const Text('Retry')),
        ],
        if (_error == null && (!storeAvailable || product == null)) ...[
          const SizedBox(height: 16),
          OutlinedButton(onPressed: _init, child: const Text('Retry')),
        ],
      ],
    );
  }
}

class _PlusFeature extends StatelessWidget {
  const _PlusFeature(this.icon, this.title, this.text);
  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.secondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                Text(text, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
