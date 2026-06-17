import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:lava_device_sdk/src/connection/connection_strategy.dart';
import 'package:lava_device_sdk/src/models/mqtt_credentials.dart';
import 'package:lava_device_sdk/src/models/types.dart';
import 'package:lava_device_sdk/src/mqtt/mqtt_transport.dart';
import 'package:lava_device_sdk/src/transport/transport.dart';

/// LAN pre-connection strategy.
///
/// Auth flow: plain MQTT → confirm_lan_status → (optional) request_lan_auth
/// → device issues TLS cert → return [MqttCredentials].
class LanStrategy implements ConnectionStrategy {
  final String _host;
  final int _authPort;
  final String _accessCode;

  final _progressController = StreamController<ConnectionProgress>.broadcast();
  MqttTransport? _authTransport;
  StreamSubscription? _msgSub;
  int _seqId = 0;
  final _pending = <int, Completer<Map<String, dynamic>>>{};
  Completer<Map<String, dynamic>?>? _authNotificationCompleter;
  bool _cancelled = false;

  LanStrategy({
    required String host,
    int authPort = 1884,
    String accessCode = '12345678',
  })  : _host = host,
        _authPort = authPort,
        _accessCode = accessCode;

  @override
  Stream<ConnectionProgress> get progressStream => _progressController.stream;

  @override
  void cancel() {
    _cancelled = true;
    _msgSub?.cancel();
    _authTransport?.disconnect();
  }

  @override
  Future<MqttCredentials?> execute() async {
    final appClientId = 'lava-lan-${DateTime.now().millisecondsSinceEpoch}';

    _emit(const ConnectionProgress('Connecting to device...'));
    _authTransport = MqttTransport(config: MqttConfig(
      host: _host,
      port: _authPort,
      clientId: '$appClientId-auth',
      subscribeTopics: [
        '$_accessCode/config/response',
        '+/status',
        '+/notification',
        '$_accessCode/config/notification',
      ],
    ));

    _msgSub = _authTransport!.messageStream.listen(_onMessage);

    try {
      await _authTransport!.connect();
    } catch (e) {
      _emit(ConnectionProgress.failed('Connect', 'Auth MQTT 连接失败: $e'));
      return null;
    }
    if (_cancelled) return null;

    // Query auth state
    _emit(const ConnectionProgress('Querying authorization...'));
    final confirmResp = await _rpcCall(
      'server.client_manager.confirm_lan_status',
      {'clientid': appClientId},
    );
    if (confirmResp == null || _cancelled) {
      _emit(ConnectionProgress.failed('Auth query', '授权查询超时'));
      return null;
    }

    final result = confirmResp['result'];
    if (result == null) {
      _emit(ConnectionProgress.failed('Auth query', '授权查询无响应'));
      return null;
    }

    final state = result['state'] as String? ?? '';

    switch (state.toLowerCase()) {
      case 'success':
        // Already authorized → extract credentials directly
        return _buildCredentials(result, appClientId);

      case 'unauthorized':
        // Need user approval on device screen
        _emit(const ConnectionProgress('Waiting for device approval...'));
        await _rpcCall('server.client_manager.request_lan_auth', {
          'clientid': appClientId,
          'app_id': 'app-$appClientId',
        }, timeout: const Duration(seconds: 30));

        // Wait for the auth result to arrive via notification
        final authResult = await _waitForAuthNotification();
        if (authResult == null || _cancelled) {
          _emit(ConnectionProgress.failed('Authorization', '设备授权超时或拒绝'));
          return null;
        }
        return _buildCredentials(authResult, appClientId);

      case 'authorizing':
        // Device is already in authorizing state, wait for result
        _emit(const ConnectionProgress('Waiting for device confirmation...'));
        final authResult = await _waitForAuthNotification();
        if (authResult == null || _cancelled) {
          _emit(ConnectionProgress.failed('Authorization', '设备授权超时'));
          return null;
        }
        return _buildCredentials(authResult, appClientId);

      default:
        _emit(ConnectionProgress.failed('Auth', '未知授权状态: $state'));
        return null;
    }
  }

