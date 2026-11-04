/// The app's public name, in one place so it can't drift between screens.
///
/// The Dart package (`sa_town_names`), bundle/application IDs, in-app
/// product IDs and database name deliberately keep the old technical
/// name - changing those would break builds, store products and existing
/// installs. Only what people see uses these strings.
library;

/// Full name: store listing title, About screen, paywall.
const String kAppName = 'Then & Now: SA Place Names';

/// Short name for tight spots: the top bar and the phone's home screen.
const String kAppShortName = 'Then & Now';

/// Name of the one-time upgrade (also its display name in both stores).
const String kPlusName = 'Then & Now Plus';

/// Store subtitle / tagline.
const String kAppTagline = 'Old and new names on one map';

/// The app's App Store page, or '' while [kAppStoreId] isn't set.
String get kAppStoreUrl => kAppStoreId.isEmpty ? '' : 'https://apps.apple.com/app/id$kAppStoreId';

/// Link added to shared town info, e.g. a small landing page that points
/// to both stores. Leave empty to use the Google Play link.
const String kShareUrl = '';

/// The Android application ID - also what the Google Play link is built
/// from. Must match `applicationId` in android/app/build.gradle.kts.
const String kAndroidAppId = 'com.nicossteyn.thenandnow';

/// The app's Google Play page (works once the app is published there).
const String kPlayStoreUrl = 'https://play.google.com/store/apps/details?id=$kAndroidAppId';

/// Apple's numeric ID for the app (App Store Connect → the app → App
/// Information → Apple ID, e.g. '6512345678'). Leave empty until the
/// iPhone version exists; the "Share this app" message then tells people
/// to search the App Store instead of giving a link.
const String kAppStoreId = '';

/// Whether "Share this app" mentions the App Store. Set to false if the
/// app is only on Google Play for now.
const bool kOnAppStore = false; // no iPhone version yet

/// Weekly dam levels from the Department of Water and Sanitation's website
/// (Plus). Off since 1.0.8: that website only answers visitors in South
/// Africa, so Google Play's reviewers abroad couldn't open the source links
/// the store listing must give for government information, and the listing
/// was rejected. The code stays (lib/services/dam_levels_service.dart);
/// switch back on only once Google has agreed (see the README).
const bool kDamLevelsEnabled = false;

/// What to type in the store's search box to find the app.
const String kStoreSearchText = 'Then & Now SA Place Names';
