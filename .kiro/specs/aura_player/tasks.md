# Aura Player — Implementation Plan

Each task is a discrete, test-driven coding step. Tasks are ordered so every step builds on previously completed work. The `_Requirements:_` reference traces each task to `requirements.md`. This plan reflects the **cloud-streaming, $0-backend** model: there is **no local file scanning** — discovery comes from a public metadata API, audio is resolved on-device, and only user data (favorites/playlists/history) is stored locally.

---

## Phase 0 — Project Foundation

- [ ] 1. Scaffold the Flutter project and toolchain
  - Run `flutter create` with `--platforms=android,macos` and org/bundle id; set Dart/Flutter constraints in `pubspec.yaml`.
  - Add dependencies: `flutter_riverpod`, `riverpod_annotation`, `just_audio`, `audio_service`, `just_audio_background`, `isar`, `isar_flutter_libs`, `palette_generator`, `go_router`, `freezed_annotation`, `dio`, `youtube_explode_dart`, `flutter_cache_manager`, `cached_network_image`, `connectivity_plus`; dev deps: `build_runner`, `riverpod_generator`, `freezed`, `isar_generator`, `flutter_lints`, `leak_tracker`.
  - Configure strict `analysis_options.yaml` (warnings as errors) and CI running `flutter analyze`, `dart format --set-exit-if-changed`, `flutter test`.
  - _Requirements: 11.1_

- [ ] 2. Establish layered structure and core utilities
  - Create `lib/{core,domain,data,application,presentation}` with `core/errors` (`Result<T>`, `Failure`, `guard`), `core/network` (dio client + retry/backoff interceptor), `core/utils` (logging), barrel files.
  - Implement `runZonedGuarded` + `FlutterError.onError` bootstrap routing uncaught errors to the logger (toast wired later).
  - _Requirements: 9.6_

- [ ] 3. Implement the design system (theme + motion + typography)
  - Add `aura_colors.dart` (pure black, graphite) and `aura_theme.dart` (dark by default).
  - Bundle Inter; configure San Francisco fallback on macOS; enable anti-aliasing + spacing scale.
  - Add `motion_tokens.dart` (`canvasMorph`, `microInteract`, `bgPulse`, `audioFadeOut` 300ms, `toast`, `preBufferLead` 30s) and a `MotionResolver` reading OS reduce-motion.
  - Golden-test base theme tokens.
  - _Requirements: 2.6, 2.7, 3.5, 4.7, 9.3, 14.1_

---

## Phase 1 — Domain Layer

- [ ] 4. Define domain entities with `freezed`
  - Create immutable `Track`, `Playlist`, `HistoryEntry`, `PlayQueue`, `PlaybackState`, `StreamInfo`, `AuraPalette`, `Settings` (pure Dart, no Flutter imports).
  - Add metadata-fallback helpers on `Track` ("Unknown Artist", title fallback).
  - Unit-test fallback logic.
  - _Requirements: 9.1_

- [ ] 5. Declare repository interfaces and use-cases
  - Define abstract `MetadataApi`, `StreamResolver`, `AudioRepository`, `UserRepository`, `SessionRepository`, `PaletteRepository`, `ConnectivityService`.
  - Implement pure use-cases: `FetchCharts`, `SearchTracks`, `ResolveStream`, `EnqueueTrack`, `AdvanceQueue` (shuffle/repeat), `PreBufferNext`, `ToggleFavorite`, `RecordHistory`, `ExtractPalette`, `RestoreSession`, `PersistSession`.
  - Unit-test queue advancement (shuffle / repeat-one / repeat-all / off) and the pre-buffer trigger predicate (≤30s remaining + next exists).
  - _Requirements: 6.8, 8.5, 14.1_

---

## Phase 2 — Persistence Layer (Isar, local user data)

- [ ] 6. Implement Isar models and store bootstrap
  - Create `FavoriteModel`, `PlaylistModel`, `HistoryModel`, `CachedTrackModel`, `ApiCacheModel`, `SessionModel`; generate adapters.
  - Implement `IsarStore` init in `main.dart`, schema version field, migration hook.
  - _Requirements: 8.1, 8.6_

