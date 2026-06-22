import 'connection_phase.dart';

/// 设备连接配置
class ConnectionConfig {
  final ConnectionMode mode;
  final String host;
  final int port;
  final String sn;

  // LAN 特有
  final String accessCode;

  // WAN 特有
  final String? ca;
  final String? cert;
  final String? key;
  final String? clientId;

  const ConnectionConfig({
    required this.mode,
    required this.host,
    required this.port,
    this.sn = '+',
    this.accessCode = '12345678',
    this.ca,
    this.cert,
    this.key,
    this.clientId,
  });

  bool get isLan => mode == ConnectionMode.lan;
  bool get isWan => mode == ConnectionMode.wan;
}
