import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/aura_colors.dart';
import '../../data/cache/artwork_cache.dart';
import '../../domain/entities/track.dart';

/// A single row in the Discover/Search list. The thumbnail is wrapped in a
/// [Hero] keyed by [Track.heroTag] so it morphs into the Now Playing artwork.
class TrackTile extends StatelessWidget {
  const TrackTile({
    required this.track,
    required this.onTap,
    this.isActive = false,
    super.key,
  });

  final Track track;
  final VoidCallback onTap;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: <Widget>[
            Hero(
              tag: track.heroTag,
              child: AuraThumbnail(url: track.artworkUrl, size: 56),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    track.displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: isActive
                          ? AuraColors.textPrimary
                          : AuraColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    track.displayArtist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: AuraColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isActive)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.graphic_eq, size: 18, color: AuraColors.textSecondary),
              ),
          ],
        ),
      ),
    );
  }
}

/// Cached, rounded artwork with a neutral monochromatic placeholder/fallback.
/// Shared between the list and the Now Playing canvas so the Hero reuses the
/// same cached image provider (no re-download, no flash).
class AuraThumbnail extends StatelessWidget {
  const AuraThumbnail({
    required this.url,
    required this.size,
    this.radius = 8,
    super.key,
  });

  final String? url;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AuraColors.graphite,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(
        Icons.music_note,
        size: size * 0.4,
        color: AuraColors.textSecondary,
      ),
    );

    if (url == null || url!.trim().isEmpty) return placeholder;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: CachedNetworkImage(
        imageUrl: url!,
        cacheManager: ArtworkCacheManager.instance,
        width: size,
        height: size,
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 200),
        placeholder: (_, __) => placeholder,
        errorWidget: (_, __, ___) => placeholder,
      ),
    );
  }
}
