# Then & Now: SA Place Names — Flutter App

*Old and new names on one map.*

A Flutter app that shows a pannable/zoomable map of South Africa with a marker
for every town in the local dataset, and lets you flip the whole map between
**previous names** and **current names**. Tapping any town reveals whichever
name isn't currently showing.

## What's included

- `assets/towns.json` — **988 South African towns, nationwide, plus
  291 airports, 245 dams and 423 mountain passes** (data version 7: every
  airport with an official code, every dam on Wikipedia's list or at least
  2 km across, and every named pass, from OpenStreetMap and Wikipedia; see
  `tools/places/` in the data repository). 18 of them were renamed (e.g. Jan
  Smuts → O. R. Tambo International Airport, Hendrik Verwoerd Dam → Gariep
  Dam); the rest show as plain pins. They have
  `"kind": "airport" | "dam" | "pass"` and their own pin shapes.
- `assets/place_facts.json` + `lib/models/place_facts.dart`,
  `lib/widgets/place_facts_section.dart` — **facts** for airports (codes,
  height, who runs it, year opened), dams (river, year, capacity, wall
  height and type) and passes (height, range, road, surface), shown with
  Then & Now Plus (data version 8; built by `tools/places/build_facts.py` in
  the data repository from Wikidata, OpenStreetMap and Wikipedia) Only
  towns count for "Where am I?". The towns are merged
  from two sources:
  - [GeoNames](https://www.geonames.org) (`cities500`, all ZA populated
    places with population ≥ 500), for full national coverage — this
    dataset is © GeoNames, licensed **CC BY 4.0**, so keep the
    attribution note in‑app or in your store listing if you ship this
  - **79 towns with a documented name history**, 76 of which show a
    different previous name on the map — e.g. Pietersburg→Polokwane,
    Nelspruit→Mbombela, Port Elizabeth→Gqeberha, Grahamstown→Makhanda,
    Queenstown→Komani, Mafikeng→Mahikeng, Ladysmith→uMnambithi. The other
    three (Louis Trichardt, Vaalwater, Reitz) had the same name before
    1994 as today and carry a note explaining their history. Each renamed
    entry has a `source` field pointing at where it was checked (mainly
    Wikipedia's [List of renamed places in South Africa](https://en.wikipedia.org/wiki/List_of_renamed_places_in_South_Africa),
    plus news reports of the gazette notices for the 2024–2026 changes)
  - the four 2026 Eastern Cape renames (KuGompo City, Robert Sobukwe
    Town, Xamdeboo, Ekhephini) were gazetted on 6 Feb 2026 but are under
    review after more than 38,000 objections — their notes say so; update
    them when the review concludes
  - every other town in the file just has `hasKnownRename: false` — it's
    plotted and searchable, but tapping it says there's no name change on
    record rather than inventing one
- `lib/models/town.dart` — the `Town` data model
- `lib/services/town_asset_loader.dart` — parses `assets/towns.json`
- `lib/services/database_helper.dart` — local **SQLite** database (via
  `sqflite`) that is created and seeded from the asset on first launch —
  everything is on‑device after that, no server/network calls for the
  data itself
- `lib/screens/map_screen.dart` — the map screen:
  - `flutter_map` renders OpenStreetMap-based tiles (which already
    include roads) with full pan/zoom/pinch support built in; tiles are
    cached on the device (up to 200 MB) so revisited areas cost no data
  - an always-visible credit strip in the bottom-left corner credits the
    tile provider and GeoNames (each credit opens its licence page)
  - a floating action button toggles the whole map between old/current
    name mode
  - tapping a town marker opens a sheet showing the other name (or a
    "no rename on record" note for the ~900 towns that don't have one)
  - markers cluster automatically when zoomed out, and clustering is
    disabled again once you're zoomed in past street level, so ~1,000
    markers stay readable at every zoom level
  - a search icon in the app bar finds any town by current *or* old name
    and jumps the map to it — useful now that there are 1,000 markers
    instead of ~55
  - a **"Renamed towns only"** chip under the banner hides places with no
    name change on record; it is on every time the app opens
  - a **filter button** under it: Show all (every time the app opens),
    or only towns, airports, dams or mountain passes. The two combine, e.g.
    "Airports" with "Renamed airports only"
  - **new versions from Google Play** are offered inside the app
    (`lib/services/app_update_service.dart`, package `in_app_update`): about
    10 seconds after opening, at most once a day, Google Play's own "Update
    available" box appears; the update downloads in the background and a
    message then offers **Restart**. Only works for copies installed from
    Google Play, so you won't see it in builds run from your PC
  - the ⋮ menu has Refresh data, Help (a plain-English guide that doubles
    as a legend for the icons; its first topic explains the numbered
    circles) and **About & credits**
  - until someone taps **Got it** in Help, a flashing card in the middle of
    the map says they haven't read it yet (tapping it opens Help). If Help
    can only be closed with its big **Got it – start using the app**
    button (tapping outside it or the back button do nothing). If Help
    was opened but the app was closed without "Got it", it opens by itself the next
    time the app is opened (or comes back after more than a minute in the
    background). The answers are saved on the phone (`help_read`,
    `help_opened_unread`); clearing the app's data or reinstalling starts
    over
  - a **"Where am I?"** button (target icon, above the name toggle) finds
    the town you're in and shows what it used to be called; if your town
    has no rename, it also suggests the nearest renamed town. A blue dot
    marks your position. See "Location" below for setup.
- `lib/config/map_tiles.dart` — which tile server the map uses, and your
  app ID for tile requests (see "Map tiles" below)
- `lib/widgets/map_attribution.dart` — the on-map credit strip
- `lib/screens/about_screen.dart` — About & credits: OpenStreetMap,
  GeoNames (CC BY 4.0), where rename information comes from, and the
  open-source licences page
- `lib/utils/links.dart` — opens links in the browser
- `assets/name_stories.json` + `lib/models/name_story.dart`,
  `lib/widgets/name_story_section.dart`, `lib/utils/sound_guide.dart` —
  **name stories and pronunciation** for every renamed town (see "Name
  stories and pronunciation" below)
- `lib/widgets/timeline_panel.dart` — the **timeline**: drag or play from
  "Then" (every previous name) to "Today" and every label shows the name the town had
  that year
- `lib/widgets/share_card.dart` and `lib/utils/town_info.dart` — **sharing
  a town's info**: exactly what the town sheet shows (name, place, previous
  name, rename year, notes, pronunciation, name story, sources), as a
  picture 1080 pixels wide plus the same text, through the phone's share sheet
- `lib/services/remote_data_service.dart` — **live data updates**: the
  ⋮ menu's "Refresh data", plus a quiet check about once a week (see
  "Live town-name updates" below)
