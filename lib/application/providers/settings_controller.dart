import 'package:flutter_riverpod/flutter_riverpod.dart';

/// User-tunable runtime settings (no UI screen — kept minimal per the 2-view
/// design, but centralized so policies are testable).
class Settings {
  const Settings({
    this.preBufferLeadSeconds = 30,
    this.audioCacheCapBytes = 500 * 1024 * 1024,
    this.artworkCacheCapBytes = 200 * 1024 * 1024,
    this.preBufferOnMetered = true,
  });

  final int preBufferLeadSeconds;
  final int audioCacheCapBytes;
  final int artworkCacheCapBytes;

  /// When on a metered connection, still pre-buffer (only the single next
  /// track). Set false to disable pre-buffering on mobile data entirely.
  final bool preBufferOnMetered;

  Settings copyWith({
    int? preBufferLeadSeconds,
    int? audioCacheCapBytes,
    int? artworkCacheCapBytes,
    bool? preBufferOnMetered,
  }) {
    return Settings(
      preBufferLeadSeconds: preBufferLeadSeconds ?? this.preBufferLeadSeconds,
      audioCacheCapBytes: audioCacheCapBytes ?? this.audioCacheCapBytes,
      artworkCacheCapBytes: artworkCacheCapBytes ?? this.artworkCacheCapBytes,
      preBufferOnMetered: preBufferOnMetered ?? this.preBufferOnMetered,
    );
  }
}

class SettingsController extends Notifier<Settings> {
  @override
  Settings build() => const Settings();

  void setPreBufferOnMetered(bool enabled) =>
      state = state.copyWith(preBufferOnMetered: enabled);
}

final settingsControllerProvider =
    NotifierProvider<SettingsController, Settings>(SettingsController.new);
