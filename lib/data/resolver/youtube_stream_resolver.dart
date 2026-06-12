import 'dart:async';

import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../core/errors/failure.dart';
import '../../core/errors/result.dart';
import '../../domain/entities/stream_info.dart';
import '../../domain/entities/track.dart';
import '../../domain/repositories/stream_resolver.dart';

/// Resolves a [Track] to a playable stream.
///
/// Resolution order (compliance-first):
///   1. If the track exposes a direct, CC-licensed audio URL (e.g. Jamendo),
///      use it as-is — no extraction performed.
///   2. Otherwise fall back to on-device YouTube audio extraction for
///      personal/local use, picking the best audio-only stream.
///
/// Resolved URLs are cached in-memory until they expire (~55 min for YouTube).
class YoutubeStreamResolver implements StreamResolver {
  YoutubeStreamResolver({YoutubeExplode? client})
      : _yt = client ?? YoutubeExplode();

  final YoutubeExplode _yt;
  final Map<String, StreamInfo> _cache = <String, StreamInfo>{};

  @override
  Future<Result<StreamInfo>> resolve(Track track) async {
    // 1. Direct CC-licensed audio — preferred, no extraction.
    if (track.hasDirectAudio) {
      final info = StreamInfo(
        url: track.directAudioUrl!,
        container: _guessContainer(track.directAudioUrl!),
        bitrateBps: 0,
        source: StreamSource.jamendoDirect,
        resolvedAtMs: DateTime.now().millisecondsSinceEpoch,
        ttlMs: 24 * 60 * 60 * 1000, // direct URLs are stable
      );
      return Result<StreamInfo>.success(info);
    }

    // 2. Cached YouTube resolution still valid?
    final cached = _cache[track.id];
    if (cached != null && !cached.isExpired) {
      return Result<StreamInfo>.success(cached);
    }

    // 3. Off-thread YouTube extraction.
    return guardAsync<StreamInfo>(
      () async {
        final query = '${track.displayTitle} ${track.displayArtist}'.trim();
        final results = await _yt.search.search(query);
        if (results.isEmpty) {
          throw const _NoStreamException();
        }

        final video = results.first;
        final manifest =
            await _yt.videos.streamsClient.getManifest(video.id);

        final audioOnly = manifest.audioOnly;
        if (audioOnly.isEmpty) {
          throw const _NoStreamException();
        }

        final best = audioOnly.withHighestBitrate();
        final info = StreamInfo(
          url: best.url.toString(),
          container: best.container.name, // 'mp4'(m4a) | 'webm'
          bitrateBps: best.bitrate.bitsPerSecond,
          source: StreamSource.youtube,
          resolvedAtMs: DateTime.now().millisecondsSinceEpoch,
          ttlMs: 55 * 60 * 1000,
        );
        _cache[track.id] = info;
        return info;
      },
      onError: (e, _) {
        if (e is _NoStreamException) {
          return const StreamNotFoundFailure();
        }
        return StreamNotFoundFailure('Could not resolve stream', e);
      },
    );
  }

  String _guessContainer(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('.m4a') || lower.contains('.mp4')) return 'm4a';
    if (lower.contains('.webm')) return 'webm';
    if (lower.contains('.ogg')) return 'ogg';
    return 'mp3';
  }

  @override
  Future<void> dispose() async {
    _cache.clear();
    _yt.close();
  }
}

class _NoStreamException implements Exception {
  const _NoStreamException();
}
