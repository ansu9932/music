# Aura Player — Requirements

## Introduction

Aura Player is an ultra-minimal, high-fidelity, **100% ad-free, cloud-based streaming** music player for **Android** and **macOS**, built with **Flutter**. The product objective is a soothing, fluid, zero-bloat listening experience with absolute stability and **zero backend hosting cost**.

Aura Player has **no local file scanning**. Discovery, search, charts, and high-resolution artwork are sourced dynamically from a **public music metadata API** (e.g., a public Saavn wrapper or the free Jamendo API). Playable audio is resolved on-device by a **client-side streaming engine** that looks up a track and extracts a direct audio stream at play time. All user data — favorites, playlists, and streaming history — is stored **locally** on the device (Isar/Hive), so the backend cost stays at **$0**.

The interface remains deliberately constrained to two surfaces — a unified **Discover/Search** view and a sliding **Now Playing** canvas — with controls hidden behind fluid gestures and micro-interactions.

This document captures the formal, testable requirements using the **EARS** notation (Easy Approach to Requirements Syntax):

- **Ubiquitous** — `THE SYSTEM SHALL ...`
- **Event-driven** — `WHEN <trigger> THE SYSTEM SHALL ...`
- **State-driven** — `WHILE <state> THE SYSTEM SHALL ...`
- **Unwanted behavior** — `IF <condition> THEN THE SYSTEM SHALL ...`
- **Optional** — `WHERE <feature is present> THE SYSTEM SHALL ...`

### Glossary

| Term | Definition |
|------|------------|
| **Track** | A streamable audio item with metadata (id, title, artist, album, duration, artwork URL) sourced from the metadata API. |
| **Metadata API** | A public, $0-cost music metadata/discovery service (Saavn wrapper or Jamendo) providing charts, search, and artwork. |
| **Stream resolver** | The on-device component that, at play time, resolves a `Track` to a direct, ad-free audio stream URL (M4A/WebM). Implemented behind a source-agnostic interface. |
| **Discover view** | The unified browse/search surface showing trending charts and search results. |
| **Now Playing canvas** | The full-screen surface that presents the active track, artwork, and progress. |
| **Pre-buffer** | Proactively fetching/buffering the next queued track before the current one ends to achieve gapless playback. |
| **Dominant palette** | The set of representative colors extracted from the active track's artwork. |
| **Toast** | A subtle, non-blocking, auto-dismissing notification surface. |

### Non-Functional Targets (apply globally)

- **Performance:** Sustained 60fps on baseline hardware and 120fps on high-refresh displays; no dropped frames > 1% during transitions.
- **Stability:** Zero unhandled exceptions reaching the UI; the player never crashes or freezes on API errors, stream-resolution failures, or connectivity loss.
- **Cost:** $0 backend — no server-side hosting, accounts, or storage; all user state persists locally on-device.
- **Footprint:** Cold start to interactive in ≤ 2s on mid-tier hardware; release binary free of unused assets/dependencies.
- **Accessibility:** Minimum 4.5:1 contrast for text, semantic labels on all interactive elements, and respect for the OS reduce-motion setting.
- **Content compliance:** The stream resolver SHALL be implemented as a swappable source abstraction; each configured source SHALL be used in accordance with its terms of service and content licensing.

---

## Requirement 1 — Discover / Search View

**User Story:** As a listener, I want a single uncluttered view of trending music and search, so that I can find and stream a track without navigating menus.

#### Acceptance Criteria

1. THE SYSTEM SHALL present a single unified Discover/Search view as the default landing surface after launch.
2. WHEN the Discover view opens THE SYSTEM SHALL fetch and display global trending charts from the metadata API.
3. WHEN cached chart/search results exist locally THE SYSTEM SHALL render them immediately while a fresh fetch completes in the background, then reconcile without resetting scroll position.
4. WHEN the user submits or edits a search query THE SYSTEM SHALL query the metadata API and display matching results incrementally, debounced, without blocking the UI thread.
5. WHEN the user taps a track THE SYSTEM SHALL begin resolution + playback of that track and reveal the Now Playing canvas.
6. THE SYSTEM SHALL render each row with title, artist, and a lazily loaded high-resolution artwork thumbnail served from the artwork cache.
7. IF artwork fails to load THEN THE SYSTEM SHALL render a neutral monochromatic placeholder in its place.
8. WHILE no results are available (empty search or unreachable API) THE SYSTEM SHALL display a minimal, single-message empty/offline state with a retry action.

---

## Requirement 2 — Now Playing Canvas

**User Story:** As a listener, I want an immersive Now Playing surface, so that I can focus on the music with minimal distraction.

#### Acceptance Criteria

