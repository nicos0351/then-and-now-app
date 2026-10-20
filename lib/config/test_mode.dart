/// Test builds: lets you switch Then & Now Plus on and off from the ⋮ menu
/// without buying it, to check every locked and unlocked screen.
///
/// Turn on with `--dart-define=TEST_PLUS=true`, e.g.
/// `flutter run --release --dart-define=TEST_PLUS=true`. It's a build-time
/// setting, so the builds you upload (without it) can't be switched by
/// anyone. A test build shows "TEST" in an orange title bar so it's never
/// mistaken for a real one - never upload a build made with this on.
library;

const bool kTestPlus = bool.fromEnvironment('TEST_PLUS', defaultValue: false);
