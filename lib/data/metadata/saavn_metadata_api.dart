import 'dart:convert';

import 'package:dio/dio.dart';

import '../../core/errors/failure.dart';
import '../../core/errors/result.dart';
import '../../domain/entities/track.dart';
import '../../domain/repositories/metadata_api.dart';
import '../../domain/repositories/user_repository.dart';

/// JioSaavn public-wrapper adapter (alternative metadata source).
///
/// Saavn does not expose a CC-licensed direct stream, so tracks from this
/// source leave [Track.directAudioUrl] null and rely on the [StreamResolver]
/// fallback. Swap this in via the `metadataApiProvider` override.
///
/// Defaults to a commonly-used community wrapper; configure [baseUrl] to point
/// at your own deployment.
class SaavnMetadataApi implements MetadataApi {
  SaavnMetadataApi({
    required Dio dio,
    required UserRepository cache,
    this.baseUrl = 'https://saavn.dev/api',
  })  : _dio = dio,
        _cache = cache;

  final Dio _dio;
  final UserRepository _cache;
  final String baseUrl;

  @override
  Future<Result<List<Track>>> fetchCharts({int limit = 20, int offset = 0}) {
    // The wrapper has no global "charts" endpoint; use a broad popular query.
    return _searchRequest(
      query: 'top hits',
      limit: limit,
      cacheKey: 'saavn:charts:$limit',
    );
  }

  @override
  Future<Result<List<Track>>> search(String query, {int limit = 20}) {
    return _searchRequest(
      query: query,
      limit: limit,
      cacheKey: 'saavn:search:${query.toLowerCase()}:$limit',
    );
  }

  Future<Result<List<Track>>> _searchRequest({
    required String query,
    required int limit,
    required String cacheKey,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$baseUrl/search/songs',
        queryParameters: <String, dynamic>{'query': query, 'limit': limit},
      );

      final data = response.data?['data'] as Map<String, dynamic>?;
      final results = (data?['results'] as List<dynamic>?) ?? <dynamic>[];
      final tracks = results
          .whereType<Map<String, dynamic>>()
          .map(_mapTrack)
          .toList(growable: false);

      await _cache.cacheResponse(
        cacheKey,
        jsonEncode(tracks.map((t) => t.toJson()).toList()),
      );
      return Result<List<Track>>.success(tracks);
    } on DioException catch (e) {
      final cached = await _readCache(cacheKey);
      if (cached != null) return Result<List<Track>>.success(cached);
      final isNetwork = e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout;
      return Result<List<Track>>.failure(
        isNetwork
            ? NetworkFailure('Offline — no cached results', e)
            : ApiFailure('Saavn request failed', e),
      );
    } catch (e) {
      final cached = await _readCache(cacheKey);
      if (cached != null) return Result<List<Track>>.success(cached);
      return Result<List<Track>>.failure(ApiFailure('Unexpected API error', e));
    }
  }

  Future<List<Track>?> _readCache(String cacheKey) async {
    final json = await _cache.getCachedResponse(cacheKey);
    if (json == null) return null;
    try {
      final decoded = jsonDecode(json) as List<dynamic>;
      return decoded
          .map((e) => Track.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  Track _mapTrack(Map<String, dynamic> json) {
    final durationSec = (json['duration'] as num?)?.toInt() ?? 0;

    String? artist;
    final artistsMap = json['artists'] as Map<String, dynamic>?;
    final primary = artistsMap?['primary'] as List<dynamic>?;
    if (primary != null && primary.isNotEmpty) {
      artist = (primary.first as Map<String, dynamic>)['name'] as String?;
    }

    String? artwork;
    final images = json['image'] as List<dynamic>?;
    if (images != null && images.isNotEmpty) {
      artwork = (images.last as Map<String, dynamic>)['url'] as String?;
    }

    return Track(
      id: 'saavn_${json['id']}',
      title: (json['name'] as String?)?.trim() ?? 'Unknown Title',
      artist: artist?.trim() ?? 'Unknown Artist',
      album: (json['album'] as Map<String, dynamic>?)?['name'] as String?,
      durationMs: durationSec * 1000,
      artworkUrl: artwork,
      // No CC-licensed direct URL; resolver fallback handles playback.
      directAudioUrl: null,
    );
  }
}
