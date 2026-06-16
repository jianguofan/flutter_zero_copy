/// Error severity determines UX treatment.
enum ErrorSeverity {
  warning,
  recoverable,
  fatal,
}

/// Categorised error codes for consistent error handling.
enum ErrorCode {
  // Network
  networkUnavailable,
  networkTimeout,
  networkServerError,

  // Auth
  authUnauthorized,
  authTokenExpired,
  authForbidden,

  // Device
  deviceNotFound,
  deviceNotConnected,
  deviceCommandFailed,
  deviceTimeout,

  // Storage
  storageReadError,
  storageWriteError,

  // Unknown
  unknown,
}

/// Structured application error with classification and severity.
class AppError {
  final ErrorCode code;
  final String message;
  final ErrorSeverity severity;
  final Object? originalError;
  final StackTrace? stackTrace;
  final DateTime timestamp;

  AppError({
    required this.code,
    required this.message,
    this.severity = ErrorSeverity.recoverable,
    this.originalError,
    this.stackTrace,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create from an arbitrary exception, attempting to classify it.
  factory AppError.fromException(Object e, [StackTrace? st]) {
    final msg = e.toString();

    if (msg.contains('SocketException') || msg.contains('No address')) {
      return AppError(
        code: ErrorCode.networkUnavailable,
        message: 'No network connection',
        severity: ErrorSeverity.recoverable,
        originalError: e,
        stackTrace: st,
      );
    }

    if (msg.contains('TimeoutException') || msg.contains('timed out')) {
      return AppError(
        code: ErrorCode.networkTimeout,
        message: 'Connection timed out',
        severity: ErrorSeverity.recoverable,
        originalError: e,
        stackTrace: st,
      );
    }

    if (msg.contains('not found')) {
      return AppError(
        code: ErrorCode.deviceNotFound,
        message: 'Device not found',
        severity: ErrorSeverity.recoverable,
        originalError: e,
        stackTrace: st,
      );
    }

    return AppError(
      code: ErrorCode.unknown,
      message: msg.length > 200 ? '${msg.substring(0, 200)}...' : msg,
      severity: ErrorSeverity.recoverable,
      originalError: e,
      stackTrace: st,
    );
  }

  /// Whether this error should trigger a user-visible notification.
  bool get isUserVisible => severity != ErrorSeverity.warning;

  /// Human-readable code for logging.
  String get codeName => code.name;

  @override
  String toString() =>
      'AppError(code: $code, message: $message, severity: $severity)';
}
