import 'dart:convert';

import 'package:dio/dio.dart';

import '../../core/errors/failure.dart';
import '../../core/errors/result.dart';
import '../../domain/entities/track.dart';
import '../../domain/repositories/metadata_api.dart';
import '../../domain/repositories/user_repository.dart';

/// Jamendo v3 REST adapter — the default, CC-licensed, free metadata source.
///
/// Jamendo responses include a directly-playable `audio` URL, so tracks from
/// this source need no client-side extraction (fully license-compliant).
class JamendoMetadataApi implements MetadataApi {
  JamendoMetadataApi({
    required Dio dio,
    required UserRepository cache,
    this.clientId = 'b6747d04',
  })  : _dio = dio,
        _cache = cache;

  final Dio _dio;
  final UserRepository _cache;
  final String clientId;

  static const String _base = 'https://api.jamendo.com/v3.0';

  @override
  Future<Result<List<Track>>> fetchCharts({int limit = 20, int offset = 0}) {
    return _request(
      path: '/tracks/',
      cacheKey: 'jamendo:charts:$limit:$offset',
      query: <String, dynamic>{
        'client_id': clientId,
        'format': 'json',
        'limit': limit,
        'offset': offset,
        'featured': 1,
        'order': 'popularity_total',
        'imagesize': 500,
      },
    );
  }

  @override
  Future<Result<List<Track>>> search(String query, {int limit = 20}) {
    return _request(
      path: '/tracks/',
      cacheKey: 'jamendo:search:${query.toLowerCase()}:$limit',
      query: <String, dynamic>{
        'client_id': clientId,
        'format': 'json',
        'limit': limit,
        'namesearch': query,
        'imagesize': 500,
      },
    );
  }

  Future<Result<List<Track>>> _request({
    required String path,
    required Map<String, dynamic> query,
    required String cacheKey,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_base$path',
        queryParameters: query,
      );

      final data = response.data;
      final results = (data?['results'] as List<dynamic>?) ?? <dynamic>[];
      final tracks = results
          .whereType<Map<String, dynamic>>()
          .map(_mapTrack)
          .toList(growable: false);

      // Cache raw mapped tracks for offline browsing.
      await _cache.cacheResponse(
        cacheKey,
        jsonEncode(tracks.map((t) => t.toJson()).toList()),
      );

      return Result<List<Track>>.success(tracks);
    } on DioException catch (e) {
      // Fall back to cache when offline / API unreachable.
      final cached = await _readCache(cacheKey);
      if (cached != null) return Result<List<Track>>.success(cached);
      final isNetwork = e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout;
      return Result<List<Track>>.failure(
        isNetwork
            ? NetworkFailure('Offline — no cached results', e)
            : ApiFailure('Jamendo request failed', e),
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
    return Track(
      id: 'jamendo_${json['id']}',
      title: (json['name'] as String?)?.trim() ?? 'Unknown Title',
      artist: (json['artist_name'] as String?)?.trim() ?? 'Unknown Artist',
      album: (json['album_name'] as String?)?.trim(),
      durationMs: durationSec * 1000,
      artworkUrl: (json['image'] as String?) ??
          (json['album_image'] as String?),
      // Jamendo provides a directly-playable, CC-licensed audio URL.
      directAudioUrl: json['audio'] as String?,
    );
  }
}