- [ ] 7. Implement `IsarUserRepository` (favorites, playlists, history)
  - CRUD for favorites and user playlists; append-to-history with most-recent-first de-duplication.
  - Migration/corruption recovery that rebuilds the store while preserving recoverable user data.
  - Unit-test CRUD, history de-dup, and recovery with a temp-dir Isar instance.
  - _Requirements: 8.1, 8.2, 8.3, 8.6_

- [ ] 8. Implement metadata/response cache and `SessionStore`
  - `CachedTrackModel`/`ApiCacheModel` read/write with TTL for offline browsing; palette fields cached per track.
  - `SessionStore` persists/restores active track, queue, position, shuffle/repeat.
  - Unit-test TTL expiry and session round-trip.
  - _Requirements: 8.4, 8.5, 12.5_

---

## Phase 3 — Metadata & Discovery API

- [ ] 9. Implement the `MetadataApi` adapter (Saavn/Jamendo)
  - Build a concrete adapter over the chosen public API using the dio client; map DTOs → `Track` (id, title, artist, album, durationMs, artworkUrl).
  - Implement charts, search, and artwork-URL retrieval; keep the adapter swappable behind the interface.
  - Apply bounded retry/backoff; on persistent failure fall back to cache and emit a toast signal.
  - Unit-test DTO mapping, retry/backoff, and offline cache fallback with a mocked HTTP client.
  - _Requirements: 12.1, 12.2, 12.3, 12.4, 12.5, 12.6_

- [ ] 10. Implement network-only permissions/entitlements
  - Android: declare `INTERNET`; remove any media/storage permissions.
  - macOS: enable outbound-network sandbox entitlement only.
  - Add a `ConnectivityService` (`connectivity_plus`) exposing online/offline status.
  - _Requirements: 9.5, 11.3_

---

## Phase 4 — Client-Side Stream Resolution

- [ ] 11. Implement the `StreamResolver` adapter (client-side)
  - Implement `YoutubeStreamResolver` using `youtube_explode_dart` behind the `StreamResolver` interface; resolve a `Track` to a direct audio-only `StreamInfo` (M4A/WebM).
  - Select best audio-only stream by bitrate/platform-compatible container; run all work off the UI thread.
  - Cache resolved URLs for their validity and transparently re-resolve on expiry.
  - Keep the adapter swappable; document the ToS/licensing constraint and provide a licensed-source stub (e.g., Jamendo direct audio).
  - Unit-test best-stream selection, expiry re-resolution, and the no-compatible-stream error path with fakes.
  - _Requirements: 13.1, 13.3, 13.4, 13.5, 13.6, 13.7_

---

## Phase 5 — Cloud Streaming Audio Engine (Background Isolate)

- [ ] 12. Implement `AuraAudioHandler` on `audio_service` + `just_audio`
  - Single `BaseAudioHandler` hosting one `just_audio` `AudioPlayer`; init via `AudioService.init` in `main.dart` (single engine, app lifetime).
  - Stream a resolved remote URL (through the audio byte cache); expose `playbackState`, `mediaItem`, position, and buffer streams; implement play/pause/seek/skipNext/skipPrevious/setShuffle/setRepeat.
  - Wire OS media controls (Android MediaSession, macOS Now Playing) and background continuation.
  - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 7.1, 7.3, 10.4, 11.2_

- [ ] 13. Implement queue, focus, and device-change handling
  - Build the queue in the handler with auto-advance honoring shuffle/repeat.
  - Handle audio interruptions/focus loss (pause + resume per policy) and becoming-noisy (headphone/BT disconnect → pause).
  - _Requirements: 6.6, 6.7, 6.8_

- [ ] 14. Implement `AudioRepositoryImpl` and resolution-driven playback
  - Adapt the handler to `AudioRepository`; on play, call `StreamResolver` (off-thread) then start playback at first playable bytes.
  - On resolution/decode failure: skip to next playable track + emit error event (toast wired in Phase 9).
  - Unit-test resolve-then-play and skip-on-error with a fake player/resolver.
  - _Requirements: 6.2, 7.1, 7.3, 9.2, 13.2_

