import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/toast_controller.dart';
import '../../core/errors/failure.dart';
import '../../core/motion/motion_tokens.dart';
import '../../core/theme/aura_colors.dart';

/// A single-instance, auto-dismissing toast pinned near the bottom of the
/// screen. Wraps the app so it floats above all routes. Never stacks.
class AuraToastScope extends ConsumerWidget {
  const AuraToastScope({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final message = ref.watch(toastControllerProvider);

    return Stack(
      children: <Widget>[
        child,
        Positioned(
          left: 0,
          right: 0,
          bottom: 80,
          child: IgnorePointer(
            ignoring: message == null,
            child: AnimatedSwitcher(
              duration: MotionTokens.toastFadeIn,
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.3),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: message == null
                  ? const SizedBox.shrink(key: ValueKey<String>('toast-empty'))
                  : _ToastBubble(
                      key: ValueKey<int>(message.id),
                      message: message,
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ToastBubble extends StatelessWidget {
  const _ToastBubble({required this.message, super.key});

  final ToastMessage message;

  @override
  Widget build(BuildContext context) {
    final accent = switch (message.kind) {
      FailureKind.network => AuraColors.error,
      FailureKind.error => AuraColors.error,
      FailureKind.info => AuraColors.textSecondary,
    };

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: AuraColors.graphite.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AuraColors.outline),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            ),
            Flexible(
              child: Text(
                message.text,
                style: const TextStyle(
                  color: AuraColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
