# Aura Player — Design & Architecture

## Overview

Aura Player is a Flutter application architected around two principles: **(1) the UI thread does nothing but render at the display's refresh rate**, and **(2) there is no backend — every byte comes from public APIs and on-device resolution, every piece of user data stays local.**

The app is **100% cloud-streaming, ad-free, and $0-backend**. There is **no local file scanning**. Discovery, charts, search, and high-resolution artwork are fetched from a public **Metadata API** (Saavn wrapper or Jamendo) behind a swappable adapter. Playable audio is produced on-device by a **Stream Resolver** that turns a `Track` into a direct M4A/WebM URL at play time. Favorites, playlists, and history persist locally (Isar). Streamed audio bytes and artwork are cached to guarantee zero-lag, gapless playback on mobile networks.

All audio resolution, network buffering, decoding, palette extraction, and persistence I/O happen off the main isolate.

This document maps the requirements in `requirements.md` to a concrete architecture, technology selection, data flow, and a testing/quality strategy that enforces the zero-bug policy.

---

## Technology Decisions

| Concern | Choice | Rationale |
|---------|--------|-----------|
| **State management** | **Riverpod (v2, code-gen `@riverpod`)** | Compile-time-safe, testable, no `BuildContext` coupling, fine-grained rebuilds, trivial provider overrides in tests. |
| **Audio core** | **`just_audio`** + **`audio_service`** + **`just_audio_background`** | Streams a remote URL with background buffering off the UI thread; `audio_service` provides the background isolate, OS media controls, and audio-focus handling; supports a concatenating/queue source for gapless pre-buffer. |
| **Metadata & discovery** | **`MetadataApi` adapter** over a public Saavn wrapper or **Jamendo API** (via `dio`/`http`) | $0-cost public charts/search/artwork; adapter keeps the provider swappable (Req 12.3). Jamendo (CC-licensed) is the compliance-safe default. |
| **Stream resolution** | **`StreamResolver` adapter** (default `youtube_explode_dart`, client-side) | On-device extraction of a direct audio-only stream at play time (Req 13). Implemented behind an interface so sources can be swapped to fully-licensed catalogs. |
| **Audio byte cache** | **`flutter_cache_manager`** (custom cache config) | Caches streamed audio bytes to avoid re-downloads and back gapless replay (Req 14.3). |
| **Artwork cache** | **`cached_network_image`** + `flutter_cache_manager` | Instant artwork rendering, dedup downloads (Req 14.4). |
| **Local storage** | **Isar** | Fast indexed NoSQL for favorites, playlists, history, and metadata/palette cache; async + isolate-friendly; migration hooks. |
| **Palette extraction** | **`palette_generator`** via **`Isolate.run`/`compute`** | CPU-bound quantization off the UI thread (Req 4.5, 7.1). |
| **Connectivity** | **`connectivity_plus`** | Detect drops/restores to drive fade-out + reconnect (Req 9.3, 9.4). |
| **Animation** | Flutter built-ins (`Hero`, `AnimatedBuilder`, `TweenAnimationBuilder`), `AnimatedIcon`/`rive`, `flutter_animate` | Vector icon morph (Req 5.1); shared-element morph via custom `PageRouteBuilder` + `Hero`. |
| **Routing** | `go_router` (2 routes) or a single `Navigator` with a custom morph route | Only two surfaces. |
| **Toasts** | Custom overlay widget | Full control over subtle, non-stacking toast behavior (Req 9.7). |

### Rejected / deferred alternatives
- **Local MediaStore scanning / `on_audio_query`**: **removed** — the product is now cloud-streaming only; no scanning, no storage-read permissions.
- **Self-hosted backend / proxy resolver**: rejected to keep hosting cost at **$0**; resolution is client-side.
- **BLoC**: viable, but Riverpod overrides give cleaner test isolation for this small surface.
- **audioplayers**: lighter, but `just_audio` + `audio_service` has stronger remote-streaming, gapless, and background support.

### Compliance posture (important)
The `StreamResolver` is a **source-agnostic interface**. The default `youtube_explode_dart` adapter extracts streams client-side; **using it to bypass ads on copyrighted content conflicts with YouTube's ToS and content licensing.** Because resolution is pluggable, a fully-licensed/CC source (e.g., Jamendo direct audio) can be configured without touching application or presentation layers (Req 13.6). Source selection is a deliberate configuration decision by the operator/developer.

