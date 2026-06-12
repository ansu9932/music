import '../../core/errors/result.dart';
import '../entities/stream_info.dart';
import '../entities/track.dart';

/// Resolves a [Track] to a directly-playable [StreamInfo] entirely on-device.
///
/// Implementations MUST be used in accordance with each source's terms of
/// service and content licensing. The default implementation prefers a
/// track's direct (CC-licensed) audio URL and only falls back to client-side
/// extraction when no direct URL exists.
abstract interface class StreamResolver {
  Future<Result<StreamInfo>> resolve(Track track);

  /// Releases any underlying clients (e.g. the YoutubeExplode HTTP client).
  Future<void> dispose();
}
