import 'package:flutter/material.dart';

import 'config/app_info.dart';
import 'screens/map_screen.dart';
import 'services/purchase_service.dart';

void main() {
  runApp(const SaTownNamesApp());
}

class SaTownNamesApp extends StatelessWidget {
  const SaTownNamesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: kAppName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue.shade700),
        useMaterial3: true,
      ),
      home: const AppGate(),
    );
  }
}

/// Shows a short spinner while the cached purchase flag is read, then the
/// map. The app is free to use; Then & Now Plus (checked through
/// PurchaseService.unlocked) only unlocks extras inside it.
///
/// Also checks with the store each time the app opens or comes back to the
/// foreground, so a purchase made outside the app - such as a free code
/// redeemed in the App Store or Play Store - unlocks without any extra
/// step.
class AppGate extends StatefulWidget {
  const AppGate({super.key});

  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> with WidgetsBindingObserver {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) PurchaseService.instance.checkStore();
  }

  Future<void> _start() async {
    try {
      await PurchaseService.instance.checkCachedPurchase();
    } catch (_) {
      // Not fatal - the app just starts without Plus until it's restored.
    }
    if (mounted) setState(() => _ready = true);
    // In the background, a few seconds in: the map gets the phone's full
    // attention first, and anything new from the store unlocks when it
    // arrives.
    Future.delayed(const Duration(seconds: 5), PurchaseService.instance.checkStore);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return const MapScreen();
  }
}