- `lib/services/location_service.dart`, `lib/utils/nearest_town.dart`,
  `lib/widgets/where_am_i_sheet.dart` — "Where am I?"
- `lib/main.dart` — app entry point
- `lib/screens/edit_town_sheet.dart` — the add/edit form:
  - tap any town, then its edit (pencil) icon, to **record a rename** for
    a town that's changed name since this app shipped: type the new name
    as the current name and the previous one moves into the old-name
    field automatically (you can also fill in a missing old name, year,
    reverted flag and notes, or fix the province)
  - **long-press anywhere on the map** to drop a pin and add a **brand
    new town** that isn't in the dataset at all yet; only towns you added
    yourself can be deleted, and delete / clear-rename both ask first
  - edits and additions are saved straight to the local SQLite database
    and are never lost: re-syncing with `assets/towns.json` after an app
    update updates and tidies up the bundled towns you haven't touched,
    but never changes or removes a row you've edited or added (see
    `DatabaseHelper` for how the stable `key`/`is_user_edited` columns
    make that safe)
  - user-added/edited towns show a small "person" badge in their detail
    sheet and a slightly different marker icon on the map, so it's clear
    which entries are official (from the bundled dataset) vs. crowd-added
- `lib/utils/provinces.dart` — the 9 provinces, used by the add/edit form
- `lib/services/purchase_service.dart` + `lib/screens/paywall_screen.dart`
  + `lib/widgets/plus_teaser.dart` — **Then & Now Plus**, the one-time
  upgrade (see "Free app + Then & Now Plus" below)
- `assets/sa_outline.json` + `lib/models/map_outline.dart` — a light
  **outline of South Africa** (provinces, neighbouring countries, province
  names) drawn under the map tiles, so the map is never blank where tiles
  can't load (no signal, never viewed). From Natural Earth (public domain),
  simplified to 42 KB
- `lib/config/offline_maps.dart`, `lib/services/offline_maps_service.dart`,
  `lib/screens/offline_maps_screen.dart` — the **Offline Maps add-on**, a
  second, higher-priced purchase for downloadable map packs. Built but
  switched off until packs are hosted (see "Offline Maps add-on" below)

## 1. Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.27+ (Dart 3.6+) — required by flutter_map 8
- Android Studio (for Android builds/emulator) and/or Xcode (for iOS
  builds/simulator, macOS only)
- Run `flutter doctor` and resolve any red flags before continuing

## 2. Generate the platform folders

This package ships only the cross-platform `lib/` code and `pubspec.yaml`.
Generate the `android/` and `ios/` folders for your installed Flutter
version by running, from inside this folder:

```bash
flutter create . --org com.nicossteyn --project-name sa_town_names
```

This will not overwrite the `lib/` files already here; it just adds the
native platform scaffolding.

### App icon

The icon is the "Then/Now pin": a map pin, brown on the left (then) and
blue on the right (now), on a cream background. The images are in
`assets/icon/` (`app_icon.svg` is the editable original). To put it in the
Android and iOS folders, run once after `flutter create` (and again if you
change the images):

```bash
flutter pub get
dart run flutter_launcher_icons
```

On Android 8+ it's an adaptive icon, so it fits round, squircle and
rounded-square launchers.

### App ID

