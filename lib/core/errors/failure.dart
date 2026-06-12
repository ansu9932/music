/// Severity hint used by the UI to pick a toast style.
enum FailureKind { info, error, network }

/// Sealed hierarchy of all recoverable failures in the app.
///
/// Data-layer methods return these via [Result] instead of throwing across
/// layers, which keeps the zero-bug / no-unhandled-exception guarantee.
sealed class Failure {
  const Failure(this.message, {this.kind = FailureKind.error, this.cause});

  /// Human-readable, toast-safe message.
  final String message;

  /// Hint for UI presentation.
  final FailureKind kind;

  /// Optional underlying error/exception for logging only (never shown).
  final Object? cause;

  @override
  String toString() => '$runtimeType($message)';
}

/// Network connectivity dropped or a request could not reach the host.
final class NetworkFailure extends Failure {
  const NetworkFailure([
    String message = 'Network unavailable',
    Object? cause,
  ]) : super(message, kind: FailureKind.network, cause: cause);
}

/// A remote API responded with an error or unexpected payload.
final class ApiFailure extends Failure {
  const ApiFailure([
    String message = 'Service unavailable',
    Object? cause,
  ]) : super(message, cause: cause);

  final int? statusCode = null;
}

/// A track could not be resolved to a playable audio stream.
final class StreamNotFoundFailure extends Failure {
  const StreamNotFoundFailure([
    String message = 'No playable stream found',
    Object? cause,
  ]) : super(message, cause: cause);
}

/// Audio decoding / playback engine error.
final class PlaybackFailure extends Failure {
  const PlaybackFailure([
    String message = 'Playback error',
    Object? cause,
  ]) : super(message, cause: cause);
}

/// Local storage (Isar) read/write/migration error.
final class StorageFailure extends Failure {
  const StorageFailure([
    String message = 'Storage error',
    Object? cause,
  ]) : super(message, cause: cause);
}

/// Catch-all for unexpected, otherwise-unclassified errors.
final class UnknownFailure extends Failure {
  const UnknownFailure([
    String message = 'Something went wrong',
    Object? cause,
  ]) : super(message, cause: cause);
}
