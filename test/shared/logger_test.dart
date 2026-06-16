import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zero_copy/shared/logger/logger.dart';

void main() {
  group('AppLogger', () {
    test('creates with default settings', () {
      final logger = AppLogger();
      expect(logger, isNotNull);
    });

    test('creates with custom minimum level', () {
      final logger = AppLogger(minimumLevel: LogLevel.warn);
      expect(logger, isNotNull);
    });

    test('debug logs without error', () {
      final logger = AppLogger();
      expect(() => logger.debug('test message'), returnsNormally);
    });

    test('info logs without error', () {
      final logger = AppLogger();
      expect(() => logger.info('test message'), returnsNormally);
    });

    test('warn logs without error', () {
      final logger = AppLogger();
      expect(() => logger.warn('test message'), returnsNormally);
    });

    test('error logs with exception', () {
      final logger = AppLogger();
      expect(
        () => logger.error('something failed', Exception('boom')),
        returnsNormally,
      );
    });

    test('log with LogLevel dispatches correctly', () {
      final logger = AppLogger();
      for (final level in LogLevel.values) {
        expect(() => logger.log(level, 'test'), returnsNormally);
      }
    });

    test('warn filter suppresses debug', () {
      // Logger with warn minimum — debug and info are filtered, but no crash.
      final logger = AppLogger(minimumLevel: LogLevel.warn);
      expect(() => logger.debug('should be filtered'), returnsNormally);
      expect(() => logger.info('should be filtered'), returnsNormally);
      expect(() => logger.warn('should appear'), returnsNormally);
      expect(() => logger.error('should appear'), returnsNormally);
    });
  });

  group('IAppLogger interface', () {
    test('AppLogger implements IAppLogger', () {
      final IAppLogger logger = AppLogger();
      expect(logger, isA<IAppLogger>());
    });
  });
}