---

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         PRESENTATION                              │
│  Widgets (stateless) · Riverpod ConsumerWidgets · Animations      │
│  ┌───────────────────────┐        ┌──────────────────────────┐   │
│  │ DiscoverView          │  morph │ NowPlayingCanvas          │   │
│  │ (charts, search,      │◄──────►│ (artwork, blur bg, ctrls, │   │
│  │  favorites, offline)  │        │  favorite/playlist)       │   │
│  └───────────────────────┘        └──────────────────────────┘   │
│            ▲ watch                          ▲ watch               │
└────────────┼────────────────────────────────┼────────────────────┘
             │ (immutable state, streams)      │
┌────────────┴────────────────────────────────┴────────────────────┐
│                       APPLICATION / STATE                         │
│  Riverpod Providers (Notifiers)                                   │
│   • DiscoverController   • SearchController    • PlayerController  │
│   • QueueController      • PreBufferController • PaletteController │
│   • LibraryController(favorites/playlists/history)                │
│   • ConnectivityController • SettingsController • ToastController  │
└────────────┬────────────────────────────────┬────────────────────┘
             │ calls                           │ calls
┌────────────┴────────────────────────────────┴────────────────────┐
│                            DOMAIN                                 │
│  Entities: Track, Playlist, HistoryEntry, PlayQueue,              │
│            PlaybackState, AuraPalette, StreamInfo                 │
│  Use-cases: FetchCharts, SearchTracks, ResolveStream,             │
│            EnqueueTrack, PreBufferNext, ToggleFavorite,           │
│            RecordHistory, ExtractPalette, RestoreSession          │
│  Repository interfaces (pure Dart, no Flutter imports)            │
└────────────┬────────────────────────────────┬────────────────────┘
             │ implements                      │ implements
┌────────────┴────────────────────────────────┴────────────────────┐
│                        DATA / SERVICES                            │
│  AuraAudioHandler (audio_service bg isolate, just_audio)          │
│  MetadataApi adapter (Saavn/Jamendo)  ·  StreamResolver adapter   │
│      (youtube_explode_dart / licensed source)                     │
│  AudioByteCache (flutter_cache_manager) · ArtworkCache (CNI)      │
│  IsarUserRepository (favorites/playlists/history/metadata cache)  │
│  PaletteService (compute) · SessionStore · ConnectivityService    │
└───────────────────────────────────────────────────────────────────┘
            │ HTTPS (public APIs) · FFI / MethodChannel
┌───────────┴───────────────────────────────────────────────────────┐
│   PUBLIC APIs (metadata) · Resolved CDN streams · OS media ctrls   │
│   Android MediaSession · macOS Now Playing                        │
└───────────────────────────────────────────────────────────────────┘
```

**Dependency rule:** dependencies point inward. Domain has zero Flutter/plugin imports. Both `MetadataApi` and `StreamResolver` are domain-declared interfaces implemented in the data layer, so providers can be swapped freely.

---

## Module / Folder Structure

```
lib/
  main.dart                       # bootstrap: Isar, audio_service, caches, ProviderScope
  app.dart                        # MaterialApp, theme, 2-route router
  core/
    theme/                        # AuraTheme: pure-black palette, Inter typography, motion tokens
    motion/                       # durations, curves, reduce-motion resolver
    errors/                       # Failure types, Result<T>, guard helpers
    network/                      # dio client, retry/backoff interceptor
    utils/
  domain/
    entities/                     # Track, Playlist, HistoryEntry, PlayQueue, StreamInfo, AuraPalette
    repositories/                 # MetadataApi, StreamResolver, UserRepository,
                                  #   AudioRepository, SessionRepository
    usecases/                     # FetchCharts, SearchTracks, ResolveStream, PreBufferNext,
                                  #   ToggleFavorite, RecordHistory, ExtractPalette, RestoreSession
  data/
    metadata/                     # SaavnMetadataApi / JamendoMetadataApi + DTO mappers
    resolver/                     # YoutubeStreamResolver (client-side) + interface impl
    audio/                        # AuraAudioHandler (audio_service), AudioRepositoryImpl
    cache/                        # AudioByteCacheManager (flutter_cache_manager), ArtworkCache
    user/                         # IsarUserRepository, Isar models (favorites/playlists/history)
    palette/                      # PaletteService (compute), PaletteCache
    session/                      # SessionStore (Isar)
    connectivity/                 # ConnectivityService (connectivity_plus)
    platform/                     # PermissionService (network only), platform channels
  application/
    providers/                    # Riverpod providers + Notifiers (controllers)
    state/                        # immutable state classes (freezed)
  presentation/
    discover/                     # DiscoverView, ChartSection, SearchField, TrackTile, OfflineState
    now_playing/                  # NowPlayingCanvas, BlurGradientBackground, ProgressBar,
                                  #   PlayPauseMorph, FavoriteButton
    transitions/                  # MorphPageRoute, shared-element wiring
    widgets/                      # AuraToast overlay, common atoms