---

## Phase 6 — Media Caching & Zero-Lag Pre-Buffering

- [ ] 15. Implement `AudioByteCacheManager` and `ArtworkCache`
  - Configure `flutter_cache_manager` for streamed audio bytes (dedup, LRU, bounded cap) and wire it as the audio source.
  - Configure `cached_network_image` for artwork (instant render, dedup).
  - Unit-test dedup of concurrent fetches and LRU eviction at the cap.
  - _Requirements: 14.3, 14.4, 14.5, 10.7_

- [ ] 16. Implement `preBufferControllerProvider` (30s lead, gapless)
  - Subscribe to position; when remaining ≤ `preBufferLead` (30s) and a next track exists, resolve + warm the byte cache and stage the next source in just_audio for a gapless transition.
  - Respect a metered-network guard (only pre-buffer the single next track, honor cache cap); retry at transition on pre-buffer failure without interrupting the current track.
  - Unit-test the 30s trigger, gapless staging, metered guard, and failure-retry behavior.
  - _Requirements: 14.1, 14.2, 14.6, 14.7_

---

## Phase 7 — Application/State Layer (Riverpod)

- [ ] 17. Implement discover, search, and player controllers
  - `discoverControllerProvider` (`AsyncNotifier`): cached-first charts then reconcile without scroll reset.
  - `searchControllerProvider` (`AsyncNotifier`): debounced API search, incremental off-thread filtering.
  - `playerControllerProvider` (`Notifier`): bridge `AudioRepository` intents/state; trigger resolution on play.
  - `queueControllerProvider`, `settingsControllerProvider` (theme, reduce-motion, cache cap, metered policy).
  - Unit-test with provider overrides + fakes.
  - _Requirements: 1.2, 1.3, 1.4, 1.5, 5.4, 5.5, 8.2_

- [ ] 18. Implement smooth-position, buffer, library, and toast controllers
  - `positionStreamProvider` feeding only the progress widget with frame-rate interpolation (no snapping); `bufferStateProvider` for a non-blocking loading indicator.
  - `libraryControllerProvider` for favorites/playlists/history (local).
  - `toastControllerProvider`: single active, auto-dismiss, non-stacking (new replaces current).
  - Unit-test toast replacement and history recording.
  - _Requirements: 5.2, 7.5, 8.2, 8.3, 9.7_

- [ ] 19. Implement `paletteControllerProvider` + `connectivityProvider`
  - `FutureProvider.family<AuraPalette, TrackId>`: return cached palette or run `palette_generator` via `Isolate.run` on the cached artwork; persist result; fall back to default graphite/black on failure.
  - `connectivityProvider` (`StreamProvider`) exposing online/offline for resilience + offline UI.
  - Unit-test palette cache hit/miss/fallback.
  - _Requirements: 4.1, 4.5, 4.6, 8.4, 9.5_

---

## Phase 8 — Presentation

- [ ] 20. Build `DiscoverView` with charts, lazy list, and offline state
  - Render trending charts + `TrackTile` rows (title, artist, lazy `cached_network_image` thumbnail with neutral placeholder on failure); preserve scroll across reconcile.
  - Minimal empty/offline state with retry action.
  - Widget-test offline state and placeholder behavior.
  - _Requirements: 1.1, 1.2, 1.6, 1.7, 1.8_

- [ ] 21. Implement debounced search UI
  - Search affordance that queries the API and filters results incrementally/debounced without blocking the UI thread.
  - Widget-test incremental results + empty query state.
  - _Requirements: 1.4_

- [ ] 22. Build `NowPlayingCanvas` shell
  - Two-route navigation only; render artwork/title/artist; controls hidden by default, revealed on interaction; downward-swipe dismiss keeps playback running; favorite/add-to-playlist affordance persisting locally.
  - Widget-test control reveal/hide, dismiss-keeps-playback, favorite toggle.
  - _Requirements: 2.1, 2.3, 2.4, 2.5, 2.8_

