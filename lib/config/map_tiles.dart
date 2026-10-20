import 'package:flutter/foundation.dart';

import 'app_info.dart';

/// Your app's real application ID - by default the Android ID in
/// app_info.dart ([kAndroidAppId]).
///
/// It is sent in the User-Agent of every map tile request. The
/// OpenStreetMap tile servers block apps that send a generic or
/// placeholder ID (like `com.example...`), so set this before release -
/// either edit the default below or build with
/// `--dart-define=APP_ID=za.co.acme.sa_town_names`.
const String kAppId = String.fromEnvironment('APP_ID', defaultValue: kAndroidAppId);

/// One credit line shown in the map's attribution box.
class TileCredit {
  const TileCredit(this.text, this.url);
  final String text;
  final String url;
}

/// Where the map's background tiles come from, chosen at build time with
/// `--dart-define` (see the README, "Map tiles"):
///
///  - `TILE_PROVIDER=osm` (default): the OpenStreetMap Foundation's public
///    server. Free, but meant for light use, with no uptime guarantee, and
///    access can be withdrawn at any time - fine for development, risky
///    for a paid app.
///  - `TILE_PROVIDER=maptiler` + `TILE_API_KEY=...`: MapTiler Cloud (OSM
///    data, free tier and paid plans). Optional `MAPTILER_MAP=streets-v4`.
///  - `TILE_PROVIDER=custom` + `TILE_URL=...` + `TILE_ATTRIBUTION=...`
///    (+ optional `TILE_ATTRIBUTION_URL`, `TILE_API_KEY` for a `{key}`
///    placeholder, `TILE_MAX_ZOOM`): any other XYZ raster tile service.
class MapTileSource {
  const MapTileSource({
    required this.name,
    required this.urlTemplate,
    required this.credits,
    this.additionalOptions = const {},
    this.maxNativeZoom = 19,
  });

  final String name;
  final String urlTemplate;
  final Map<String, String> additionalOptions;
  final List<TileCredit> credits;
  final int maxNativeZoom;

  static const _provider = String.fromEnvironment('TILE_PROVIDER', defaultValue: 'osm');
  static const _apiKey = String.fromEnvironment('TILE_API_KEY');
  static const _maptilerMap = String.fromEnvironment('MAPTILER_MAP', defaultValue: 'streets-v4');
  static const _customUrl = String.fromEnvironment('TILE_URL');
  static const _customAttribution = String.fromEnvironment('TILE_ATTRIBUTION');
  static const _customAttributionUrl = String.fromEnvironment('TILE_ATTRIBUTION_URL');
  static const _customMaxZoom = int.fromEnvironment('TILE_MAX_ZOOM', defaultValue: 19);

  static const osmCredit = TileCredit('OpenStreetMap contributors', 'https://www.openstreetmap.org/copyright');

  static const openStreetMap = MapTileSource(
    name: 'OpenStreetMap',
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    credits: [osmCredit],
  );

  /// The tile source selected by the build's `--dart-define`s. Falls back
  /// to [openStreetMap] (with a debug warning) if a provider is chosen but
  /// its settings are missing.
  static MapTileSource fromEnvironment() {
    switch (_provider) {
      case 'maptiler':
        if (_apiKey.isEmpty) {
          debugPrint('TILE_PROVIDER=maptiler needs TILE_API_KEY - falling back to OpenStreetMap.');
          return openStreetMap;
        }
        return MapTileSource(
          name: 'MapTiler',
          // 256px raster tiles; {key} is filled from additionalOptions.
          urlTemplate: 'https://api.maptiler.com/maps/$_maptilerMap/256/{z}/{x}/{y}.png?key={key}',
          additionalOptions: const {'key': _apiKey},
          credits: const [
            TileCredit('MapTiler', 'https://www.maptiler.com/copyright/'),
            osmCredit,
          ],
        );
      case 'custom':
        if (_customUrl.isEmpty || _customAttribution.isEmpty) {
          debugPrint('TILE_PROVIDER=custom needs TILE_URL and TILE_ATTRIBUTION - falling back to OpenStreetMap.');
          return openStreetMap;
        }
        return MapTileSource(
          name: 'Custom',
          urlTemplate: _customUrl,
          additionalOptions: _apiKey.isEmpty ? const {} : const {'key': _apiKey},
          maxNativeZoom: _customMaxZoom,
          credits: [
            TileCredit(
              _customAttribution,
              _customAttributionUrl.isEmpty ? 'https://www.openstreetmap.org/copyright' : _customAttributionUrl,
            ),
          ],
        );
      case 'osm':
        return openStreetMap;
      default:
        debugPrint('Unknown TILE_PROVIDER "$_provider" - using OpenStreetMap.');
        return openStreetMap;
    }
  }

  /// Logs a loud warning in debug builds if [kAppId] is still a
  /// placeholder - OSM blocks those, and it identifies you to any provider.
  static void warnIfPlaceholderAppId() {
    if (kReleaseMode) return;
    if (kAppId.contains('yourcompany') || kAppId.contains('example')) {
      debugPrint('WARNING: kAppId is still the placeholder "$kAppId". Set your real application ID '
          'in lib/config/map_tiles.dart or with --dart-define=APP_ID=... before release - '
          'the OpenStreetMap tile servers block placeholder IDs.');
    }
  }
}
