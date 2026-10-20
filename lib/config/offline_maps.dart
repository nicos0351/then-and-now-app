/// Offline Maps add-on settings.
///
/// The add-on is built but **switched off** until downloadable map packs
/// exist and the store product is set up - an in-app purchase that
/// delivers nothing would be rejected by App Review. When the packs are
/// hosted (see README, "Offline maps add-on"), build with
/// `--dart-define=OFFLINE_MAPS=true`, or change the default below.
const bool kOfflineMapsEnabled = bool.fromEnvironment('OFFLINE_MAPS', defaultValue: false);

/// The list of downloadable map packs (JSON), published with the town
/// data on GitHub Pages. Format: see README and `OfflinePack.fromJson`.
const String kOfflinePacksUrl = String.fromEnvironment(
  'OFFLINE_PACKS_URL',
  defaultValue: 'https://nicos0351.github.io/then-and-now-data/offline/packs.json',
);

/// Display name of the add-on (also its name in both stores).
const String kOfflineName = 'Offline Maps';