1. WHEN playback of a track begins THE SYSTEM SHALL display the Now Playing canvas with the active track's artwork, title, and artist.
2. WHILE a track is playing THE SYSTEM SHALL update the displayed elapsed time and progress indicator continuously and smoothly.
3. THE SYSTEM SHALL hide secondary controls (volume, seek handle) by default and reveal them only on direct user interaction or while actively in use.
4. WHEN the user performs the dismiss gesture (downward swipe) on the canvas THE SYSTEM SHALL return to the Discover view while keeping playback uninterrupted.
5. THE SYSTEM SHALL present no more than the two defined surfaces (Discover/Search and Now Playing); no additional top-level navigation destinations shall exist.
6. THE SYSTEM SHALL render all typography using a clean sans-serif family (Inter or the platform San Francisco) with anti-aliasing enabled and generous whitespace.
7. WHILE the device is set to a dark system theme or by default THE SYSTEM SHALL render a monochromatic dark palette anchored on pure black (#000000) with soft graphite accents.
8. THE SYSTEM SHALL expose a favorite/add-to-playlist affordance on the canvas that persists to local storage.

---

## Requirement 3 — Shared-Element Morph Transition

**User Story:** As a listener, I want the album art to flow between views, so that the experience feels continuous and soothing rather than abrupt.

#### Acceptance Criteria

1. WHEN transitioning from the Discover view to the Now Playing canvas THE SYSTEM SHALL animate the tapped track's artwork as a single continuous shared element that scales and translates to its destination.
2. WHEN transitioning from the Now Playing canvas back to the Discover view THE SYSTEM SHALL reverse the shared-element morph so the artwork returns to its originating row.
3. WHILE a morph transition is in progress THE SYSTEM SHALL maintain visual continuity with no hard cut, flash, or artwork reload (the cached image provider is reused).
4. THE SYSTEM SHALL complete each canvas transition within 250–400 ms using an eased (non-linear) curve.
5. IF the OS reduce-motion accessibility setting is enabled THEN THE SYSTEM SHALL substitute a simple cross-fade for the morph while preserving destination state.
6. IF a transition is interrupted by a new navigation gesture THEN THE SYSTEM SHALL settle the shared element to a valid end state without leaving orphaned or duplicated artwork.

---

## Requirement 4 — Dynamic Blur Background

**User Story:** As a listener, I want the Now Playing background to reflect the current track's colors, so that each song has its own calming atmosphere.

#### Acceptance Criteria

1. WHEN a track becomes active THE SYSTEM SHALL derive a dominant palette from that track's (cached) artwork and use it to generate the Now Playing background.
2. THE SYSTEM SHALL render the background as a heavily blurred, multi-color gradient sourced from the dominant palette.
3. WHILE the Now Playing canvas is visible THE SYSTEM SHALL animate the gradient with a slow, continuous pulse that does not distract from foreground content.
4. WHEN the active track changes THE SYSTEM SHALL cross-fade smoothly from the previous palette's background to the new palette's background.
5. THE SYSTEM SHALL compute palette extraction off the main UI thread and cache the result keyed by track so repeated visits do not recompute or re-download.
6. IF a dominant palette cannot be extracted (artwork unavailable or undecodable) THEN THE SYSTEM SHALL fall back to the default graphite-on-black gradient.
7. WHILE the OS reduce-motion setting is enabled THE SYSTEM SHALL render a static gradient instead of the pulsing animation.

---

## Requirement 5 — Playback Micro-interactions

**User Story:** As a listener, I want controls that respond fluidly, so that interacting with playback feels tactile and polished.

#### Acceptance Criteria

1. WHEN the user toggles play/pause THE SYSTEM SHALL morph the icon between play and pause states via continuous vector interpolation rather than swapping discrete images.
2. WHILE a track plays THE SYSTEM SHALL advance the progress bar by smooth interpolation between position updates, exhibiting no visible jitter or snapping.
3. WHEN the user scrubs the progress bar THE SYSTEM SHALL update the preview position in real time and seek to the released position on gesture end.
4. WHEN the user requests next or previous track THE SYSTEM SHALL transition to the adjacent track in the queue and update all Now Playing elements accordingly.
5. WHEN the user toggles shuffle or repeat THE SYSTEM SHALL reflect the new mode with an immediate, animated state change on the corresponding control.
6. THE SYSTEM SHALL provide tactile/haptic or visual confirmation feedback on primary control activation where the platform supports it.

---

## Requirement 6 — Cloud Streaming Audio Engine & Background Playback

**User Story:** As a listener, I want reliable streamed playback that continues in the background, so that music keeps playing while I use other apps.

#### Acceptance Criteria

1. THE SYSTEM SHALL play audio by streaming a resolved direct audio URL (M4A/WebM) through a dedicated background audio engine, with no local-file scanning involved.
2. WHEN the user initiates playback THE SYSTEM SHALL resolve the track to a stream URL on-device and begin playback as soon as the initial buffer is ready.
3. WHILE the app is backgrounded or the screen is locked THE SYSTEM SHALL continue streaming playback uninterrupted.
4. WHEN the app is backgrounded THE SYSTEM SHALL expose playback controls and metadata to the OS media notification / Control Center / lock screen.
5. WHEN an OS media control (play, pause, next, previous, seek) is activated THE SYSTEM SHALL apply the corresponding action and reflect it in the UI on return.
6. WHEN an audio focus loss or interruption occurs (incoming call, another app) THE SYSTEM SHALL pause playback and resume per platform policy when focus returns.
7. WHEN headphones are unplugged or a Bluetooth device disconnects THE SYSTEM SHALL pause playback to avoid unexpected loud output.
8. THE SYSTEM SHALL maintain a play queue and advance to the next queued track automatically when the current track completes, honoring shuffle/repeat state.

---

## Requirement 7 — Audio Thread Safety & UI Smoothness

**User Story:** As a listener, I want a perfectly smooth UI, so that streaming, resolution, or buffering never causes the interface to stutter.

#### Acceptance Criteria

1. THE SYSTEM SHALL perform stream resolution, network buffering, and decoding off the main UI thread (in a background isolate/service).
2. WHILE a track is resolving or buffering THE SYSTEM SHALL keep the UI fully responsive and animations running at the target frame rate.
3. THE SYSTEM SHALL communicate playback and buffering state to the UI via streams/state notifications rather than blocking synchronous calls.
4. WHILE artwork or metadata is being fetched/processed THE SYSTEM SHALL not block scrolling or transitions in any view.
5. IF resolution or buffering exceeds an expected duration THEN THE SYSTEM SHALL surface a non-blocking loading indicator without freezing input.

---

## Requirement 8 — Local Persistence (Decentralized, $0 Backend)

**User Story:** As a listener, I want my favorites, playlists, and history saved on my device, so that the app needs no account or server and loads instantly.

#### Acceptance Criteria

1. THE SYSTEM SHALL persist all user data — favorites, user-created playlists, and streaming history — locally in the on-device store (Isar/Hive), with no server-side storage.
2. WHEN the user favorites a track or adds it to a playlist THE SYSTEM SHALL persist the change locally and reflect it immediately in the UI.
3. WHEN a track is played to a meaningful threshold THE SYSTEM SHALL append it to local streaming history (most-recent-first, de-duplicated).
4. THE SYSTEM SHALL cache fetched track metadata, chart/search results, extracted palettes, and artwork references locally to avoid redundant network calls.
5. THE SYSTEM SHALL persist last-session playback context (active track, queue, position, shuffle/repeat mode) and restore it on next launch.
6. IF the local store is corrupt or a schema migration fails THEN THE SYSTEM SHALL recover by rebuilding the store without crashing, preserving recoverable user data where possible.

---

## Requirement 9 — Error Handling & Connection Resilience

**User Story:** As a listener on a fluctuating mobile network, I want the player to handle drops quietly, so that bad connectivity or failed lookups never break my session.

#### Acceptance Criteria

1. IF a track has missing or incomplete metadata THEN THE SYSTEM SHALL display sensible fallbacks (e.g., "Unknown Artist") and continue normally.
2. IF stream resolution fails or returns no playable URL THEN THE SYSTEM SHALL show a subtle non-intrusive toast, skip to the next playable track, and continue without crashing.
3. IF the audio stream drops mid-playback due to network loss THEN THE SYSTEM SHALL fade the audio out smoothly over approximately 300 ms, display a non-intrusive network toast, and attempt a bounded reconnect rather than freezing.
4. WHEN connectivity is restored after a drop THE SYSTEM SHALL resume the affected track from its last known position where the source permits.
5. IF the metadata API is unreachable THEN THE SYSTEM SHALL fall back to cached results and present an offline indicator with a retry action.
6. THE SYSTEM SHALL ensure no error path results in an app crash, frozen UI, or stuck loading spinner.
7. WHEN an error/network toast is shown THE SYSTEM SHALL auto-dismiss it after a short interval and never stack so as to obscure primary content.

---

## Requirement 10 — Lifecycle, Disposal & Memory Safety

**User Story:** As a maintainer, I want all resources released deterministically, so that the app has no leaks across view changes and backgrounding.

#### Acceptance Criteria

1. WHEN a view is disposed THE SYSTEM SHALL cancel its stream subscriptions, animation controllers, and listeners.
2. WHEN the app moves to the background THE SYSTEM SHALL release non-essential resources (decoded artwork, palette workers) while preserving the active audio stream session.
3. WHEN the app is terminated THE SYSTEM SHALL release the audio engine and close the local store cleanly.
4. THE SYSTEM SHALL maintain a single shared audio engine instance for the app's lifetime and prevent duplicate concurrent players.
5. THE SYSTEM SHALL ensure repeated navigation between Discover and Now Playing does not accumulate retained controllers, subscriptions, or listeners (no monotonic memory growth).
6. IF the OS issues a low-memory warning THEN THE SYSTEM SHALL evict caches (artwork, audio byte cache, palettes) to reclaim memory while preserving playback continuity.
7. THE SYSTEM SHALL enforce a bounded on-disk audio/artwork cache size and evict least-recently-used entries when the cap is exceeded.

---

## Requirement 11 — Cross-Platform Parity (Android & macOS)

**User Story:** As a listener on either platform, I want the same fluid streaming experience, so that the app feels native and consistent everywhere.

#### Acceptance Criteria

1. THE SYSTEM SHALL build and run as a release artifact on both Android and macOS from a single shared codebase.
2. THE SYSTEM SHALL integrate background playback and OS media controls using each platform's native mechanism (Android media session / macOS Now Playing).
3. THE SYSTEM SHALL declare and use only network/internet access (no media/storage scanning permissions) appropriate to each platform, including macOS outbound-network sandbox entitlements.
4. WHERE a platform exposes high-refresh displays THE SYSTEM SHALL render animations at the display's maximum supported frame rate.
5. THE SYSTEM SHALL adapt input affordances (touch gestures on Android, pointer/trackpad and keyboard on macOS) while keeping identical visual design and motion.

---

## Requirement 12 — Metadata & Discovery API Integration

**User Story:** As a listener, I want trending charts, search, and high-res artwork sourced automatically, so that I always have fresh global content without any backend.

#### Acceptance Criteria

1. THE SYSTEM SHALL integrate a public, $0-cost music metadata API (e.g., a public Saavn wrapper or the Jamendo API) behind a single `MetadataApi` interface.
2. THE SYSTEM SHALL fetch trending/charts, search results, and high-resolution album artwork URLs through this interface and map them to the `Track` entity.
3. THE SYSTEM SHALL implement the metadata source as a swappable adapter so an alternative provider can be configured without changing application or presentation code.
4. WHEN an API request fails or times out THE SYSTEM SHALL apply bounded retry with backoff and fall back to cached data, surfacing a non-intrusive toast on persistent failure.
5. THE SYSTEM SHALL cache API responses (charts, searches, artwork references) with a sensible TTL to minimize redundant network calls and enable offline browsing of previously seen content.
6. THE SYSTEM SHALL never embed long-lived secrets in the client beyond what a free public API requires, and SHALL keep all configuration local to the device.

---

## Requirement 13 — Client-Side Audio Stream Resolution

**User Story:** As a listener, I want a track to start playing the instant I hit play, so that streaming feels immediate and ad-free.

#### Acceptance Criteria

1. THE SYSTEM SHALL resolve a `Track` to a direct, ad-free audio stream (M4A/WebM container) entirely on-device through a single `StreamResolver` interface, with no proprietary backend involved.
2. WHEN the user presses play THE SYSTEM SHALL trigger resolution and begin playback as soon as the first playable bytes are buffered.
3. THE SYSTEM SHALL select the best available audio-only stream by bitrate/quality and platform-compatible container.
4. THE SYSTEM SHALL cache resolved stream URLs for the duration of their validity and re-resolve transparently when a URL expires.
5. IF resolution returns no compatible stream THEN THE SYSTEM SHALL emit a recoverable error, skip the track, and notify the user via toast.
6. THE SYSTEM SHALL implement stream resolution as a swappable source abstraction and use each configured source in accordance with its terms of service and content licensing.
7. THE SYSTEM SHALL perform all resolution work off the main UI thread.

---

## Requirement 14 — Zero-Lag Pre-Buffering & Media Caching

**User Story:** As a listener, I want gapless playback and instant artwork, so that songs flow seamlessly even on mobile networks.

#### Acceptance Criteria

1. WHILE a track is playing and a next track exists in the queue THE SYSTEM SHALL begin resolving and pre-buffering that next track approximately 30 seconds before the current track ends.
2. WHEN the current track completes THE SYSTEM SHALL transition to the pre-buffered next track with no audible gap.
3. THE SYSTEM SHALL cache streamed audio bytes (via a media cache manager) so a replayed or resumed track is not re-downloaded.
4. THE SYSTEM SHALL cache album artwork (via a cached network image layer) so previously seen artwork renders instantly without re-download.
5. THE SYSTEM SHALL deduplicate concurrent fetches so the same stream or artwork URL is not downloaded more than once simultaneously.
6. WHILE the device is on a metered/mobile connection THE SYSTEM SHALL respect a configurable cache cap and avoid unbounded pre-fetching beyond the next queued track.
7. IF pre-buffering of the next track fails THEN THE SYSTEM SHALL retry at track transition and fall back gracefully without interrupting the currently playing track.