The Android `applicationId` (and iOS bundle ID) is
`com.nicossteyn.thenandnow`. It's permanent once the app is on Google Play
or the App Store. It must match `kAppId` in `lib/config/map_tiles.dart`
(used to identify the app to the map tile server), which already defaults
to it, so `--dart-define=APP_ID=...` isn't needed.

### App name on the phone and in the stores

The name people see is set in `lib/config/app_info.dart` (`kAppName`,
`kAppShortName`, `kAppTagline`). The code project, bundle/application
IDs, in-app product IDs and database keep the technical name
`sa_town_names`, so nothing breaks for builds, store products or existing
installs.

The home-screen label comes from the platform folders, so set it once
after `flutter create`. Use the short name, because home screens cut off
long labels. The `&` must be written as `&amp;` in both files (they're
XML):

- Android: `android/app/src/main/AndroidManifest.xml` →
  `<application android:label="Then &amp; Now" ...>`
- iOS: `ios/Runner/Info.plist` → set `CFBundleDisplayName` to
  `<string>Then &amp; Now</string>`

Store listings:

| Field | Value |
|---|---|
| App Store name (max 30) | Then & Now: SA Place Names |
| App Store subtitle (max 30) | Old and new names on one map |
| Google Play app name (max 30) | Then & Now: SA Place Names |
| Google Play short description (max 80) | Old and new names of SA towns, airports, dams and mountain passes on one map. |

Before you publish, search both stores and the CIPC trademark register
to make sure no one else is using the name or something close to it.

## 3. Install dependencies

```bash
flutter pub get
```

## 4. Android — internet permission and opening links

Map tiles are fetched over the network, and the credits / About screen
open links in the browser. In `android/app/src/main/AndroidManifest.xml`,
add the internet permission (inside `<manifest>`, before
`<application>`), and a `<queries>` entry so links can be opened on
Android 11+ (also inside `<manifest>`):

```xml
<uses-permission android:name="android.permission.INTERNET" />

<queries>
  <intent>
    <action android:name="android.intent.action.VIEW" />
    <data android:scheme="https" />
  </intent>
</queries>
```

## 4a. Location for "Where am I?"

The app asks for location only when someone taps "Where am I?", uses
it once on the phone to find the nearest town, and never stores or
sends it. It first tries a quick, low-power fix (from Wi-Fi or mobile
networks). If that fails, for example in a dead zone on a rural road,
it falls back to GPS, which works without signal. That's why Android
asks for precise location too. People can still pick "Approximate" in
the prompt; it then just won't work where there's no signal.

**Android** — in `android/app/src/main/AndroidManifest.xml`, inside
`<manifest>` (next to the internet permission):

```xml
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
```

The location plugin (`geolocator` 14) also needs `compileSdk = 35` in
`android/app/build.gradle` (or `build.gradle.kts`). New Flutter projects
usually use 35 or newer already.

**iOS** — in `ios/Runner/Info.plist`, add the text shown in the
permission prompt:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Your location is used only on this phone to show which town you're in and its former name. It is never stored or shared.</string>
```

The app never needs background location, so turn off the plugin's
"Always" location code in `ios/Podfile`. That stops Apple from asking
about "Always" location access when you submit. Flutter's generated
Podfile already ends with a `post_install` block; add the `if` part
inside its loop so it looks like this:

```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    if target.name == "geolocator_apple"
      target.build_configurations.each do |config|
        config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= ['$(inherited)', 'BYPASS_PERMISSION_LOCATION_ALWAYS=1']
      end
    end
  end
end
```

**Store privacy forms.** The location is processed only on the device:
- App Store privacy label: under Apple's definitions, data that never
  leaves the device isn't "collected", so location doesn't need to be
  listed as collected.
- Google Play Data safety: declare that the app *accesses* approximate
  and precise location for app functionality, processed only on the
  device. It isn't collected or shared, because it's never sent off the
  phone.

Check the current wording of both forms when you fill them in.

## 4b. Map tiles — set your app ID, and pick a tile provider for release

**App ID (required).** Every tile request identifies the app with
`kAppId` in `lib/config/map_tiles.dart`. Set it to the same ID you used
with `flutter create --org ...` (e.g. `za.co.acme.sa_town_names`), either
by editing the default there or at build time:

```bash
flutter run --dart-define=APP_ID=za.co.acme.sa_town_names
```

OpenStreetMap blocks requests that send a placeholder ID such as
`com.example...` or `com.yourcompany...` (you'll see a warning in the
debug console until it's set).

**Tile provider.** By default the map uses the OpenStreetMap
Foundation's free public tile server. That's fine for development, and
the app meets its usage policy (real app ID, on-map credit, on-device
caching). But the server is donation-funded with no uptime guarantee, and
OSM says access for commercial apps "may be withdrawn at any point", so
for a paid app on the stores, switch to a commercial provider. They serve
the same OpenStreetMap data. The provider is chosen at build time, with
no code changes:

```bash
# MapTiler (https://www.maptiler.com — free tier, then paid plans)
flutter build apk --dart-define=APP_ID=za.co.acme.sa_town_names \
  --dart-define=TILE_PROVIDER=maptiler --dart-define=TILE_API_KEY=your_key
