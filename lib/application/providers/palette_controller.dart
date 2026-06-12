import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/aura_palette.dart';
import 'metadata_providers.dart';

/// Key for [paletteProvider]: track id + artwork URL (records are equatable,
/// so identical keys de-duplicate the future automatically).
typedef PaletteKey = ({String trackId, String? artworkUrl});

/// Off-thread, cached palette extraction for the active track's artwork.
/// Always resolves (falls back to the default graphite palette on failure).
final paletteProvider =
    FutureProvider.family<AuraPalette, PaletteKey>((ref, key) async {
  final service = ref.watch(paletteServiceProvider);
  return service.extract(trackId: key.trackId, artworkUrl: key.artworkUrl);
});
