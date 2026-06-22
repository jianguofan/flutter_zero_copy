/// 心跳状态
class HeartbeatState {
  final bool active;
  final DateTime? lastOk;
  final int failCount;
  final bool isIdle;
  final DateTime? lastComm;

  const HeartbeatState({
    this.active = false,
    this.lastOk,
    this.failCount = 0,
    this.isIdle = true,
    this.lastComm,
  });

  HeartbeatState copyWith({
    bool? active,
    DateTime? lastOk,
    int? failCount,
    bool? isIdle,
    DateTime? lastComm,
  }) {
    return HeartbeatState(
      active: active ?? this.active,
      lastOk: lastOk ?? this.lastOk,
      failCount: failCount ?? this.failCount,
      isIdle: isIdle ?? this.isIdle,
      lastComm: lastComm ?? this.lastComm,
    );
  }

  @override
  String toString() =>
      'HeartbeatState(active: $active, failCount: $failCount, isIdle: $isIdle)';
}
