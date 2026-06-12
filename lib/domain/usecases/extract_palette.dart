import '../entities/aura_palette.dart';

/// Contract for palette extraction; the concrete service runs
/// `palette_generator` inside `Isolate.run` and caches per track.
abstract interface class PaletteExtractor {
  Future<AuraPalette> extract({
    required String trackId,
    required String? artworkUrl,
  });
}

/// Use-case wrapper around a [PaletteExtractor].
class ExtractPalette {
  const ExtractPalette(this._extractor);
  final PaletteExtractor _extractor;

  Future<AuraPalette> call({
    required String trackId,
    required String? artworkUrl,
  }) =>
      _extractor.extract(trackId: trackId, artworkUrl: artworkUrl);
}
