import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zero_copy/shared/errors/app_error.dart';
import 'package:flutter_zero_copy/shared/utils/retry_policy.dart';
import 'package:flutter_zero_copy/shared/logger/logger.dart';

void main() {
  group('AppError', () {
    test('fromException classifies SocketException', () {
      final err = AppError.fromException(
        Exception('SocketException: No address associated with hostname'),
      );
      expect(err.code, equals(ErrorCode.networkUnavailable));
      expect(err.severity, equals(ErrorSeverity.recoverable));
    });

    test('fromException classifies TimeoutException', () {
      final err = AppError.fromException(
        Exception('TimeoutException: Connection timed out'),
      );
      expect(err.code, equals(ErrorCode.networkTimeout));
    });

    test('fromException classifies not found errors', () {
      final err = AppError.fromException(Exception('device not found'));
      expect(err.code, equals(ErrorCode.deviceNotFound));
    });

    test('fromException falls back to unknown', () {
      final err = AppError.fromException(Exception('something weird'));
      expect(err.code, equals(ErrorCode.unknown));
    });

    test('isUserVisible is false for warnings', () {
      final err = AppError(
        code: ErrorCode.unknown,
        message: 'test',
        severity: ErrorSeverity.warning,
      );
      expect(err.isUserVisible, isFalse);
    });

    test('isUserVisible is true for fatal errors', () {
      final err = AppError(
        code: ErrorCode.unknown,
        message: 'test',
        severity: ErrorSeverity.fatal,
      );
      expect(err.isUserVisible, isTrue);
    });

    test('codeName returns enum name', () {
      final err = AppError(code: ErrorCode.deviceTimeout, message: 'timeout');
      expect(err.codeName, equals('deviceTimeout'));
    });

    test('timestamp defaults to now', () {
      final before = DateTime.now();
      final err = AppError(code: ErrorCode.unknown, message: 'test');
      expect(err.timestamp.isAfter(before.subtract(const Duration(seconds: 1))),
          isTrue);
    });
  });

  group('RetryPolicy', () {
    test('succeeds on first attempt', () async {
      final policy = RetryPolicy(maxRetries: 3);
      final result = await policy.execute(() async => 42);
      expect(result, equals(42));
    });

    test('retries and succeeds on second attempt', () async {
      var attempts = 0;
      final policy = RetryPolicy(
        initialDelay: const Duration(milliseconds: 1),
        maxRetries: 3,
        logger: AppLogger(),
      );

      final result = await policy.execute(() async {
        attempts++;
        if (attempts < 2) throw Exception('fail');
        return 'success';
      });

      expect(result, equals('success'));
      expect(attempts, equals(2));
    });

    test('throws after exhausting retries', () async {
      final policy = RetryPolicy(
        initialDelay: const Duration(milliseconds: 1),
        maxRetries: 2,
      );

      expect(
        () => policy.execute(() async => throw Exception('always fail')),
        throwsException,
      );
    });

    test('tryExecute returns null on failure', () async {
      final policy = RetryPolicy(
        initialDelay: const Duration(milliseconds: 1),
        maxRetries: 1,
      );

      final result = await policy.tryExecute(
          () async => throw Exception('fail'));
      expect(result, isNull);
    });

    test('tryExecute returns value on success', () async {
      final policy = RetryPolicy(maxRetries: 1);
      final result = await policy.tryExecute(() async => 'ok');
      expect(result, equals('ok'));
    });
  });
}
