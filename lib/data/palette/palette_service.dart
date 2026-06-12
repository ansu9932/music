import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:palette_generator/palette_generator.dart';

import '../../domain/entities/aura_palette.dart';
import '../../domain/repositories/user_repository.dart';
import '../../domain/usecases/extract_palette.dart';
import '../cache/artwork_cache.dart';

/// Extracts a dominant palette from artwork off the UI thread and caches the
/// result per track (in Isar + an in-memory map).
///
/// Note: `PaletteGenerator` and `dart:ui` image decoding require the platform
/// bindings, so the heavy quantization is performed via the framework's
/// async API (which offloads decode to the engine) rather than a pure
/// `Isolate.run` (which cannot access `dart:ui`). Bytes are fetched off the UI
/// thread through the artwork cache.
class PaletteService implements PaletteExtractor {
  PaletteService(this._cache);

  final UserRepository _cache;
  final Map<String, AuraPalette> _memory = <String, AuraPalette>{};

  @override
  Future<AuraPalette> extract({
    required String trackId,
    required String? artworkUrl,
  }) async {
    // In-memory fast path.
    final mem = _memory[trackId];
    if (mem != null) return mem;

    // Persistent cache.
    final cached = await _cache.getCachedPalette(trackId);
    if (cached != null && cached.length >= 3) {
      final palette = AuraPalette(
        dominantArgb: cached[0],
        vibrantArgb: cached[1],
        mutedArgb: cached[2],
      );
      _memory[trackId] = palette;
      return palette;
    }

    if (artworkUrl == null || artworkUrl.trim().isEmpty) {
      return AuraPalette.fallback;
    }

    try {
      final bytes = await _loadBytes(artworkUrl);
      if (bytes == null) return AuraPalette.fallback;

      final image = await _decodeImage(bytes);
      final generator = await PaletteGenerator.fromImage(
        image,
        maximumColorCount: 16,
      );

      final dominant =
          generator.dominantColor?.color ?? AuraPalette.fallback.dominant;
      final vibrant = generator.vibrantColor?.color ??
          generator.lightVibrantColor?.color ??
          dominant;
      final muted = generator.darkMutedColor?.color ??
          generator.mutedColor?.color ??
          AuraPalette.fallback.muted;

      final palette = AuraPalette.fromColors(
        dominant: dominant,
        vibrant: vibrant,
        muted: muted,
      );

      _memory[trackId] = palette;
      await _cache.cachePalette(
        trackId,
        <int>[palette.dominantArgb, palette.vibrantArgb, palette.mutedArgb],
      );
      image.dispose();
      return palette;
    } catch (_) {
      return AuraPalette.fallback;
    }
  }

  Future<Uint8List?> _loadBytes(String url) async {
    final file = await ArtworkCacheManager.instance.getSingleFile(url);
    if (!file.existsSync()) return null;
    return file.readAsBytes();
  }

  Future<ui.Image> _decodeImage(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: 100, // small decode keeps quantization fast
    );
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  /// Clears the in-memory palette cache (lifecycle pause / low-memory).
  void evictMemory() => _memory.clear();
}