- [ ] 23. Implement `BlurGradientBackground`
  - Gradient from `AuraPalette` with heavy `ImageFiltered` blur; slow pulse; `AnimatedSwitcher` cross-fade on palette change; static gradient when reduce-motion is on.
  - Golden-test default and palette-driven backgrounds.
  - _Requirements: 4.2, 4.3, 4.4, 4.7_

- [ ] 24. Implement `PlayPauseMorph`, interpolated `ProgressBar`, and skip/shuffle/repeat
  - Vector-interpolated play/pause morph (not image swap); gliding progress bar with scrub preview + seek-on-release; next/prev and animated shuffle/repeat toggles; haptic/visual confirmation.
  - Widget-test scrub seek-on-release and toggle animations.
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6_

---

## Phase 9 — Transitions, Toasts & Connection Resilience

- [ ] 25. Implement the shared-element morph transition
  - `MorphPageRoute` + `Hero(tag: trackId)` reusing the same `cached_network_image` provider via `flightShuttleBuilder` (no re-download/flash); eased 250–400 ms; reverse on return.
  - Reduce-motion substitutes a cross-fade; debounce navigation to avoid duplicate heroes.
  - Widget-test morph forward/back and reduce-motion fallback.
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6_

- [ ] 26. Implement `AuraToast` overlay and connection resilience
  - Subtle overlay driven by `toastControllerProvider`; connect metadata-API, resolution, decode, and global-guard errors to emit toasts (auto-dismiss, non-stacking).
  - On stream drop (via `connectivityProvider`): fade audio out over ~300 ms, show network toast, attempt bounded reconnect, and resume from last position on restore.
  - Widget/unit-test fade-out timing, reconnect, resume-from-position, and non-stacking toasts.
  - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5, 9.6, 9.7_

---

## Phase 10 — Lifecycle, Memory & Session Restore

- [ ] 27. Implement `AppLifecycleObserver` and disposal discipline
  - `WidgetsBindingObserver` for `paused`/`detached`: release artwork/palette caches + pause pre-buffer/palette workers while keeping the audio stream alive; on `detached` dispose audio engine and close Isar.
  - Ensure all `AnimationController`s are disposed and providers use `autoDispose`; low-memory eviction of in-memory + bounded on-disk caches.
  - _Requirements: 10.1, 10.2, 10.3, 10.6, 10.7_

- [ ] 28. Restore last session on launch
  - Restore active track, queue, position, shuffle/repeat from `SessionStore`; re-resolve the active stream lazily on resume; persist context on relevant state changes.
  - _Requirements: 8.5, 13.4_

---

## Phase 11 — Verification & Hardening

- [ ] 29. Author integration tests for primary flows
  - End-to-end: search → tap → morph → resolve → stream → background continuation → OS control → dismiss; plus offline, stream-drop fade-out, and resolution-failure/skip paths.
  - _Requirements: 1.4, 1.5, 2.1, 2.4, 3.1, 6.2, 6.3, 6.4, 9.2, 9.3, 13.2_

- [ ] 30. Add leak and performance verification
  - `leak_tracker` test asserting no retained controllers/subscriptions across repeated Discover↔Now Playing navigation.
  - Profile-mode frame-timing during transitions and while buffering (no jank > 16ms @60Hz / 8ms @120Hz); verify pre-buffer yields no audible gap.
  - _Requirements: 7.2, 10.5, 11.4, 14.2_

- [ ] 31. Cross-platform release validation
  - Build and smoke-test Android and macOS release artifacts; verify streaming background playback, OS media controls, network-only permissions/entitlements, and high-refresh rendering on each platform.
  - Confirm no unused assets/dependencies and that the configured `StreamResolver`/`MetadataApi` sources are used in line with their ToS/licensing.
  - _Requirements: 6.3, 6.4, 11.1, 11.2, 11.3, 11.4, 11.5, 12.6, 13.6_