  Future<Map<String, dynamic>?> _waitForAuthNotification() async {
    _authNotificationCompleter = Completer<Map<String, dynamic>?>();

    try {
      return await _authNotificationCompleter!.future.timeout(const Duration(seconds: 30));
    } on TimeoutException {
      return null;
    } finally {
      _authNotificationCompleter = null;
    }
  }

  Future<Map<String, dynamic>?> _rpcCall(
    String method,
    Map<String, dynamic> params, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final id = ++_seqId;
    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = completer;
    _authTransport!.send('$_accessCode/config/request', Uint8List.fromList(
      utf8.encode(jsonEncode({
        'jsonrpc': '2.0',
        'method': method,
        'params': params,
        'id': id,
      })),
    ));
    try {
      return await completer.future.timeout(timeout);
    } on TimeoutException {
      _pending.remove(id);
      return null;
    }
  }

  void _onMessage(TransportMessage msg) {
    try {
      final json = jsonDecode(utf8.decode(msg.payload)) as Map<String, dynamic>;

      // Handle RPC responses (have 'id' field)
      final id = json['id'];
      if (id is num && _pending.containsKey(id.toInt())) {
        _pending.remove(id.toInt())!.complete(json);
        return;
      }

      // Handle notifications (have 'method' field)
      final method = json['method'] as String?;
      if (method != null && _authNotificationCompleter != null && !_authNotificationCompleter!.isCompleted) {
        // Handle notify_lan_auth notification (LAN mode)
        if (method == 'notify_lan_auth' && json['params'] is List) {
          final params = json['params'] as List;
          if (params.isNotEmpty && params[0] is Map) {
            final p = params[0] as Map;
            final state = p['state'] as String?;

            if (state == 'approve') {
              // Certificate data is directly in params[0], not in params[0]['result']
              _authNotificationCompleter!.complete(p as Map<String, dynamic>);
            } else if (state == 'denied') {
              _authNotificationCompleter!.complete(null);
            }
            return;
          }
        }

        // Handle notify_cloud_auth notification (WAN mode fallback)
        if (method == 'notify_cloud_auth' && json['params'] is List) {
          final params = json['params'] as List;
          if (params.isNotEmpty && params[0] is Map) {
            final p = params[0] as Map;
            final state = p['state'] as String?;

            if (state == 'approve') {
              _authNotificationCompleter!.complete(p as Map<String, dynamic>);
            } else if (state == 'denied') {
              _authNotificationCompleter!.complete(null);
            }
            return;
          }
        }
      }
    } catch (_) {}
  }

  MqttCredentials? _buildCredentials(Map result, String clientId) {
    final sn = result['sn'] as String?;
    if (sn == null) {
      _emit(ConnectionProgress.failed('Credentials', '设备 SN 缺失'));
      return null;
    }

    final port = (result['port'] as num?)?.toInt() ?? 1884;
    final ca = result['ca'] as String?;
    final cert = result['cert'] as String?;
    final key = result['key'] as String?;

    SecurityContext? secCtx;
    if (cert != null && key != null) {
      secCtx = SecurityContext(withTrustedRoots: false)
        ..useCertificateChainBytes(utf8.encode(cert))
        ..usePrivateKeyBytes(utf8.encode(key));
      if (ca != null) {
        secCtx.setTrustedCertificatesBytes(utf8.encode(ca));
      }
    }

    final cid = result['clientId'] as String? ?? clientId;

    _emit(ConnectionProgress.done('Authorized'));
    return MqttCredentials(
      host: _host,
      port: port,
      clientId: cid,
      sn: sn,
      securityContext: secCtx,
      subscribeTopics: MqttCredentials.defaultSubscribeTopics(sn),
      publishTopic: MqttCredentials.defaultPublishTopic(sn),
      ca: ca,
      cert: cert,
      key: key,
    );
  }

  void _emit(ConnectionProgress progress) {
    _progressController.add(progress);
  }
}