# optional: --dart-define=MAPTILER_MAP=streets-v4   (or another map style ID)

# Any other XYZ raster tile service (e.g. Stadia Maps, Thunderforest, your own server)
flutter build apk --dart-define=APP_ID=za.co.acme.sa_town_names \
  --dart-define=TILE_PROVIDER=custom \
  --dart-define=TILE_URL='https://tiles.example.com/{z}/{x}/{y}.png?api_key={key}' \
  --dart-define=TILE_API_KEY=your_key \
  --dart-define=TILE_ATTRIBUTION='Example Maps · OpenStreetMap contributors' \
  --dart-define=TILE_ATTRIBUTION_URL=https://example.com/copyright
```

Notes:
- Use the same `--dart-define`s for `flutter run`, `flutter build apk`,
  `flutter build appbundle` and `flutter build ios`.
- A tile API key is built into the app, so anyone can extract it. In your
  provider's dashboard, restrict the key to your app (by app ID / bundle
  ID) and set a usage cap.
- MapTiler's **free** plan also requires the MapTiler logo on the map;
  paid plans only need the text credit, which the app already shows.
- Whatever provider you use, read its terms: the credit text it requires
  goes in `TILE_ATTRIBUTION`, and the in-app credit strip shows it.
- Tiles are cached on the device (flutter_map's built-in cache, capped at
  200 MB in `map_screen.dart`). The OS may clear it when storage runs
  low. Pre-downloading areas for offline use is **not** allowed on the
  OpenStreetMap server; the Offline Maps add-on therefore uses its own
  map packs (see "Offline Maps add-on").
- Where no tile is available, the bundled outline of the provinces and
  neighbouring countries shows instead, so the towns are never floating
  on a blank screen.

## 5. Run it

```bash
flutter run            # runs on a connected device/emulator/simulator
flutter build apk      # Android release build
flutter build ios      # iOS release build (macOS + Xcode required)
```

## 6. Free app + Then & Now Plus (set up before payment works)

The app is **free to download and use**. There are two separate one-time,
non-consumable purchases:

- **Then & Now Plus** (`sa_town_names_full_unlock`) — described here.
- **Offline Maps** (`sa_town_names_offline_maps`, priced higher) —
  described in "Offline Maps add-on" below. It's only offered in builds
  with `--dart-define=OFFLINE_MAPS=true`.

**Then & Now Plus** unlocks the old names and two extras:

| Free for everyone | Then & Now Plus |
|---|---|
| The map with every town, airport, dam and pass, under today's names | **Previous names**: the "Show previous names" switch, each place's former name when you tap it, the timeline's "Then" stop, searching by old names, and sharing a town's info |
| Which places were renamed, and when (red pins, "Renamed only" filter) | **Name stories & pronunciation**: what each new name means or who it honours, where the old name came from, how to say it |
| Timeline from 1994 to today (all but the "Then" stop), search by current name | **Record & add names**: record a name change, fix an old name, add a missing place |
| "Where am I?" (your town, and the nearest renamed town), Refresh data | |

How it looks for free users:
- The **Show previous names** button has a lock and opens the Plus screen.
- Tapping a renamed place shows its current name and "Renamed in 2005"
  (where the year is known), with a **What was Polokwane called
  before?** card offering Plus instead of the old name, notes and story.
- **"Where am I?"** names your town and says it was renamed, with the same
  card instead of the old name.
- The **timeline** runs from 1994 to today; its "Then" end has a
  lock that opens the Plus screen. Note: in the years after 1994 the
  timeline shows the names towns still had then, and most renames
  happened from 2002 on, so many old names are visible there.
- **Search** finds current names only. If the text matches an old name, a
  "Looking for a previous name?" row offers Plus.
- **Share** cards, the pencil (edit) and long-press (add) open the Plus
  screen.
- ⋮ → **Then & Now Plus** opens it any time. After purchase it shows
  "Unlocked", and everything opens up immediately, with no restart.

`PaywallScreen` sells the single **non-consumable** product through
`in_app_purchase`, Flutter's official plugin for StoreKit (iOS) and Play
Billing (Android). That's also the *only* store-compliant way to sell an
in-app unlock; a custom checkout (Stripe, PayPal, etc.) isn't permitted
for this on iOS and is against Play policy too. It has **Restore
purchase**, which Apple requires, and the purchase restores free on any
phone signed into the same store account.

**Price:** a low one-off price tends to suit South African buyers; think
in the R29–R49 range. You set it in each store, and the app shows
whatever the store says.

None of the purchase part works out of the box. You need to create the
one product in each store first:

### Google Play Console (Android)

1. Create the app in Play Console if you haven't already, and upload at
   least one build to an internal testing track (Play Billing doesn't
   work on a debug build installed directly via `flutter run`/ADB — the
   app has to come from Play, even for testing).
2. **Monetize → Products → In-app products → Create product**.
3. Product ID must be exactly `sa_town_names_full_unlock` (matches
   `PurchaseService.productId` — change both together if you rename it).
4. Name it **"Then & Now Plus"**, set it **active**, give it a price and
   a description, and save.
5. Under **Setup → License testing**, add your own Google account as a
   license tester so you can buy it repeatedly without being charged.

### App Store Connect (iOS)

1. In Xcode, open the iOS runner target → **Signing & Capabilities** →
   **+ Capability** → add **In-App Purchase**.
2. In App Store Connect: **Features → In-App Purchases → +** → choose
   **Non-Consumable**.
3. Product ID must be exactly `sa_town_names_full_unlock`.
4. Fill in the reference name, price, and the (required) localised
   display name **"Then & Now Plus"**, a description (e.g. "Previous
   names for every renamed place, name stories and pronunciation, and
   recording and adding names.") and a review screenshot of the Plus screen, then save.
5. You'll need an **Agreements, Tax, and Banking** setup completed in App
   Store Connect before purchases work, even in sandbox.
6. Test with a **Sandbox Apple ID** (App Store Connect → Users and Access
   → Sandbox → Testers), signed into the Sandbox environment on your test
   device (Settings → App Store → Sandbox Account on iOS 17 and earlier;
   it's under the app-specific Sandbox setting on newer iOS).

### Free Plus for founders and reviewers (store codes)

Give Plus away with the stores' own codes rather than anything built into
the app (Apple's guideline 3.1.1 doesn't allow apps to unlock features
with their own codes or keys):

- **iOS:** App Store Connect → your app → the Then & Now Plus in-app
  purchase → **Offer Codes** → create codes for a free offer. (Apple
  replaced in-app purchase promo codes with offer codes on 26 March 2026;
  offer codes now cover one-time purchases.) The founder redeems it in the
  App Store app (account picture → Redeem Gift Card or Code).
- **Android:** Play Console → **Promotions** (in the Monetize section) → create a promo code promotion →
  choose the Then & Now Plus product. Up to 500 codes per quarter across
  the app's one-time products; unused codes expire at the end of the
  quarter. The founder redeems it in the Play Store (Menu → Redeem code),
  or via `https://play.google.com/redeem?code=THECODE`.

