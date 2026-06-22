/// 连接模式
enum ConnectionMode { lan, wan }

/// 连接状态机（6 个阶段）
enum ConnectionPhase {
  disconnected, // 未连接
  connecting,   // TCP/TLS 握手
  authorizing,  // 等待设备端授权
  authorized,   // 授权成功，订阅 topic
  connected,    // 全部就绪
  failed,       // 连接/授权失败
}

/// 连接阶段变化事件
class ConnectionEvent {
  final ConnectionPhase phase;
  final String? message;
  final dynamic data;

  const ConnectionEvent(this.phase, {this.message, this.data});

  @override
  String toString() => 'ConnectionEvent($phase, message: $message)';
}
