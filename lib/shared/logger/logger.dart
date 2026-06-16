import 'package:logger/logger.dart' as log_lib;

/// Log levels supported by [AppLogger].
enum LogLevel { debug, info, warn, error }

/// Unified logging interface for the Lava App.
///
/// Wraps the `logger` package with additional formatting
/// (timestamps, caller info) and a simple programmatic API.
abstract class IAppLogger {
  void debug(String message, [Object? error, StackTrace? stackTrace]);
  void info(String message, [Object? error, StackTrace? stackTrace]);
  void warn(String message, [Object? error, StackTrace? stackTrace]);
  void error(String message, [Object? error, StackTrace? stackTrace]);
  void log(LogLevel level, String message, [Object? error, StackTrace? stackTrace]);
}

/// Production logger implementation backed by the `logger` package.
class AppLogger implements IAppLogger {
  final log_lib.Logger _logger;

  AppLogger({
    LogLevel minimumLevel = LogLevel.debug,
    bool enableStackTraces = true,
  }) : _logger = log_lib.Logger(
          filter: _LogFilter(minimumLevel),
          printer: _LogPrinter(enableStackTraces: enableStackTraces),
        );

  @override
  void debug(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.d(message, error: error, stackTrace: stackTrace);
  }

  @override
  void info(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.i(message, error: error, stackTrace: stackTrace);
  }

  @override
  void warn(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.w(message, error: error, stackTrace: stackTrace);
  }

  @override
  void error(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }

  @override
  void log(LogLevel level, String message, [Object? err, StackTrace? st]) {
    switch (level) {
      case LogLevel.debug:
        debug(message, err, st);
      case LogLevel.info:
        info(message, err, st);
      case LogLevel.warn:
        warn(message, err, st);
      case LogLevel.error:
        this.error(message, err, st);
    }
  }
}

// ── Internal helpers ──

class _LogFilter extends log_lib.LogFilter {
  final LogLevel minimumLevel;

  _LogFilter(this.minimumLevel);

  @override
  bool shouldLog(log_lib.LogEvent event) {
    // Map package levels to our levels
    final map = <log_lib.Level, LogLevel>{
      log_lib.Level.debug: LogLevel.debug,
      log_lib.Level.info: LogLevel.info,
      log_lib.Level.warning: LogLevel.warn,
      log_lib.Level.error: LogLevel.error,
    };
    final eventLevel = map[event.level] ?? LogLevel.debug;
    return eventLevel.index >= minimumLevel.index;
  }
}

class _LogPrinter extends log_lib.LogPrinter {
  final bool enableStackTraces;

  _LogPrinter({this.enableStackTraces = true});

  @override
  List<String> log(log_lib.LogEvent event) {
    final timestamp = _formatTimestamp(DateTime.now());
    final level = event.level.name.toUpperCase().padRight(5);
    final header = '$timestamp [$level]';

    final buffer = StringBuffer('$header ${event.message}');

    if (event.error != null) {
      buffer.write('\n$header   └─ error: ${event.error}');
    }

    if (enableStackTraces && event.stackTrace != null) {
      final lines = event.stackTrace.toString().split('\n');
      for (final line in lines.take(8)) {
        buffer.write('\n$header     $line');
      }
    }

    return [buffer.toString()];
  }

  String _formatTimestamp(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    final ms = dt.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }
}
