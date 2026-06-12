import '../../core/errors/result.dart';
import '../entities/stream_info.dart';
import '../entities/track.dart';
import '../repositories/stream_resolver.dart';

/// Resolves a track to a playable stream (off the UI thread inside the
/// resolver implementation).
class ResolveStream {
  const ResolveStream(this._resolver);
  final StreamResolver _resolver;

  Future<Result<StreamInfo>> call(Track track) => _resolver.resolve(track);
}
