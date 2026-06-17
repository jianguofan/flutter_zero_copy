import 'dart:async';
import 'package:lava_device_sdk/src/adapter/moonraker/moonraker_adapter.dart';
import 'package:lava_device_sdk/src/client/device_client.dart';
import 'package:lava_device_sdk/src/connection/connection_strategy.dart';
import 'package:lava_device_sdk/src/connection/lan_strategy.dart';
import 'package:lava_device_sdk/src/connection/wan_strategy.dart';
import 'package:lava_device_sdk/src/core/schema.dart';
import 'package:lava_device_sdk/src/models/connection_result.dart';
import 'package:lava_device_sdk/src/models/mqtt_credentials.dart';
import 'package:lava_device_sdk/src/models/types.dart';
import 'package:lava_device_sdk/src/mqtt/mqtt_transport.dart';

/// Unified device connection entry point.
///
/// WAN — one call with a token:
/// ```dart
/// final client = await DeviceHub.connectWan(
///   api: myApiService,
///   token: 'xxx',
///   deviceIp: '192.168.1.100',
///   sn: 'SN123',
/// );
/// // or with known PIN:
/// final client = await DeviceHub.connectWan(
///   api: myApiService,
///   token: 'xxx',
///   pinCode: '123456',
/// );
/// ```
///
/// LAN — one call with an IP:
/// ```dart
/// final client = await DeviceHub.connectLan(ip: '192.168.1.100');
/// ```
class DeviceHub {
  DeviceHub._();

  /// Connect via LAN (device on local network).
  ///
  /// Returns [ConnectionResult] on success (containing both [DeviceClient] and
  /// [MqttCredentials] for caching), null on failure.
  /// Listen to [strategy.progressStream] for step-by-step status.
  static Future<ConnectionResult?> connectLan({
    required String ip,
    int authPort = 1884,
    String accessCode = '12345678',
    DeviceSchema? schema,
    LanStrategy? strategy, // For testing or custom overrides
  }) async {
    final strat = strategy ?? LanStrategy(
      host: ip,
      authPort: authPort,
      accessCode: accessCode,
    );
    return _connect(strat, schema: schema);
  }

  /// Connect via WAN (cloud / AWS IoT).
  ///
  /// PIN acquisition: provide [deviceIp] + [sn] for auto-retrieval via LAN,
  /// or provide [pinCode] directly if known.
  static Future<ConnectionResult?> connectWan({
    required CloudApiClient api,
    required String token,
    String? deviceIp,
    String? sn,
    String? pinCode,
    String nickname = 'MyPrinter',
    DeviceSchema? schema,
    WanStrategy? strategy,
  }) async {
    final strat = strategy ?? WanStrategy(
      api: api,
      token: token,
      deviceIp: deviceIp,
      sn: sn,
      pinCode: pinCode,
      nickname: nickname,
    );
    return _connect(strat, schema: schema);
  }

  /// Generic: connect using any [ConnectionStrategy].
  static Future<ConnectionResult?> _connect(
    ConnectionStrategy strategy, {
    DeviceSchema? schema,
  }) async {
    final creds = await strategy.execute();
    if (creds == null) return null;

    final usedSchema = schema ?? DeviceSchema.fromJson(_defaultSchema(creds.sn));

    final client = DeviceClient(
      schema: usedSchema,
      adapter: MoonrakerAdapter.fromDataSource(usedSchema.dataSource),
      transport: MqttTransport(config: MqttConfig(
        host: creds.host,
        port: creds.port,
        clientId: creds.clientId,
        subscribeTopics: creds.subscribeTopics,
        securityContext: creds.securityContext,
      )),
    )..connect();

    return ConnectionResult(client: client, credentials: creds);
  }

  /// Reconnect using previously obtained [MqttCredentials] (e.g., from a cached
  /// certificate). Skips the pre-connection strategy entirely — ideal for fast
  /// reconnection without re-authorization.
  ///
  /// If [credentials.securityContext] is null but raw [ca]/[cert]/[key] strings
  /// are present on the credentials, a fresh [SecurityContext] is reconstructed
  /// automatically via [MqttCredentials.getOrCreateSecurityContext].
  static Future<ConnectionResult?> connectWithCredentials(
    MqttCredentials credentials, {
    DeviceSchema? schema,
  }) async {
    final secCtx = credentials.getOrCreateSecurityContext();
    final usedSchema = schema ?? DeviceSchema.fromJson(_defaultSchema(credentials.sn));

    final client = DeviceClient(
      schema: usedSchema,
      adapter: MoonrakerAdapter.fromDataSource(usedSchema.dataSource),
      transport: MqttTransport(config: MqttConfig(
        host: credentials.host,
        port: credentials.port,
        clientId: credentials.clientId,
        subscribeTopics: credentials.subscribeTopics,
        securityContext: secCtx,
      )),
    )..connect();

    return ConnectionResult(client: client, credentials: credentials);
  }

  static Map<String, dynamic> _defaultSchema(String sn) => {
    'version': '1.0',
    'deviceType': 'moonraker',
    'fields': {
      'toolhead.position': {'type': 'array', 'default': [0, 0, 0, 0]},
      'toolhead.status': {'type': 'string', 'default': 'Ready'},
      'toolhead.estimated_print_time': {'type': 'number', 'default': 0},
      'extruder.temperature': {'type': 'number', 'default': 0},
      'extruder.target': {'type': 'number', 'default': 0},
      'heater_bed.temperature': {'type': 'number', 'default': 0},
      'heater_bed.target': {'type': 'number', 'default': 0},
      'print_stats.state': {'type': 'string', 'default': 'standby'},
      'print_stats.filename': {'type': 'string', 'default': ''},
      'print_stats.total_duration': {'type': 'number', 'default': 0},
      'print_stats.filament_used': {'type': 'number', 'default': 0},
      'print_stats.info': {'type': 'object', 'default': {}},
      'virtual_sdcard.progress': {'type': 'number', 'default': 0},
      'virtual_sdcard.is_active': {'type': 'boolean', 'default': false},
      'fan.speed': {'type': 'number', 'default': 0},
      'system_stats.sysload': {'type': 'number', 'default': 0},
      'machine_state_manager.main_state': {'type': 'number', 'default': 0},
    },
    'dataSource': {
      'type': 'moonraker',
      'statusTopic': '$sn/status',
      'responseTopic': '$sn/response',
      'notificationTopic': '$sn/notification',
      'subscribe': {
        'toolhead': ['position', 'status', 'estimated_print_time'],
        'extruder': ['temperature', 'target'],
        'heater_bed': ['temperature', 'target'],
        'print_stats': ['filename', 'state', 'total_duration', 'filament_used', 'info'],
        'virtual_sdcard': ['progress', 'is_active'],
        'fan': ['speed'],
        'system_stats': ['sysload'],
        'machine_state_manager': null,
      },
    },
  };
}
