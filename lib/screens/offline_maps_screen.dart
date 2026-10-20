import 'dart:async';

import 'package:flutter/material.dart';

import '../config/offline_maps.dart';
import '../services/offline_maps_service.dart';
import '../services/purchase_service.dart';

/// The Offline Maps add-on: buy it, then download map packs to use the
/// map with no signal, and manage (update/remove) downloaded packs.
class OfflineMapsScreen extends StatefulWidget {
  const OfflineMapsScreen({super.key});

  @override
  State<OfflineMapsScreen> createState() => _OfflineMapsScreenState();
}

class _OfflineMapsScreenState extends State<OfflineMapsScreen> {
  final _purchases = PurchaseService.instance;
  final _maps = OfflineMapsService.instance;
  StreamSubscription<PurchaseEvent>? _sub;

  List<OfflinePack>? _available;
  List<InstalledPack> _installed = const [];
  bool _useOffline = true;
  String? _error;
  bool _buying = false;

  /// Pack id -> download progress (0..1) while downloading.
  final Map<String, double> _downloading = {};

  @override
  void initState() {
    super.initState();
    _sub = _purchases.events.listen(_onPurchaseEvent);
    _purchases.offlineUnlocked.addListener(_refresh);
    _load();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _purchases.offlineUnlocked.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _onPurchaseEvent(PurchaseEvent event) {
    if (!mounted || event.productId != PurchaseService.offlineProductId) return;
    switch (event.type) {
      case PurchaseEventType.purchased:
        setState(() => _buying = false);
        break;
      case PurchaseEventType.pending:
        break;
      case PurchaseEventType.canceled:
        setState(() => _buying = false);
        break;
      case PurchaseEventType.error:
        setState(() {
          _buying = false;
          _error = event.message;
        });
        break;
    }
  }

  Future<void> _load() async {
    try {
      await _purchases.init();
    } catch (_) {
      // The price shows as unavailable; buying explains the problem.
    }
    final installed = await _maps.installed();
    final useOffline = await _maps.useOffline();
    List<OfflinePack>? available;
    String? error;
    try {
      available = await _maps.fetchAvailable();
    } catch (e) {
      error = 'Could not load the list of map packs. Check your connection and try again.';
    }
    if (!mounted) return;
    setState(() {
      _installed = installed;
      _useOffline = useOffline;
      _available = available;
      _error = error;
    });
  }

  Future<void> _buy() async {
    setState(() {
      _buying = true;
      _error = null;
    });
    try {
      await _purchases.buy(id: PurchaseService.offlineProductId);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _buying = false;
        _error = 'Could not start the purchase: $e';
      });
    }
  }

  Future<void> _restore() async {
    setState(() {
      _buying = true;
      _error = null;
    });
    final ok = await _purchases.restore(id: PurchaseService.offlineProductId);
    if (!mounted) return;
    setState(() {
      _buying = false;
      if (!ok) _error = 'No earlier $kOfflineName purchase found for this store account.';
    });
  }

  Future<void> _download(OfflinePack pack) async {
    setState(() {
      _downloading[pack.id] = 0;
      _error = null;
    });
    try {
      await _maps.download(pack, onProgress: (p) {
        if (mounted) setState(() => _downloading[pack.id] = p);
      });
      final installed = await _maps.installed();
      if (!mounted) return;
      setState(() => _installed = installed);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Download of ${pack.name} failed: $e');
    } finally {
      if (mounted) setState(() => _downloading.remove(pack.id));
    }
  }

  Future<void> _remove(OfflinePack pack) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${pack.name}?'),
        content: Text('This frees ${pack.sizeLabel}. You can download it again later.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true) return;
    await _maps.remove(pack.id);
    final installed = await _maps.installed();
    if (mounted) setState(() => _installed = installed);
  }

  Future<void> _setUseOffline(bool value) async {
    setState(() => _useOffline = value);
    await _maps.setUseOffline(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final owned = _purchases.hasOfflineMaps;
    final price = _purchases.offlineProduct?.price;

    return Scaffold(
      appBar: AppBar(title: const Text(kOfflineName)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Download the map for areas you\'re travelling to, and it works with no signal and '
            'no data costs - roads, rivers and terrain included. Town names, stories and '
            '"Where am I?" already work offline.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          if (!owned) ...[
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('$kOfflineName add-on', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      'A one-time purchase, separate from Then & Now Plus. No subscription. '
                      'Map packs and their updates are included.',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: (_buying || price == null) ? null : _buy,
                      child: _buying
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(price == null ? 'Price unavailable' : 'Unlock $kOfflineName for $price'),
                    ),
                    TextButton(onPressed: _buying ? null : _restore, child: const Text('Restore purchase')),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (owned && _installed.isNotEmpty)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Use downloaded maps'),
              subtitle: const Text('Off: use online maps (needs signal) even where you have a pack.'),
              value: _useOffline,
              onChanged: _setUseOffline,
            ),
          if (_error != null) ...[
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            const SizedBox(height: 8),
          ],
          Text('Map packs', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          if (_available == null && _error == null)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          for (final pack in _available ?? const <OfflinePack>[]) _packTile(pack, owned),
          // Installed packs no longer offered (e.g. offline right now): still manageable.
          for (final inst in _installed)
            if (!(_available ?? const <OfflinePack>[]).any((p) => p.id == inst.pack.id)) _packTile(inst.pack, owned),
          const SizedBox(height: 16),
          Text(
            'Packs are stored in the app\'s own storage on this phone and are removed if you uninstall '
            'the app. Large packs are best downloaded on Wi-Fi; keep the app open until the download '
            'finishes.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _packTile(OfflinePack pack, bool owned) {
    final matches = _installed.where((i) => i.pack.id == pack.id);
    final installed = matches.isEmpty ? null : matches.first;
    final updateAvailable = installed != null && installed.pack.version < pack.version;
    final progress = _downloading[pack.id];

    Widget trailing;
    if (progress != null) {
      trailing = SizedBox(width: 40, height: 40, child: CircularProgressIndicator(value: progress));
    } else if (!owned) {
      trailing = const Icon(Icons.lock_outline);
    } else if (installed == null) {
      trailing = IconButton(
        tooltip: 'Download',
        icon: const Icon(Icons.download),
        onPressed: () => _download(pack),
      );
    } else {
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (updateAvailable)
            IconButton(tooltip: 'Update', icon: const Icon(Icons.system_update_alt), onPressed: () => _download(pack)),
          IconButton(tooltip: 'Remove', icon: const Icon(Icons.delete_outline), onPressed: () => _remove(pack)),
        ],
      );
    }

    final status = installed == null
        ? pack.sizeLabel
        : updateAvailable
            ? 'Downloaded · update available'
            : 'Downloaded · ${pack.sizeLabel}';

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(installed == null ? Icons.map_outlined : Icons.offline_pin),
      title: Text(pack.name),
      subtitle: Text([if (pack.description.isNotEmpty) pack.description, status].join('\n')),
      isThreeLine: pack.description.isNotEmpty,
      trailing: trailing,
    );
  }
}