Each code unlocks one product only, so a Plus code never unlocks Offline
Maps. No extra step is needed in the app: it checks with the store each
time it opens or comes back to the foreground
(`PurchaseService.checkStore()`), and shows "Then & Now Plus is unlocked"
when the code comes through. Plus then restores on any phone signed into
that store account, like a paid purchase.

### If you rename a product ID

Change `PurchaseService.productId` in
`lib/services/purchase_service.dart` **and** the product ID in the
consoles so they match exactly — a mismatch is the most common
reason `queryProductDetails` comes back empty (check the debug console;
`PurchaseService.init()` logs when a configured ID isn't found).

### Before you rely on this for real money

`PurchaseService` only checks the purchase **on-device** (via the store's
own restore/cache) — good enough to build and test with, but a
compromised device could spoof it. For production, send each purchase's
`PurchaseDetails.verificationData` to a backend you control and verify it
server-side against Apple's/Google's verification endpoints before
trusting it (there's a `// Production apps should...` comment marking
exactly where in `_onPurchaseUpdates`).

### What "once-off" means here

- It's a **non-consumable** purchase — bought once, unlocked forever,
  restorable free on any device signed into the same store account
  (that's what the "Restore purchase" button on the paywall does).
- The unlocked state is cached locally (`shared_preferences`), so the
  map opens straight away with Plus already on. In the background the app
  then checks with the store for anything new (see "Free Plus for
  founders" above); on Android that query only runs while something is
  still locked, and at most every two minutes.

## Offline Maps add-on (second paid option)

**Offline Maps** is a separate one-time purchase, priced above Plus (think
R79–R99). It lets people download **map packs** — the actual map picture,
roads, rivers and terrain — so the map works with no signal and no data
costs. Place names, stories, the timeline and "Where am I?" already work
offline for everyone; this add-on is only about the map underneath.

### It's switched off until packs exist

An in-app purchase that delivers nothing gets rejected by App Review (and
annoys buyers), so the add-on is hidden by default. Turn it on only once
at least one pack is hosted and the store product is set up:

```bash
flutter build appbundle --dart-define=OFFLINE_MAPS=true   # plus your other --dart-defines
flutter build ios       --dart-define=OFFLINE_MAPS=true
```

When on, the ⋮ menu gets an **Offline Maps** item. That screen shows the
price and **Restore purchase**, then the list of packs with download,
update and remove buttons, sizes and progress, and a **Use downloaded
maps** switch.

### How it works in the app

- Packs are **raster MBTiles** files (an SQLite file of map pictures), read
  with `flutter_map_mbtiles`. They're stored in the app's private storage
  (`offline_maps/<id>.mbtiles`) and removed if the app is uninstalled.
- Downloads go to a `.part` file first and only replace the installed pack
  once the full, expected size has arrived — a dropped connection never
  leaves a broken pack.
- On the map, packs draw **on top of** the online tiles: overview packs
  first, detailed packs last. Each pack shows from its lowest zoom to two
  levels past its highest, so zooming in further switches back to sharper
  online (or cached) tiles. Where neither exists, the outline shows.
- The credit strip adds each pack's `attribution` while the pack is in use.
- When you raise a pack's `version` in the list, phones that have it show
  **Update**.

### The packs list (`offline/packs.json`)

The app reads `https://nicos0351.github.io/then-and-now-data/offline/packs.json`
(`kOfflinePacksUrl`; override with `--dart-define=OFFLINE_PACKS_URL=...`).
The data repo's publish workflow already copies an `offline/` folder to the
site, so just add `offline/packs.json` there:

```json
{
  "format": 1,
  "packs": [
    {
      "id": "sa-overview",
      "name": "South Africa overview",
      "description": "Whole country with main roads, for planning and long trips.",
      "url": "https://github.com/nicos0351/then-and-now-data/releases/download/maps-2026-11/sa-overview.mbtiles",
      "sizeBytes": 157286400,
      "minZoom": 5,
      "maxZoom": 10,
      "version": 1,
      "attribution": "OpenStreetMap contributors",
      "bounds": [16.3, -35.0, 33.0, -22.0]
    }
  ]
}
```

- `id`: lower case, digits and dashes; it's also the file name on the phone.
- `url` must be `https://`. `sizeBytes` must be the **exact** file size
  (the download is rejected otherwise) — on Linux/macOS: `wc -c < file`.
- `bounds` is `[west, south, east, north]`; leave it out for "anywhere".
- The app tests this format in `test/offline_and_outline_test.dart`.

**Where to host the files:** not in the repository itself (Git and Pages
aren't meant for 100 MB+ files). Attach each `.mbtiles` to a **GitHub
Release** of the data repo (Releases → Draft a new release → attach
files; each file can be up to 2 GB) and use the download link as `url`.

### Making the packs — legally

The map pictures can't be copied from tile.openstreetmap.org (its policy
forbids bulk downloading) or from most commercial providers (their terms
usually forbid storing tiles for offline use unless you're on a plan that
allows it). Two legal routes:

1. **Render your own from OpenStreetMap data** (free, more work). Download
   South Africa from Geofabrik (`south-africa-latest.osm.pbf`), and render
   raster tiles into MBTiles with a tool such as TileMill/Mapnik or
   `tilemaker` + a renderer. OSM data is ODbL: keep the "OpenStreetMap
   contributors" credit (the `attribution` field does this in the app).
2. **Buy a provider plan that allows offline/self-hosted tiles** (e.g.
   MapTiler's downloadable map data, or another provider that licenses
   MBTiles for redistribution in apps). Use the credit they require as
   the `attribution`.

**Suggested packs and rough sizes** (raster, 256 px PNG/JPEG; real sizes
depend on style and compression):

| Pack | Zoom | Rough size |
|---|---|---|
| South Africa overview | 5–10 | 100–200 MB |
| One province, detailed (e.g. Gauteng) | 11–14 | 150–400 MB (larger provinces more) |
| Main tourist route (e.g. Garden Route corridor) | 11–14 | 100–300 MB |

Start with the overview plus two or three popular areas; a whole-country
pack at zoom 14 would be many gigabytes.

### iOS: keep packs out of iCloud backups

Apple rejects apps that back up large files that can be downloaded again.
After each download the app asks iOS to exclude the pack from backups,
through a tiny channel you add once to `ios/Runner/AppDelegate.swift`
(inside `application(_:didFinishLaunchingWithOptions:)`, before
`GeneratedPluginRegistrant.register(with: self)`):

```swift
let controller = window?.rootViewController as! FlutterViewController
FlutterMethodChannel(name: "then_and_now/files", binaryMessenger: controller.binaryMessenger)
  .setMethodCallHandler { call, result in
    guard call.method == "excludeFromBackup",
          let args = call.arguments as? [String: Any],
          let path = args["path"] as? String else {
      result(FlutterMethodNotImplemented); return
    }
    var url = URL(fileURLWithPath: path)
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    do { try url.setResourceValues(values); result(nil) }
    catch { result(FlutterError(code: "backup", message: error.localizedDescription, details: nil)) }
  }
```

Without it the app still works (it logs a warning), but review may flag
the backup size. Android needs nothing.

### Store product

Create a second **non-consumable** product exactly like Plus (see section
6), with:

- Product ID **`sa_town_names_offline_maps`** (matches
  `PurchaseService.offlineProductId`)
- Name **"Offline Maps"**, a higher price than Plus (e.g. R79–R99)
- Description, e.g. "Download South African map packs to use the map with
  no signal and no data costs. One-time purchase; pack updates included."
- For Apple review: a screenshot of the Offline Maps screen, and a review
  note saying where to find it (⋮ → Offline Maps) and that packs download
  after purchase.

Both purchases restore independently; buying one never unlocks the other.

## Wording: "previous", not "pre-1994"

The app deliberately avoids using 1994 as a reference point in what people
see: it says **previous name(s)**, and the first stop of the timeline is
**"Then"**. Real years (when a place was renamed, the years on the
timeline) are still shown. Internally the data and code still treat
`oldName` as the name a place had before its post-1994 rename.

## Recording a new rename in the app (recommended for day-to-day updates)

You don't need to touch code for this. In the running app:

1. Tap the town on the map (or find it via search).
2. Tap the pencil/edit icon in the sheet that pops up.
3. Type the town's **new** name in "Current name" — the name it had until
   now moves to "Previous name" automatically (change it if the
   previous name was something else). Optionally add the year and notes,
   then Save.

That's it — it's saved to the on-device database immediately and survives
app updates (see `DatabaseHelper`'s `source_key`/`is_user_edited` logic).
Use this for towns renamed *after* this app shipped; it's the quickest
way to keep the "recently changed" names current without a code release.

To add a town that isn't on the map at all yet, long-press the spot on
the map where it is and fill in the same form.

## Extending the bundled dataset (for a code release / everyone)

Edit `assets/towns.json` directly — it's a plain array of objects:

```json
{
  "key": "asset:polokwane:-23.904:29.469",
  "name": "Polokwane",
  "oldName": "Pietersburg",
  "hasKnownRename": true,
  "renamedYear": 2005,
  "reverted": false,
  "notes": "Provincial capital of Limpopo.",
  "province": "Limpopo",
  "latitude": -23.9045,
  "longitude": 29.4689,
  "population": 272461,
  "source": "https://en.wikipedia.org/wiki/List_of_renamed_places_in_South_Africa"
}
```

- `key` is the town's permanent identity. **Never change it**, even when
  you correct the name or coordinates — that is what lets existing
  installs update the row in place. For a new town, make up any unique
  value starting with `asset:` (e.g. `asset:newtown:-25.000:28.000`).
- For a town with no documented rename, set `hasKnownRename: false` and
  make `oldName` the same as `name`.
- For a rename that was later reverted, set `oldName` to the same as
  `name`, `reverted: true`, and explain in `notes`.
- `source` is for your own record-keeping; the app ignores it.

After editing, bump `DatabaseHelper.seedVersion` by 1 in
`lib/services/database_helper.dart`. On next launch existing installs
re-sync: new towns are added, corrected towns are updated in place, and
towns removed from the file are removed from the map — except any town
the user has edited or added, which is always left as they had it.

The `min_city_population=500` cutoff used to build the current dataset
excludes very small settlements. To go beyond ~1,000 towns (e.g. every
hamlet), re-run the generation step against a lower-threshold GeoNames
export or an OpenStreetMap extract — practical for a few thousand more
entries, but at that scale you'd likely also want server-side / tiled
loading rather than one bundled JSON file, since the app currently loads
the whole dataset into SQLite on first launch.

## Name stories and pronunciation

Tapping a renamed town (or using "Where am I?" in one) shows:

- **Say it** — a respelling with the stressed syllable in CAPITALS, e.g.
  `gq·eh-BEH-rha`, plus a one-line tip for each tricky sound in that name
  (clicks, *rh*, *hl*, aspirated *kh/ph/th*, …). "How to read this" opens
  a short general guide.
- **About the name …** — what the new name means or who it honours
  (45 towns), and where the old name came from (35 towns), with a tappable
  source link.

All 76 towns whose previous name differs from today's have a
pronunciation guide. Meanings and origins are only included where a
source was found (mostly Wikipedia and South African news reports);
where nothing reliable turned up, the field is left empty rather than
guessed. Towns where only the spelling changed (e.g. Engcobo → Ngcobo)
just say so.

**Accuracy.** The respellings are approximate guides for English and
Afrikaans speakers, written from the standard spelling rules of each
language. Before release, have a first-language speaker of isiXhosa,
isiZulu, Sepedi, Setswana, siSwati and Tshivenda check the entries in
their language. The next big improvement is **audio recordings** by those
speakers; an `audio` field per entry would be the natural way to add
them.

**Editing.** Everything lives in `assets/name_stories.json`, one entry
per town, matched to `assets/towns.json` by `key`:

```json
{
  "key": "asset:polokwane:-23.904:29.469",
  "name": "Polokwane",
  "say": "paw-law-KWAH-neh",
  "sounds": [],
  "meaning": "‘Sanctuary’ in Sepedi (Northern Sotho) – a name Sepedi speakers already used for the area.",
  "formerNameOrigin": "Pietersburg (1886) honoured Voortrekker leader Petrus Jacobus (Piet) Joubert.",
  "sources": ["https://en.wikipedia.org/wiki/Polokwane"]
}
```

- `sounds` uses the codes in `lib/utils/sound_guide.dart` (`c`, `q`, `x`,
  `gq`, `nq`, `rh`, `hl`, `aspirated`, …); add a code there before using
  it.
- `name` must match the town's current name. If a user renames a town in
  the app, its story stops showing because it no longer applies.
- Stories aren't stored in the database, so a corrected file reaches
  everyone with the next app update; no `seedVersion` bump is needed.
- `test/name_stories_test.dart` checks that every renamed town has an
  entry, every key matches a town, every sound code exists and every
  meaning or origin has a source.

## Sharing the app, and the zoom-out button

- **Share this app** (share icon in the top bar) shows a 1080 × 1350
  picture with the app icon, what the app does, a Pietersburg → Polokwane
  example and "Free on Google Play and the App Store", and sends it with a
  short description and where to find the app on each phone
  (`lib/widgets/app_promo_card.dart`). The store details are in
  `lib/config/app_info.dart`: the Google Play link is built from
  `kAndroidAppId`; once the iPhone version exists, put its Apple ID in
  `kAppStoreId` to add an App Store link (until then the message says to
  search the App Store). If the app is only on Google Play, set
  `kOnAppStore = false`.
- The **zoom-out button** (top right of the map) glides back to the
  opening view of the whole country.

## Timeline and share cards

**Timeline.** The timeline icon in the top bar opens a slider from
"Then" (every previous name) to "Today" (this year), with a play button that steps
through the years. Each town shows the name it had in the chosen year,
using its rename year. Renames with no recorded year (mostly in
KwaZulu-Natal) switch at "Today", and the panel says so. The map's
old/current toggle is hidden while the timeline is open.

**Sharing a town's info.** Every renamed town's sheet has a share icon,
and so does "Where am I?" when your town is renamed. Sharing sends exactly
what the sheet shows, in the same order: the name (the previous name first
when the map is showing previous names), the place, the previous or
current name, the rename year, the notes, and the name story
(pronunciation with sound tips, what both names mean, sources). It shows
a preview and shares a picture of that info (1080 pixels wide, at least
1350 tall, longer for long stories) plus the same info as text, ending
with a link to the app, through the normal share sheet (WhatsApp,
Instagram, Messages, …). Both are built from one list
(`townInfo` in `lib/utils/town_info.dart`), so they always match.

- The link is the Google Play page. To use a different one (for example a
  small page linking both stores), set `kShareUrl` in
  `lib/config/app_info.dart`.
- **iOS:** add this to `ios/Runner/Info.plist`. Without it, the app
  crashes if someone picks "Save Image" in the share sheet:

  ```xml
  <key>NSPhotoLibraryAddUsageDescription</key>
  <string>Lets you save shared town info pictures to your photos.</string>
  ```

## Live town-name updates

New renames reach users without an app release. The data is published
from the GitHub repository **nicos0351/then-and-now-data** at
`https://nicos0351.github.io/then-and-now-data/data.json`
(`kRemoteDataUrl` in `lib/services/remote_data_service.dart`).

- **Last refreshed:** the "Refresh data" item in the ⋮ menu shows when
  the data was last refreshed ("Today, 13:45", "3 days ago", …), and the
  About screen shows that plus the data version. After 30 days without a
  successful refresh, a small dot appears on the ⋮ button and the time is
  shown in red, as a nudge.
- **In the app:** ⋮ → **Refresh data** checks right away. The map also
  checks quietly about once a week when it opens. If the file's
  `dataVersion` is higher than the phone's, the towns and name stories
  update and a "What's new" note lists the changes. With no connection,
  the app simply keeps what it has.
- **Safety:** the download is fully checked before anything changes. It
  is rejected if it isn't valid JSON, has an unknown `format`, has fewer
  than 900 towns, or has a duplicate key, an unknown province or a town
  outside South Africa. The update runs in one database transaction, so
  it either fully applies or not at all. Towns the user edited or added
  are never touched.
- **Versions:** the bundled data (`DatabaseHelper.seedVersion`) and the
  live file's `dataVersion` share one number sequence. Before each app
  release, copy the latest `data.json` towns and stories into
  `assets/towns.json` and `assets/name_stories.json`, and set
  `seedVersion` to its `dataVersion`. That way new installs start current,
  and nobody is ever moved back to older data.
- **Publishing an update:** see the data repository's README. In short,
  edit `data.json`, raise `dataVersion`, add a `changes` line, and merge.
  An automatic check on GitHub validates every change first. A monthly
  scheduled check proposes new gazetted renames as pull requests for you
  to approve.

## Notes on scope

- **Roads**: OpenStreetMap's standard tile layer already renders the full
  road network for South Africa as part of the base map image — no
  separate roads dataset is required. If you'd rather have roads as
  tappable/queryable vector data (not just a picture), that needs a vector
  tile source and is a bigger addition — let me know if you want that
  routed in instead.
- **Attribution**: the map shows a permanent credit for the tile
  provider and GeoNames, and About & credits gives the full CC BY 4.0
  notice for GeoNames and the OpenStreetMap licence link. If you add
  other data sources, credit them in `about_screen.dart` too. It doesn't
  hurt to repeat "Place data © GeoNames.org, CC BY 4.0" and "Map data
  © OpenStreetMap contributors" in the store listing.
- **Reverted names**: a couple of towns (Louis Trichardt, Vaalwater) were
  renamed and then renamed back — these are flagged with `reverted: true`
  and a note so the toggle behaviour stays sensible.
- **Duplicate place names**: South Africa has several towns that share a
  name across different provinces (e.g. two Springs, two Middelburgs) —
  these are kept as separate markers since they're genuinely different
  places; only true duplicate records for the *same* town were merged.