test/                             # unit + widget + golden tests
integration_test/                 # end-to-end flows
```

---

## State Management Model (Riverpod)

All state classes are **immutable** (`freezed`). Controllers are `Notifier`/`AsyncNotifier`/`StreamNotifier` exposed by `@riverpod` providers. Network/derived providers use `autoDispose` to release subscriptions on teardown.

| Provider | Type | Responsibility | Backed by |
|----------|------|----------------|-----------|
| `discoverControllerProvider` | `AsyncNotifier<DiscoverState>` | Fetch trending charts; serve cached-first then reconcile | `MetadataApi`, `UserRepository` (cache) |
| `searchControllerProvider` | `AsyncNotifier<SearchState>` | Debounced query → API results; incremental, off-thread filtering | `MetadataApi` |
| `playerControllerProvider` | `Notifier<PlaybackState>` | Play/pause/seek/next/prev, shuffle/repeat; triggers resolution | `AudioRepository`, `StreamResolver` |
| `positionStreamProvider` | `StreamProvider<Duration>` | High-frequency position for smooth, interpolated progress | AudioHandler |
| `bufferStateProvider` | `StreamProvider<BufferState>` | Buffering/loading indicator without blocking UI | AudioHandler |
| `queueControllerProvider` | `Notifier<PlayQueue>` | Queue ordering + shuffle/repeat semantics | AudioHandler |
| `preBufferControllerProvider` | `Notifier<PreBufferState>` | **Resolve + buffer next track ~30s before current ends** | `StreamResolver`, `AudioByteCache` |
| `streamResolverProvider` | `Provider<StreamResolver>` | Swappable resolution adapter | `StreamResolver` impl |
| `metadataApiProvider` | `Provider<MetadataApi>` | Swappable metadata adapter | `MetadataApi` impl |
| `paletteControllerProvider` | `FutureProvider.family<AuraPalette, TrackId>` | Off-thread palette extraction + cache from cached artwork | `PaletteService` |
| `libraryControllerProvider` | `Notifier<LibraryState>` | Favorites, user playlists, streaming history (local) | `UserRepository` (Isar) |
| `connectivityProvider` | `StreamProvider<ConnectivityStatus>` | Drive fade-out + reconnect + offline UI | `ConnectivityService` |
| `settingsControllerProvider` | `Notifier<Settings>` | Theme, reduce-motion, cache cap, metered-network policy | `SessionStore` |
| `toastControllerProvider` | `Notifier<ToastState?>` | Single active, auto-dismiss, non-stacking | — |

**Smoothness rule (Req 5.2, 7.2):** position ticks feed only the progress widget via `AnimatedBuilder`, interpolated with a `Ticker` so the bar glides at frame rate rather than snapping to discrete stream events. Buffering state is a separate provider so a loading spinner never rebuilds the whole canvas.

**Resolution flow (Req 13.2):** `PlayerController.play(track)` → `streamResolverProvider.resolve(track)` (off-thread) → feed resolved URL (through `AudioByteCache`) into the AudioHandler → playback starts at first playable bytes.

---

## Metadata & Discovery Pipeline (Req 12)

```
DiscoverView / SearchController
   └─► metadataApiProvider (MetadataApi interface)
          ├─ Saavn wrapper adapter  ── or ──  Jamendo adapter (default, CC-licensed)
          │      dio + retry/backoff interceptor (Req 12.4)
          ├─ DTO → Track mapper (id, title, artist, album, durationMs, artworkUrl)
          └─ response cache in Isar with TTL (Req 12.5 → offline browsing of seen content)
