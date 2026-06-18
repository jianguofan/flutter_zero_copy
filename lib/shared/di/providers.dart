import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_zero_copy/shared/config/app_config.dart';
import 'package:flutter_zero_copy/shared/event_bus/event_bus.dart';
import 'package:flutter_zero_copy/shared/http/http_client.dart';
import 'package:flutter_zero_copy/shared/logger/logger.dart';
import 'package:flutter_zero_copy/shared/storage/storage.dart';
import 'package:flutter_zero_copy/services/wan_api_service.dart';

// ── Configuration ──

/// Active app configuration (prod CN by default).
final appConfigProvider = Provider<AppConfig>((ref) => AppConfig.prodCN);

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

/// Shared Dio HTTP client configured with the current app config.
final httpClientProvider = Provider<Dio>((ref) {
  final config = ref.watch(appConfigProvider);
  final logger = ref.watch(loggerProvider);
  return createHttpClient(baseUrl: config.apiBaseUrl, logger: logger);
});

// ── WAN API Service ──

/// Cloud API service used by [DeviceHub.connectWan] for device binding,
/// certificate retrieval, and authorization verification.
final wanApiServiceProvider = Provider<WanApiService>((ref) {
  final dio = ref.watch(httpClientProvider);
  return WanApiService(dio: dio);
});
