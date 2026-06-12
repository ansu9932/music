import '../../core/errors/result.dart';
import '../entities/track.dart';
import '../repositories/metadata_api.dart';

/// Searches the metadata API for tracks matching [query].
class SearchTracks {
  const SearchTracks(this._api);
  final MetadataApi _api;

  Future<Result<List<Track>>> call(String query, {int limit = 20}) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return Future<Result<List<Track>>>.value(
        const Result<List<Track>>.success(<Track>[]),
      );
    }
    return _api.search(trimmed, limit: limit);
  }
}