```

- Cached-first rendering: controllers emit cached results immediately, then reconcile after the network fetch (Req 1.3).
- On persistent failure: bounded retry, fall back to cache, show non-intrusive toast + offline indicator (Req 9.5, 12.4).
- No long-lived secrets beyond what the free public API requires; all config stays local (Req 12.6).

---

## Audio Pipeline, Stream Resolution & Thread Safety

```
UI isolate                         Background audio isolate (audio_service)
──────────                         ────────────────────────────────────────
PlayerController ──intent──►        AuraAudioHandler (BaseAudioHandler)
   ▲   ▲                                │  just_audio AudioPlayer
   │   │                                │  source = AudioByteCache(resolvedUrl)
   │   └── playbackState stream ◄───────┤  (resolve/buffer/decode off UI thread)
   └────── position/buffer stream ◄─────┤  MediaSession / Now Playing controls
                                         ├─ audio focus / becoming-noisy → pause
                                         └─ queue advance (shuffle/repeat)

StreamResolver (off-thread)  ──resolved StreamInfo(url,container,bitrate)──► AudioByteCache
```

- **Req 7.1 / 7.3 / 13.7:** resolution, network buffering, and decode are off the UI thread; the UI only sends intents and listens to broadcast streams.
- **Req 13.3/13.4:** resolver picks best audio-only stream by bitrate/container; resolved URLs are cached for their validity and transparently re-resolved on expiry.
- **Req 6.6 / 6.7:** handler subscribes to interruption and becoming-noisy events and pauses accordingly.
- **Req 10.4:** exactly one `AudioPlayer`/`AudioHandler` singleton for the app lifetime.

---

## Zero-Lag Pre-Buffering & Caching Pipeline (Req 14)

```
positionStream ──► PreBufferController
   when (duration - position) ≤ 30s  AND next track exists  AND not already prepared:
        ├─ resolve next track via StreamResolver (off-thread)
        ├─ warm AudioByteCache with initial bytes (flutter_cache_manager)
        └─ stage next source in just_audio (concatenating/queue source)
   on current track complete:
        └─ transition to staged source → no audible gap (Req 14.2)

Caching:
   • AudioByteCacheManager: streamed bytes (dedup, LRU, bounded cap) (Req 14.3, 14.5, 10.7)
   • ArtworkCache (cached_network_image): instant artwork, dedup (Req 14.4)
   • Metered-network guard: respect cache cap; never pre-fetch beyond next track (Req 14.6)
   • Pre-buffer failure: retry at transition, no interruption to current track (Req 14.7)
```

The 30-second lead time is a `settingsControllerProvider` constant so it can be tuned; on metered connections the controller still pre-buffers only the single next track.

---

## Palette → Blur Background Pipeline

```
Track active ──► paletteControllerProvider(trackId)
                     │ cache hit? ─► return cached AuraPalette
                     │ miss:
                     └─► load artwork via ArtworkCache (already cached image)
                             └─► Isolate.run(PaletteGenerator)
                                    └─► AuraPalette{dominant,vibrant,muted} ─► cached

NowPlayingCanvas
  └─ BlurGradientBackground(palette)
        • gradient from palette + ImageFiltered(blur ~60–80 sigma)
        • slow pulse: AnimationController(8–12s, reverse loop)
        • AnimatedSwitcher cross-fade on palette change (Req 4.4)
        • reduce-motion ⇒ static gradient (Req 4.7)
        • extraction failure ⇒ default graphite/black gradient (Req 4.6)
```

Extraction uses the already-cached artwork bytes (no re-download) and runs off the UI thread (Req 4.5/7.1), cached per track (Req 8.4).

---

## Shared-Element Morph Transition

- Flutter `Hero` keyed by `TrackId`, wrapped in a custom `MorphPageRoute` (`PageRouteBuilder`) with a `CurveTween` (e.g., `Curves.easeOutCubic`, 320 ms — within Req 3.4).
- The artwork widget is the **same `cached_network_image` provider** in both `TrackTile` and `NowPlayingCanvas`, so `Hero` interpolates with no re-download or flash (Req 3.3); `flightShuttleBuilder` reuses the provider across the flight.
- **Interruption (Req 3.6):** debounce navigation during flight to avoid duplicate heroes.
- **Reduce-motion (Req 3.5):** `MotionResolver` swaps the morph for a `FadeTransition` route.

---

## Data Model (Isar — user data + caches, no scanned files)

```dart
@collection
class FavoriteModel {
  Id id;                       // hashed from trackId
  @Index(unique: true) String trackId;
  String title; String artist; String? album;
  int? durationMs; String? artworkUrl;
  DateTime addedAt;
}

