import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/library_controller.dart';
import '../../core/motion/motion_tokens.dart';
import '../../core/theme/aura_colors.dart';
import '../../domain/entities/track.dart';

/// Heart toggle that persists to local storage immediately and animates the
/// state change with a subtle scale pop.
class FavoriteButton extends ConsumerWidget {
  const FavoriteButton({required this.track, super.key});

  final Track track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFav = ref.watch(isFavoriteProvider(track.id));

    return IconButton(
      onPressed: () => ref.read(libraryControllerProvider).toggleFavorite(track),
      iconSize: 24,
      icon: AnimatedSwitcher(
        duration: MotionTokens.microInteract,
        transitionBuilder: (child, animation) =>
            ScaleTransition(scale: animation, child: child),
        child: Icon(
          isFav ? Icons.favorite : Icons.favorite_border,
          key: ValueKey<bool>(isFav),
          color: isFav ? AuraColors.error : AuraColors.textPrimary,
        ),
      ),
    );
  }
}
