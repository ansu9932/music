import 'failure.dart';

/// A lightweight, allocation-cheap sum type: either a [Success] or a
/// [FailureResult]. Data-layer methods return `Result<T>` so errors are
/// values, never thrown across layers.
sealed class Result<T> {
  const Result();

  const factory Result.success(T value) = Success<T>;
  const factory Result.failure(Failure failure) = FailureResult<T>;

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is FailureResult<T>;

  /// The value if successful, otherwise null.
  T? get valueOrNull => switch (this) {
        Success<T>(:final value) => value,
        FailureResult<T>() => null,
      };

  /// The failure if failed, otherwise null.
  Failure? get failureOrNull => switch (this) {
        Success<T>() => null,
        FailureResult<T>(:final failure) => failure,
      };

  /// Exhaustive fold to a single value of type [R].
  R when<R>({
    required R Function(T value) success,
    required R Function(Failure failure) failure,
  }) {
    return switch (this) {
      Success<T>(:final value) => success(value),
      FailureResult<T>(:final failure) => failure(this.failureOrNull!),
    };
  }

  /// Maps a successful value while preserving failures.
  Result<R> map<R>(R Function(T value) transform) {
    return switch (this) {
      Success<T>(:final value) => Result<R>.success(transform(value)),
      FailureResult<T>(:final failure) => Result<R>.failure(failure),
    };
  }

  /// Returns the value or a [fallback] when failed.
  T getOrElse(T fallback) => valueOrNull ?? fallback;
}

final class Success<T> extends Result<T> {
  const Success(this.value);
  final T value;
}

final class FailureResult<T> extends Result<T> {
  const FailureResult(this.failure);
  final Failure failure;
}

/// Runs [action], converting any thrown error into a [Result.failure] using
/// [onError] (defaults to wrapping in [UnknownFailure]). Guarantees no
/// exception escapes.
Future<Result<T>> guardAsync<T>(
  Future<T> Function() action, {
  Failure Function(Object error, StackTrace stack)? onError,
}) async {
  try {
    return Result<T>.success(await action());
  } catch (error, stack) {
    final failure = onError?.call(error, stack) ?? UnknownFailure('$error', error);
    return Result<T>.failure(failure);
  }
}

/// Synchronous variant of [guardAsync].
Result<T> guard<T>(
  T Function() action, {
  Failure Function(Object error, StackTrace stack)? onError,
}) {
  try {
    return Result<T>.success(action());
  } catch (error, stack) {
    final failure = onError?.call(error, stack) ?? UnknownFailure('$error', error);
    return Result<T>.failure(failure);
  }
}