@collection
class PlaylistModel {
  Id id;
  @Index() String name;
  List<String> trackIds;       // ordered
  DateTime createdAt; DateTime updatedAt;
}

@collection
class HistoryModel {
  Id id;
  @Index() String trackId;
  DateTime playedAt;           // most-recent-first, de-duplicated (Req 8.3)
}

@collection
class CachedTrackModel {        // metadata + palette cache (Req 8.4, 12.5)
  Id id;
  @Index(unique: true) String trackId;
  String title; String artist; String? album;
  int? durationMs; String? artworkUrl;
  int? paletteDominantArgb; int? paletteVibrantArgb; int? paletteMutedArgb;
  DateTime fetchedAt;          // TTL for cache freshness
}

@collection
class ApiCacheModel {           // raw chart/search response cache with TTL (Req 12.5)
  Id id;
  @Index(unique: true) String requestKey;
  String payloadJson;
  DateTime fetchedAt;
}

@collection
class SessionModel {            // single row: last-session context (Req 8.5)
  Id id = 0;
  String? activeTrackId;
  List<String> queueTrackIds;
  int positionMs;
  int repeatMode;              // 0 off, 1 one, 2 all
  bool shuffle;
}
```

A schema version field drives migration; a failed migration triggers a safe rebuild preserving recoverable user data (Req 8.6). Streamed audio bytes are NOT stored in Isar — they live in `flutter_cache_manager`'s bounded on-disk cache (Req 14.3, 10.7).

---

## Theme & Motion Tokens

```dart
// core/theme/aura_colors.dart
background    = Color(0xFF000000)   // pure black (Req 2.7)
surface       = Color(0xFF0A0A0A)
graphite      = Color(0xFF1C1C1E)
graphiteSoft  = Color(0xFF2C2C2E)
textPrimary   = Color(0xFFF2F2F2)
textSecondary = Color(0xFF8E8E93)

