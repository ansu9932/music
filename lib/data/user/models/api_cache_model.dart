import 'package:isar/isar.dart';

part 'api_cache_model.g.dart';

/// Raw API response cache (charts, searches) with TTL for offline browsing.
@collection
class ApiCacheModel {
  ApiCacheModel();

  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String cacheKey;

  late String responseJson;

  late int cachedAt;
  int ttlMs = 30 * 60 * 1000; // 30 minutes default

  bool get isExpired =>
      DateTime.now().millisecondsSinceEpoch - cachedAt >= ttlMs;
}
