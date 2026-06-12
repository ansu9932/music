import 'package:freezed_annotation/freezed_annotation.dart';

part 'track.freezed.dart';
part 'track.g.dart';

/// A streamable audio item sourced from the metadata API.
///
/// [directAudioUrl] is the Jamendo CC-licensed, directly-playable stream when
/// available. When null, the [StreamResolver] must resolve a stream on-device.
@freezed
class Track with _$Track {
  const factory Track({
    required String id,
    required String title,
    required String artist,
    String? album,
    @Default(0) int durationMs,
    String? artworkUrl,
    String? directAudioUrl,
  }) = _Track;

  const Track._();

  factory Track.fromJson(Map<String, dynamic> json) => _$TrackFromJson(json);

  /// Title with a non-empty fallback.
  String get displayTitle => title.trim().isEmpty ? 'Unknown Title' : title;

  /// Artist with a non-empty fallback.
  String get displayArtist => artist.trim().isEmpty ? 'Unknown Artist' : artist;

  /// True when the track exposes a directly-playable, licensed audio URL and
  /// requires no client-side stream extraction.
  bool get hasDirectAudio =>
      directAudioUrl != null && directAudioUrl!.trim().isNotEmpty;

  Duration get duration => Duration(milliseconds: durationMs);

  /// Stable Hero tag for the shared-element morph transition.
  String get heroTag => 'artwork-$id';
}
