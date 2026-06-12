import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';

import '../../data/audio/audio_repository_impl.dart';
import '../../data/audio/aura_audio_handler.dart';
import '../../data/resolver/youtube_stream_resolver.dart';
import '../../data/session/session_store.dart';
import '../../data/user/isar_user_repository.dart';
import '../../domain/entities/playback_state.dart';
import '../../domain/repositories/audio_repository.dart';
import '../../domain/repositories/session_repository.dart';
import '../../domain/repositories/stream_resolver.dart';
import '../../domain/repositories/user_repository.dart';

/// Overridden in `main()` after the Isar instance is opened.
final isarProvider = Provider<Isar>((ref) {
  throw UnimplementedError('isarProvider must be overridden in main()');
});

/// Overridden in `main()` after `AudioService.init` creates the handler.
final audioHandlerProvider = Provider<AuraAudioHandler>((ref) {
  throw UnimplementedError('audioHandlerProvider must be overridden in main()');
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return IsarUserRepository(ref.watch(isarProvider));
});

final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  return SessionStore(ref.watch(isarProvider));
});

final streamResolverProvider = Provider<StreamResolver>((ref) {
  final resolver = YoutubeStreamResolver();
  ref.onDispose(resolver.dispose);
  return resolver;
});

final audioRepositoryProvider = Provider<AudioRepository>((ref) {
  return AudioRepositoryImpl(ref.watch(audioHandlerProvider));
});

/// Broadcast of the UI-facing playback state.
final playbackStateProvider = StreamProvider<PlaybackState>((ref) {
  return ref.watch(audioRepositoryProvider).playbackState;
});

/// High-frequency position stream (drives smooth progress interpolation).
final positionProvider = StreamProvider<Duration>((ref) {
  return ref.watch(audioRepositoryProvider).positionStream;
});
