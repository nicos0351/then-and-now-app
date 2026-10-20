import 'dart:math' as math;

import '../models/town.dart';

/// A town and how far it is from the person.
class NearbyTown {
  const NearbyTown(this.town, this.distanceKm);
  final Town town;
  final double distanceKm;
}

/// How close the nearest town is, which decides the wording ("You're in
/// X" vs "You're near X" vs "nearest town is X").
enum Proximity { inTown, nearTown, farFromTown, outsideSouthAfrica }

/// Answer to "Where am I?".
class WhereAmIResult {
  const WhereAmIResult({required this.nearest, required this.proximity, this.nearestRenamed});

  /// The closest town in the dataset.
  final NearbyTown nearest;

  final Proximity proximity;

  /// The closest *renamed* town within [renamedSearchRadiusKm], when the
  /// nearest town itself has no different old name - so there's always
  /// something interesting to show. Null if [nearest] is itself renamed
  /// or nothing renamed is close enough.
  final NearbyTown? nearestRenamed;
}

/// Within this distance of a town's point, you're "in" it.
const double inTownKm = 5;

/// Within this distance, you're "near" it.
const double nearTownKm = 30;

/// Further than this from every town in the dataset means you're almost
/// certainly not in South Africa.
const double outsideSouthAfricaKm = 250;

/// How far to look for a renamed town to suggest.
const double renamedSearchRadiusKm = 100;

/// Great-circle distance in kilometres (haversine; plenty accurate for
/// "which town is closest").
double distanceKm(double lat1, double lon1, double lat2, double lon2) {
  const earthRadiusKm = 6371.0;
  double rad(double deg) => deg * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLon = rad(lon2 - lon1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.sin(dLon / 2) * math.sin(dLon / 2);
  return 2 * earthRadiusKm * math.asin(math.min(1.0, math.sqrt(a)));
}

/// Finds the town the person at [lat]/[lon] is in or nearest to, plus the
/// nearest renamed town if their own town has no name change. Returns null
/// only if [towns] is empty. ~1,000 towns, so a simple scan is instant.
WhereAmIResult? findWhereAmI(List<Town> towns, double lat, double lon) {
  NearbyTown? nearest;
  NearbyTown? nearestRenamed;

  for (final town in towns) {
    final d = distanceKm(lat, lon, town.latitude, town.longitude);
    if (nearest == null || d < nearest.distanceKm) nearest = NearbyTown(town, d);
    if (town.hasDifferentOldName && (nearestRenamed == null || d < nearestRenamed.distanceKm)) {
      nearestRenamed = NearbyTown(town, d);
    }
  }
  if (nearest == null) return null;

  final Proximity proximity;
  if (nearest.distanceKm <= inTownKm) {
    proximity = Proximity.inTown;
  } else if (nearest.distanceKm <= nearTownKm) {
    proximity = Proximity.nearTown;
  } else if (nearest.distanceKm <= outsideSouthAfricaKm) {
    proximity = Proximity.farFromTown;
  } else {
    proximity = Proximity.outsideSouthAfrica;
  }

  final suggestRenamed = !nearest.town.hasDifferentOldName &&
      proximity != Proximity.outsideSouthAfrica &&
      nearestRenamed != null &&
      nearestRenamed.distanceKm <= renamedSearchRadiusKm;

  return WhereAmIResult(
    nearest: nearest,
    proximity: proximity,
    nearestRenamed: suggestRenamed ? nearestRenamed : null,
  );
}

/// "3 km", "850 m", "120 km".
String formatDistance(double km) {
  if (km < 1) return '${math.max(50, (km * 1000 / 50).round() * 50)} m';
  if (km < 10) return '${km.toStringAsFixed(1).replaceAll('.0', '')} km';
  return '${km.round()} km';
}