// core/motion/motion_tokens.dart
canvasMorph   = 320ms, Curves.easeOutCubic
microInteract = 180ms, Curves.easeOut
bgPulse       = 10s,  Curves.easeInOut (reversing)
audioFadeOut  = 300ms (network-drop fade, Req 9.3)
toast         = in 200ms / hold 2.6s / out 200ms
preBufferLead = 30s (next-track resolution lead time, Req 14.1)
```

Typography: **Inter** bundled for Android; San Francisco on macOS with Inter fallback. Anti-aliasing + generous spacing (Req 2.6).

---

## Error Handling & Connection Resilience (Zero-Bug Policy)

- **`Result<T>` / `Failure`** in `core/errors`: data-layer methods return `Result` rather than throwing across layers.
- **Global guards:** `runZonedGuarded` + `FlutterError.onError` route uncaught errors to a logger and the `ToastController` (Req 9.6).
- **Network resilience (`connectivity_plus`):**
  - Stream drop mid-playback → `audioFadeOut` (≈300 ms volume ramp) + network toast + bounded exponential reconnect (Req 9.3); resume from last position on restore where the source permits (Req 9.4).
  - Metadata API unreachable → cached fallback + offline indicator + retry action (Req 9.5).
- **Per-concern mapping:** missing metadata → fallbacks (Req 9.1); resolution failure / no compatible stream → skip + toast (Req 9.2, 13.5); API failure → retry/backoff + cache (Req 12.4).
- **Toasts** are single-instance, auto-dismiss, non-stacking; a new toast replaces the current one (Req 9.7).

---

## Lifecycle & Memory Management

- Every `ConsumerStatefulWidget` disposes its `AnimationController`s; `autoDispose` providers cancel stream subscriptions on teardown (Req 10.1, 10.5).
- `AppLifecycleObserver` (`WidgetsBindingObserver`): on `paused` release artwork decode caches + pause palette/pre-buffer workers while keeping the audio stream alive (Req 10.2); on `detached` close Isar and dispose the audio engine (Req 10.3).
- Single audio engine singleton (Req 10.4).
- Bounded on-disk caches (audio bytes + artwork) with LRU eviction and a configurable cap (Req 10.7, 14.6); low-memory callback evicts in-memory artwork/palette caches (Req 10.6).
- Debug leak guard / `leak_tracker` in tests verifies no monotonic growth across repeated navigation (Req 10.5).

---

## Cross-Platform Considerations (Req 11)

| Aspect | Android | macOS |
|--------|---------|-------|
| Background playback | Foreground service via `audio_service` | `audio_service` macOS + Now Playing info center |
| OS media controls | `MediaSession` notification | Control Center / media keys |
| Permissions | **INTERNET only** (no media/storage read) | **Outbound-network sandbox entitlement** only |
| Content source | Metadata API + client-side resolver | same shared code |
| High refresh | request max display refresh | ProMotion via Flutter engine |
| Input | touch gestures | pointer/trackpad + keyboard (space=play/pause, arrows) |

Network access and both adapters (`MetadataApi`, `StreamResolver`) are isolated behind interfaces; all UI/motion code is shared.

---

## Testing & Quality Strategy

| Layer | Test type | Coverage focus |
|-------|-----------|----------------|
| Domain use-cases | Unit | Queue/shuffle/repeat, fallback metadata, pre-buffer trigger logic, session restore |
| MetadataApi adapter | Unit (mock HTTP) | DTO mapping, retry/backoff, cache TTL, offline fallback |
| StreamResolver adapter | Unit (fakes) | Best-stream selection, URL-expiry re-resolve, no-stream error path |
| Repositories | Unit (temp-dir Isar) | Favorites/playlists/history CRUD, cache, migration recovery |
| Controllers (Riverpod) | Unit w/ provider overrides | State transitions on play/resolve/skip/error/connectivity |
| Pre-buffer/caching | Unit | 30s trigger, dedup, LRU eviction, metered guard |
| Connection resilience | Unit | Fade-out timing, bounded reconnect, resume-from-position |
| Widgets | Widget tests | Offline state, toast non-stacking, control reveal/hide, favorite toggle |
| Visuals | Golden tests | Theme tokens, blur background, play/pause morph frames |
| Flows | `integration_test` | Search → tap → morph → resolve → stream → background → dismiss; offline + drop paths |
| Performance | Profile/trace | Frame timing during transitions; no jank > 16ms (8ms @120Hz) |
| Leaks | `leak_tracker` | No retained controllers across repeated navigation |

CI runs `flutter analyze` (warnings as errors), `dart format --set-exit-if-changed`, and the full test suite before any release build.

---

## Requirements Traceability

| Requirement | Primary design elements |
|-------------|--------------------------|
| 1 Discover/Search | `DiscoverView`, `discoverControllerProvider`, `searchControllerProvider`, cached-first reconcile, lazy artwork, offline state |
| 2 Now Playing canvas | `NowPlayingCanvas`, 2-route nav, hidden controls, theme tokens, favorite/playlist affordance |
| 3 Shared-element morph | `MorphPageRoute` + `Hero(tag: trackId)`, shared cached image provider, `MotionResolver` |
| 4 Dynamic blur background | `paletteControllerProvider` (compute on cached artwork), `BlurGradientBackground`, pulse + cross-fade, fallbacks |
| 5 Micro-interactions | `PlayPauseMorph`, interpolated `ProgressBar`, scrub, shuffle/repeat, haptics |
| 6 Cloud streaming engine | `AuraAudioHandler` (just_audio remote source + audio_service), focus/noisy handling, queue advance |
| 7 Thread safety | background isolate, stream-based state, off-thread resolution/buffering |
| 8 Local persistence | Isar Favorite/Playlist/History/CachedTrack/Session models, cache, restore |
| 9 Error/connection resilience | `Result`/`Failure`, global guards, `connectivityProvider`, 300ms fade-out, reconnect, offline indicator, toast |
| 10 Lifecycle/memory | autoDispose providers, controller disposal, `AppLifecycleObserver`, single engine, bounded LRU caches, leak guard |
| 11 Cross-platform | shared codebase, network-only permissions, platform media-control adapters |
| 12 Metadata API | `metadataApiProvider` + Saavn/Jamendo adapters, DTO mappers, retry/backoff, TTL cache, swappable |
| 13 Stream resolution | `streamResolverProvider` + `YoutubeStreamResolver`/licensed adapter, best-stream selection, URL re-resolve, off-thread, ToS/licensing constraint |
| 14 Pre-buffer & caching | `preBufferControllerProvider` (30s lead), `AudioByteCacheManager`, `ArtworkCache`, dedup, metered guard, gapless transition |
