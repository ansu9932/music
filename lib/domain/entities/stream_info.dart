import 'package:freezed_annotation/freezed_annotation.dart';

part 'stream_info.freezed.dart';
part 'stream_info.g.dart';

/// Where a resolved stream URL originated.
enum StreamSource { jamendoDirect, youtube }

/// A resolved, directly-playable audio stream for a [Track].
@freezed
class StreamInfo with _$StreamInfo {
  const factory StreamInfo({
    required String url,
    required String container, // 'mp3' | 'm4a' | 'webm'
    @Default(0) int bitrateBps,
    required StreamSource source,
    required int resolvedAtMs,
    // Validity window; YouTube URLs expire ~60min, so we cache for 55min.
    @Default(55 * 60 * 1000) int ttlMs,
  }) = _StreamInfo;

  const StreamInfo._();

  factory StreamInfo.fromJson(Map<String, dynamic> json) =>
      _$StreamInfoFromJson(json);

  bool get isExpired =>
      DateTime.now().millisecondsSinceEpoch - resolvedAtMs >= ttlMs;
}
