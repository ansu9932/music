import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/dio_client.dart';
import '../../data/metadata/jamendo_metadata_api.dart';
import '../../data/palette/palette_service.dart';
import '../../domain/repositories/metadata_api.dart';
import '../../domain/usecases/fetch_charts.dart';
import '../../domain/usecases/search_tracks.dart';
import 'audio_providers.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = DioClient.create();
  ref.onDispose(dio.close);
  return dio;
});

/// Default metadata source: Jamendo (CC-licensed, free, direct audio URLs).
///
/// To switch to JioSaavn, override this provider in `ProviderScope` with a
/// `SaavnMetadataApi`.
final metadataApiProvider = Provider<MetadataApi>((ref) {
  return JamendoMetadataApi(
    dio: ref.watch(dioProvider),
    cache: ref.watch(userRepositoryProvider),
  );
});

final fetchChartsProvider = Provider<FetchCharts>((ref) {
  return FetchCharts(ref.watch(metadataApiProvider));
});

final searchTracksProvider = Provider<SearchTracks>((ref) {
  return SearchTracks(ref.watch(metadataApiProvider));
});

final paletteServiceProvider = Provider<PaletteService>((ref) {
  final service = PaletteService(ref.watch(userRepositoryProvider));
  ref.onDispose(service.evictMemory);
  return service;
});
