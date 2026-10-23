# Nebula (Android-first Flutter)

## Build with GitHub Actions
Every push to `main` builds everything and publishes a GitHub Release (named "Nebula build N") with:
- `nebula-universal.apk`: one APK for any phone (easiest to install)
- `nebula-arm64-v8a.apk`, `nebula-armeabi-v7a.apk`, `nebula-x86_64.apk`: smaller per-architecture builds
- `nebula.aab`: app bundle

From your phone: open the repo in a browser, tap Releases, and tap the APK to download and install it.
The same files are also in the run's `nebula-android` artifact. Push a tag like `v0.1.0` for a non-prerelease.
APKs are signed with the debug key: fine for sideloading, not for the Play Store.
If the build fails, the compile error is in the "Build everything" step log.

## Build locally
    flutter create --platforms=android --project-name nebula --org com.nebula .
    rm -f test/widget_test.dart
    python3 scripts/setup_android.py
    flutter pub get && flutter gen-l10n
    flutter run        # or: flutter build apk --release --split-per-abi

`scripts/setup_android.py` adds the internet permission, cleartext HTTP (some addons use http), PiP support,
and sets minSdk 24.

## Player
media_kit (libmpv): hardware decoding, embedded and external subtitle tracks (srt/vtt/ass), audio-track
switching, speed 0.25x-4x, pitch control, HTTP headers, aspect/fill modes, PiP (via `floating`).

## Addons
Install by manifest URL (Addons page, from Profile). Supports catalog, meta, stream and subtitles resources.
Only streams with a direct http(s) URL are playable, which is what debrid-configured addons return;
torrent-only (infoHash/magnet) results are hidden. Installed addon URLs are stored unencrypted on the device
and may contain your debrid key, so don't share backups or sync files that include them. (Sync export does not include addons.)

## Implemented
Home with reorderable sections, addon catalog rows, filters, mock CF recommendations, infinite-scroll Movies/TV
(shimmer), Live TV with mock EPG, detail pages with episodes and stream picker, resume playback, online subtitle
search via addons, neon subtitle style with mock translation, resumable downloads + offline playback, watch
history/profile stats, catalog builder, JSON sync export/import, Nebula Lens, stats overlay, skip-intro (sample metadata only).

## Not built
Chromecast/AirPlay and screen mirroring (dropped), built-in torrent engine (use addons + debrid), original-language
audio detection (use the audio menu), background playback service/notification, Firebase sync, proxy addon,
mood/language filters, full i18n (few strings localized), auto-quality for non-adaptive streams (direct files have one quality).

<!-- CI verification trigger: analyzer policy fix -->
