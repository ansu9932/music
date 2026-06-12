import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/failure.dart';
import '../../core/motion/motion_tokens.dart';

/// A single toast message. [kind] picks the visual style.
class ToastMessage {
  ToastMessage(this.text, {this.kind = FailureKind.info})
      : id = DateTime.now().microsecondsSinceEpoch;

  final int id;
  final String text;
  final FailureKind kind;
}

/// Holds the single active toast. New toasts replace the current one (never
/// stack). Auto-dismisses after the hold duration.
class ToastController extends Notifier<ToastMessage?> {
  Timer? _timer;

  @override
  ToastMessage? build() {
    ref.onDispose(() => _timer?.cancel());
    return null;
  }

  void show(String text, {FailureKind kind = FailureKind.info}) {
    _timer?.cancel();
    final message = ToastMessage(text, kind: kind);
    state = message;

    final total = MotionTokens.toastFadeIn +
        MotionTokens.toastHold +
        MotionTokens.toastFadeOut;
    _timer = Timer(total, () {
      // Only clear if this exact toast is still showing.
      if (state?.id == message.id) state = null;
    });
  }

  /// Convenience for surfacing a [Failure] to the user.
  void showFailure(Failure failure) =>
      show(failure.message, kind: failure.kind);

  void dismiss() {
    _timer?.cancel();
    state = null;
  }
}

final toastControllerProvider =
    NotifierProvider<ToastController, ToastMessage?>(ToastController.new);
