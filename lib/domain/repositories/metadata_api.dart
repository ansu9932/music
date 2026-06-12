import '../../core/errors/result.dart';
import '../entities/track.dart';

/// Abstraction over a public, $0-cost music metadata/discovery provider
/// (Jamendo by default, JioSaavn wrapper as an alternative). Implemented as a
/// swappable adapter so providers can be changed without touching app code.
abstract interface class MetadataApi {
  /// Trending / featured charts.
  Future<Result<List<Track>>> fetchCharts({int limit = 20, int offset = 0});

  /// Free-text search by name.
  Future<Result<List<Track>>> search(String query, {int limit = 20});
}
