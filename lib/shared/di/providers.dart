import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_zero_copy/shared/config/app_config.dart';
import 'package:flutter_zero_copy/shared/event_bus/event_bus.dart';
import 'package:flutter_zero_copy/shared/logger/logger.dart';
import 'package:flutter_zero_copy/shared/storage/storage.dart';

// ── Configuration ──

/// Active app configuration (dev by default; override for staging/prod).
final appConfigProvider = Provider<AppConfig>((ref) => AppConfig.dev);

// ── Logger ──

/// Application-wide logger.
///
/// Log level is automatically set to [LogLevel.debug] when the active
/// configuration has `enableDebugLogging == true`.
final loggerProvider = Provider<IAppLogger>((ref) {
  final config = ref.watch(appConfigProvider);
  return AppLogger(
    minimumLevel: config.enableDebugLogging ? LogLevel.debug : LogLevel.info,
  );
});

// ── Storage ──

/// Primary KV storage (Hive-powered, suitable for structured data).
///
/// Initialised lazily — call `ref.read(storageProvider).init()` before use.
final storageProvider = Provider<IStorage>((ref) => HiveStorage());

// ── Event Bus ──

/// Application-wide event bus for decoupled feature communication.
final eventBusProvider = Provider<EventBus>((ref) => EventBus());

// ── HTTP Client ──

// final httpClientProvider = Provider<Dio>((ref) {
//   final config = ref.watch(appConfigProvider);
//   final logger = ref.watch(loggerProvider);
//   return createHttpClient(baseUrl: config.apiBaseUrl, logger: logger);
// });
