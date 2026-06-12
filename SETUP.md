# Aura Player — Build & Run

A 100% ad-free, cloud-streaming, `$0`-backend music player for **Android** and
**macOS**, built with Flutter. Discovery via the public **Jamendo** API
(CC-licensed), local-only user data via **Isar**, and on-device stream
resolution.

> This repository contains the complete `lib/` source, `pubspec.yaml`, lint
> config, and the platform overrides (Android manifest + Kotlin activity, macOS
> entitlements). It does **not** contain the full generated platform build
> system (Gradle wrapper, Xcode project, etc.) or the generated code
> (`*.g.dart`, `*.freezed.dart`). The steps below generate those.

## Prerequisites

- Flutter SDK **3.19+** (Dart 3.3+). Check with `flutter doctor`.
- Android: Android Studio + SDK (for the APK).
- macOS: Xcode (for the desktop build).

## 1. Generate the platform build system

The platform folders here only carry the files we customize. Generate the rest
(Gradle, Xcode project, launcher resources) without clobbering our sources:

```bash
flutter create --org com.aura --project-name aura_player --platforms=android,macos .
```

`flutter create` will regenerate some platform files. Re-apply our three
customized platform files afterward (they are the source of truth):

```bash
git checkout -- \
  android/app/src/main/AndroidManifest.xml \
  android/app/src/main/kotlin/com/aura/player/MainActivity.kt \
  macos/Runner/DebugProfile.entitlements \
  macos/Runner/Release.entitlements
```

> If `flutter create` placed `MainActivity.kt` under a different package path,
> keep ours at `android/app/src/main/kotlin/com/aura/player/` and update the
> `applicationId`/namespace in `android/app/build.gradle(.kts)` to
> `com.aura.player`.

## 2. Add the Inter font (optional but recommended)

Place the four Inter TTFs in `assets/fonts/` (see `assets/fonts/README.md`).
On macOS the app falls back to San Francisco if these are absent, so it still
runs without them.

## 3. Install dependencies

```bash
flutter pub get
```

## 4. Run code generation (Freezed + Isar)

The entities use Freezed/json_serializable and the database uses Isar; both
require generated code:

```bash
dart run build_runner build --delete-conflicting-outputs
```

This produces the `*.freezed.dart`, `*.g.dart`, and Isar collection files. Re-run
after changing any `@freezed` entity or `@collection` model. For iterative work:

```bash
dart run build_runner watch --delete-conflicting-outputs
```

## 5. Analyze & run

```bash
flutter analyze
flutter run                 # pick an Android or macOS device
```

## 6. Build release artifacts

Android APK:

```bash
flutter build apk --release
# output: build/app/outputs/flutter-apk/app-release.apk
```

Android App Bundle (for Play):

```bash
flutter build appbundle --release
```

macOS app:

```bash
flutter build macos --release
# output: build/macos/Build/Products/Release/aura_player.app
```

## Architecture (quick map)

```
lib/
  core/          theme, motion tokens, Result/Failure, dio client
  domain/        entities (freezed), repository interfaces, use-cases
  data/          Jamendo/Saavn APIs, youtube resolver, audio_service handler,
                 Isar models + repos, caches, palette, connectivity
  application/   Riverpod providers/controllers (state)
  presentation/  Discover + Now Playing UI, transitions, toast, lifecycle
```

- **State:** Riverpod (manual providers — see note below).
- **Audio:** `just_audio` + `audio_service` (`BaseAudioHandler`) + `audio_session`.
- **Resolver:** prefers Jamendo's direct CC-licensed `audio` URL; falls back to
  `youtube_explode_dart` only for tracks without a direct URL.
- **DB:** Isar (favorites, playlists, history, metadata/palette/api caches, session).

### Notes / deviations from the original brief

1. **Riverpod providers are hand-written**, not generated with
   `riverpod_generator`. Stacking a third codegen system (on top of Freezed +
   Isar) increased build-break risk with no functional benefit; the manual
   providers are idiomatic and behave identically. `riverpod_generator` is left
   in `dev_dependencies` if you prefer to migrate.
2. **`just_audio_background` was removed** — it conflicts with `audio_service`
   (both own the media session). We use `audio_service`'s `BaseAudioHandler`,
   exactly as the audio-engine requirement specified.
3. **`audio_session` was added** — it is the standard companion required to
   implement audio-focus-loss and becoming-noisy (headphone unplug) pausing.
4. **Compliance:** the default playback path uses Jamendo's CC-licensed direct
   audio. `youtube_explode_dart` is a fallback for personal/local use only;
   using it to stream copyrighted content may violate YouTube's ToS. The
   resolver is a swappable interface so you can restrict it to licensed sources.
5. **Jamendo key:** uses the public `client_id=b6747d04`. Register a free key at
   jamendo.com and set it in `JamendoMetadataApi` for production.
