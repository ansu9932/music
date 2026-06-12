import '../../core/errors/result.dart';
import '../entities/track.dart';
import '../repositories/metadata_api.dart';

/// Fetches trending charts from the metadata API.
class FetchCharts {
  const FetchCharts(this._api);
  final MetadataApi _api;

  Future<Result<List<Track>>> call({int limit = 20, int offset = 0}) =>
      _api.fetchCharts(limit: limit, offset: offset);
}
