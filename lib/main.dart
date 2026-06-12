import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'application/providers/audio_providers.dart';
import 'data/audio/aura_audio_handler.dart';
import 'data/isar_bootstrap.dart';
import 'data/resolver/youtube_stream_resolver.dart';

/// App entry point.
///
/// Everything runs inside [runZonedGuarded] so no uncaught async error can
/// reach the user as a crash; errors are logged and (where possible) surfaced
/// as toasts by the UI layer.
Future<void> main() async {
  await runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Route framework errors through the logger instead of a red screen.
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        debugPrint('FlutterError: ${details.exceptionAsString()}');
      };

      // 1. Open the local store (with corruption recovery).
      final isar = await IsarBootstrap.open();

      // 2. Initialize the single background audio engine.
      final resolver = YoutubeStreamResolver();
      final handler = await AudioService.init<AuraAudioHandler>(
        builder: () => AuraAudioHandler(resolver: resolver),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.aura.player.audio',
          androidNotificationChannelName: 'Aura Player',
          androidNotificationOngoing: true,
          androidStopForegroundOnPause: true,
        ),
      );

      runApp(
        ProviderScope(
          overrides: <Override>[
            isarProvider.overrideWithValue(isar),
            audioHandlerProvider.overrideWithValue(handler),
          ],
          child: const AuraApp(),
        ),
      );
    },
    (Object error, StackTrace stack) {
      // Last-resort guard: log and keep running.
      debugPrint('Uncaught zone error: $error\n$stack');
    },
  );
}
