import 'package:dio/dio.dart';
import 'package:flutter_zero_copy/shared/logger/logger.dart';

/// Creates and configures a [Dio] HTTP client for the Lava App.
///
/// Includes:
/// - Base URL and timeouts (connect: 10s, receive: 30s)
/// - Request/response logging via [LoggingInterceptor]
/// - Error normalization via [ErrorInterceptor]
Dio createHttpClient({
  required String baseUrl,
  required IAppLogger logger,
  Duration connectTimeout = const Duration(seconds: 10),
  Duration receiveTimeout = const Duration(seconds: 30),
}) {
  final dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: connectTimeout,
    receiveTimeout: receiveTimeout,
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  ));

  dio.interceptors.addAll([
    LoggingInterceptor(logger),
    ErrorInterceptor(logger),
  ]);

  return dio;
}

/// Logs every request and response for debugging.
class LoggingInterceptor extends Interceptor {
  final IAppLogger _logger;

  LoggingInterceptor(this._logger);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _logger.debug('→ ${options.method} ${options.uri}');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _logger.debug('← ${response.statusCode} ${response.requestOptions.uri}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _logger.warn('✗ ${err.requestOptions.method} ${err.requestOptions.uri}: ${err.message}');
    handler.next(err);
  }
}

/// Normalises [DioException] into actionable app-level information.
class ErrorInterceptor extends Interceptor {
  final IAppLogger _logger;

  ErrorInterceptor(this._logger);

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final statusCode = err.response?.statusCode;
    final msg = switch (err.type) {
      DioExceptionType.connectionTimeout => 'Connection timed out',
      DioExceptionType.receiveTimeout => 'Server did not respond in time',
      DioExceptionType.connectionError => 'No network connection',
      _ when statusCode == 401 => 'Unauthorized',
      _ when statusCode == 403 => 'Forbidden',
      _ when statusCode == 404 => 'Not found',
      _ when statusCode != null && statusCode >= 500 => 'Server error ($statusCode)',
      _ => err.message ?? 'Unknown error',
    };
    _logger.error('HTTP Error: $msg', err);
    handler.next(err);
  }
}
