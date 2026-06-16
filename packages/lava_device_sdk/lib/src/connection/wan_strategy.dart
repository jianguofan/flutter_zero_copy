import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:lava_device_sdk/src/connection/connection_strategy.dart';
import 'package:lava_device_sdk/src/models/mqtt_credentials.dart';
import 'package:lava_device_sdk/src/models/types.dart';
import 'package:lava_device_sdk/src/mqtt/mqtt_transport.dart';

/// Cloud API abstraction — the SDK does not depend on a specific HTTP client.
/// The demo layer provides an implementation (e.g. WanApiService).
abstract class CloudApiClient {
  /// Bind the device to the user account. Returns the deviceId.
  Future<Map<String, dynamic>> bindDevice(String authCode, String nickname);

  /// Get MQTT certificate and connection details for the bound device.
  Future<DeviceCertConfig> getDeviceCert();

  /// Verify online authorization status. Non-fatal.
  Future<void> checkAuthStatus(String deviceId, String certId, String sn);

  /// Base URL for logging purposes.
  String get baseUrl;
}

/// Certificate config returned from the cloud.
class DeviceCertConfig {
  final String endpoint;
  final int port;
  final String clientId;
  final String cert;
  final String key;
  final String? ca;

  const DeviceCertConfig({
    required this.endpoint,
    required this.port,
    required this.clientId,
    required this.cert,
    required this.key,
    this.ca,
  });
}

/// WAN/cloud pre-connection strategy.
///
/// Flow: PIN acquisition → bind device → get cert → check auth → MQTT credentials.
///
/// PIN acquisition modes:
/// 1. **Provided [pinCode]**: skip LAN retrieval, use directly.
/// 2. **LAN retrieval**: connect to device LAN MQTT, request PIN, wait for user
///    to approve on device screen. Needs [deviceIp] and [sn].
class WanStrategy implements ConnectionStrategy {
  final CloudApiClient _api;
  final String _token;
  final String _nickname;
  final String? _deviceIp;
  final String? _sn;
  final String? _pinCode;

  final _progressController = StreamController<ConnectionProgress>.broadcast();
  bool _cancelled = false;

  WanStrategy({
    required CloudApiClient api,
    required String token,
    String nickname = 'MyPrinter',
    String? deviceIp,
    String? sn,
    String? pinCode,
  })  : _api = api,
        _token = token,
        _nickname = nickname,
        _deviceIp = deviceIp,
        _sn = sn,
        _pinCode = pinCode;

  @override
  Stream<ConnectionProgress> get progressStream => _progressController.stream;

  @override
  void cancel() => _cancelled = true;

  @override
  Future<MqttCredentials?> execute() async {
    // Step 1: Get PIN code
    final pinCode = await _getPinCode();
    if (pinCode == null || _cancelled) return null;

    // Step 2: Bind device
    _emit(const ConnectionProgress('Binding device...'));
    Map<String, dynamic> bindResult;
    try {
      bindResult = await _api.bindDevice(pinCode, _nickname);
    } catch (e) {
      _emit(ConnectionProgress.failed('Bind', '绑定设备失败: $e'));
      return null;
    }
    if (_cancelled) return null;
    final sn = bindResult['sn'] as String?;
    final deviceId = bindResult['deviceId'] as String?;
    if (sn == null || deviceId == null) {
      _emit(ConnectionProgress.failed('Bind', '绑定响应缺少 sn/deviceId'));
      return null;
    }

    // Step 3: Get TLS certificate
    _emit(const ConnectionProgress('Getting device certificate...'));
    DeviceCertConfig certConfig;
    try {
      certConfig = await _api.getDeviceCert();
    } catch (e) {
      _emit(ConnectionProgress.failed('Cert', '获取证书失败: $e'));
      return null;
    }
    if (_cancelled) return null;

    // Step 4: Check auth status (non-fatal)
    _emit(const ConnectionProgress('Verifying authorization...'));
    try {
      await _api.checkAuthStatus(deviceId, certConfig.clientId, sn);
    } catch (_) {
      // Non-fatal
    }
    if (_cancelled) return null;

    // Step 5: Build credentials
    final secCtx = SecurityContext(withTrustedRoots: false)
      ..useCertificateChainBytes(utf8.encode(certConfig.cert))
      ..usePrivateKeyBytes(utf8.encode(certConfig.key));
    if (certConfig.ca != null) {
      secCtx.setTrustedCertificatesBytes(utf8.encode(certConfig.ca!));
    }

    _emit(ConnectionProgress.done('Ready'));
    return MqttCredentials(
      host: certConfig.endpoint,
      port: certConfig.port,
      clientId: certConfig.clientId,
      sn: sn,
      securityContext: secCtx,
      subscribeTopics: MqttCredentials.defaultSubscribeTopics(sn),
      publishTopic: MqttCredentials.defaultPublishTopic(sn),
    );
  }

  Future<String?> _getPinCode() async {
    if (_pinCode != null) {
      _emit(const ConnectionProgress('Using provided PIN code...'));
      return _pinCode;
    }
    if (_deviceIp == null || _sn == null) {
      _emit(ConnectionProgress.failed('PIN',
          '需要提供 deviceIp + sn 以获取 PIN，或直接传入 pinCode'));
      return null;
    }

    _emit(const ConnectionProgress('Requesting PIN from device...'));
    try {
      return await _getPinCodeViaLan(_deviceIp!, _sn!);
    } catch (e) {
      _emit(ConnectionProgress.failed('PIN', '获取 PIN 失败: $e'));
      return null;
    }
  }

  /// Connect to device LAN MQTT and request PIN code.
  Future<String?> _getPinCodeViaLan(String deviceIp, String sn) async {
    final clientId = 'lava-pin-${DateTime.now().millisecondsSinceEpoch}';
    final appId = 'app-${DateTime.now().millisecondsSinceEpoch}';

    final transport = MqttTransport(config: MqttConfig(
      host: deviceIp,
      port: 1884,
      clientId: clientId,
      subscribeTopics: ['$sn/notification'],
    ));

    final completer = Completer<String?>();
    late StreamSubscription sub;

    sub = transport.messageStream.listen((msg) {
      try {
        final json = jsonDecode(utf8.decode(msg.payload)) as Map<String, dynamic>;
        if (json['method'] == 'notify_cloud_auth' && json['params'] is List) {
          final params = json['params'] as List;
          if (params.isNotEmpty && params[0] is Map) {
            final p = params[0] as Map;
            if (p['state'] == 'approve') {
              final pin = p['pin_code'] as String?;
              if (pin != null && !completer.isCompleted) {
                completer.complete(pin);
              }
            }
          }
        }
      } catch (_) {}
    });

    try {
      await transport.connect();
      transport.send('$sn/request', Uint8List.fromList(utf8.encode(jsonEncode({
        'jsonrpc': '2.0',
        'method': 'server.client_manager.request_pin_code',
        'params': {
          'userid': _token,
          'nickname': _nickname,
          'app_id': appId,
        },
        'id': 1,
      }))));

      return await completer.future.timeout(const Duration(seconds: 120));
    } catch (_) {
      return null;
    } finally {
      sub.cancel();
      transport.disconnect();
    }
  }

  void _emit(ConnectionProgress progress) {
    _progressController.add(progress);
  }
}
