import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';

/// Factory + interceptor for the shared [Dio] instance used by metadata APIs.
///
/// Adds bounded exponential-backoff retry for transient network/5xx errors so
/// flaky mobile connections degrade gracefully instead of throwing.
abstract final class DioClient {
  const DioClient._();

  static Dio create({
    Duration connectTimeout = const Duration(seconds: 10),
    Duration receiveTimeout = const Duration(seconds: 15),
    int maxRetries = 3,
  }) {
    final dio = Dio(
      BaseOptions(
        connectTimeout: connectTimeout,
        receiveTimeout: receiveTimeout,
        responseType: ResponseType.json,
        headers: const <String, dynamic>{
          'Accept': 'application/json',
          'User-Agent': 'AuraPlayer/1.0 (+https://github.com/ansu9932/music)',
        },
      ),
    );

    dio.interceptors.add(_RetryInterceptor(dio: dio, maxRetries: maxRetries));
    return dio;
  }
}

class _RetryInterceptor extends Interceptor {
  _RetryInterceptor({required this.dio, required this.maxRetries});

  final Dio dio;
  final int maxRetries;

  static const String _retryCountKey = 'aura_retry_count';

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final attempt = (err.requestOptions.extra[_retryCountKey] as int?) ?? 0;

    if (!_isRetryable(err) || attempt >= maxRetries) {
      handler.next(err);
      return;
    }

    // Backoff: 1s, 2s, 4s (+ jitter).
    final delayMs = (1000 * math.pow(2, attempt)).toInt();
    final jitter = math.Random().nextInt(250);
    await Future<void>.delayed(Duration(milliseconds: delayMs + jitter));

    final options = err.requestOptions;
    options.extra[_retryCountKey] = attempt + 1;

    try {
      final response = await dio.fetch<dynamic>(options);
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  bool _isRetryable(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.badResponse:
        final code = err.response?.statusCode ?? 0;
        return code >= 500 && code < 600;
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return false;
    }
  }
}
