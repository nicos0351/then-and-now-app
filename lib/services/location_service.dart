import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Why a location couldn't be found, so the UI can say what to do.
enum LocationProblem { serviceDisabled, denied, deniedForever, unavailable }

class LocationOutcome {
  const LocationOutcome.found(double this.latitude, double this.longitude) : problem = null;
  const LocationOutcome.failed(LocationProblem this.problem)
      : latitude = null,
        longitude = null;

  final double? latitude;
  final double? longitude;
  final LocationProblem? problem;

  bool get isFound => problem == null;
}

/// One-off, low-accuracy location for "Where am I?".
///
/// Town-level accuracy is all the app needs, so it first asks for the
/// cheapest fix, and only uses GPS if that fails (e.g. no signal on a
/// rural road). People can still choose "approximate" in the permission
/// prompt. The position is used on the device to find the nearest town
/// and is never stored or sent anywhere.
class LocationService {
  LocationService._();

  /// A last-known fix younger than this is used straight away.
  static const Duration _freshEnough = Duration(minutes: 30);

  static Future<LocationOutcome> currentLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationOutcome.failed(LocationProblem.serviceDisabled);
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return const LocationOutcome.failed(LocationProblem.deniedForever);
      }
      if (permission == LocationPermission.denied) {
        return const LocationOutcome.failed(LocationProblem.denied);
      }

      // A recent cached fix is instant, and coarse fixes from scratch can
      // be slow - so try that first.
      Position? last;
      if (!kIsWeb) {
        try {
          last = await Geolocator.getLastKnownPosition();
        } catch (_) {
          last = null;
        }
      }
      if (last != null && DateTime.now().difference(last.timestamp) < _freshEnough) {
        return LocationOutcome.found(last.latitude, last.longitude);
      }

      // First a quick, low-power fix (usually from Wi-Fi or mobile
      // networks). In a dead zone there may be no network fix at all, so
      // then fall back to GPS, which works without signal.
      for (final attempt in const [
        LocationSettings(accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 10)),
        LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 30)),
      ]) {
        try {
          final position = await Geolocator.getCurrentPosition(locationSettings: attempt);
          return LocationOutcome.found(position.latitude, position.longitude);
        } catch (_) {
          // Timed out, or that method isn't available (e.g. no network
          // location in a dead zone) - try the next one.
        }
      }
      // An older fix is still better than nothing for "which town".
      if (last != null) return LocationOutcome.found(last.latitude, last.longitude);
      return const LocationOutcome.failed(LocationProblem.unavailable);
    } catch (e) {
      debugPrint('Location lookup failed: $e');
      return const LocationOutcome.failed(LocationProblem.unavailable);
    }
  }

  static Future<void> openAppSettings() => Geolocator.openAppSettings();
  static Future<void> openLocationSettings() => Geolocator.openLocationSettings();
}
