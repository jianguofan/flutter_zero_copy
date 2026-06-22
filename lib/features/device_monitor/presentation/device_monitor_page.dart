import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/mock_device_monitor.dart';
import '../models/metrics_event.dart';

/// 设备监控页面 — 连接元数据 + 事件搜集展示
class DeviceMonitorPage extends StatefulWidget {
  const DeviceMonitorPage({super.key});

  @override
  State<DeviceMonitorPage> createState() => _DeviceMonitorPageState();
}

class _DeviceMonitorPageState extends State<DeviceMonitorPage> {
  final _monitor = MockDeviceMonitor();
  StreamSubscription<MetricsEvent>? _eventSub;
  final _events = <MetricsEvent>[];
  static const _maxDisplayEvents = 100;

  @override
  void initState() {
    super.initState();
    _eventSub = _monitor.eventStream.listen((e) {
      setState(() {
        _events.insert(0, e);
        if (_events.length > _maxDisplayEvents) _events.removeLast();
      });
    });
    _monitor.addListener(() => setState(() {}));
    _monitor.start();
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _monitor.dispose();
    super.dispose();
  }

  // ── 导出 ──

  void _exportAll() {
    final data = _monitor.exportAll();
    final json = const JsonEncoder.withIndent('  ').convert(data);
    Clipboard.setData(ClipboardData(text: json));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已复制到剪贴板'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showStoreData() {
    final data = _monitor.storeData;
    final json = const JsonEncoder.withIndent('  ').convert(data);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.storage, size: 20),
            SizedBox(width: 8),
            Text('Store 数据'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: SingleChildScrollView(
            child: SelectableText(
              json,
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: json));
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Store 数据已复制到剪贴板'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text('复制'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final snap = _monitor.snapshot;
    return Container(
      color: const Color(0xFFF5F6FA),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── 连接元数据卡片（新增） ──
                  _MetadataCard(
                    config: _monitor.config,
                    phase: _monitor.phaseLabel,
                    sessionStart: _monitor.sessionStart,
                    onViewStore: _showStoreData,
                  ),
                  const SizedBox(height: 12),
                  // ── 连接状态卡片 ──
                  _StatusCard(monitor: _monitor),
                  const SizedBox(height: 12),
                  // ── 成功率指标行 ──
                  _MetricsRow(snap: snap),
                  const SizedBox(height: 12),
                  // ── 链路质量 + 延迟 ──
                  _QualityCard(monitor: _monitor, snap: snap),
                  const SizedBox(height: 12),
                  // ── 消息/命令计数 ──
                  _MessageCard(snap: snap),
                  const SizedBox(height: 12),
                  // ── 事件时间线 ──
                  _EventTimeline(events: _events),
                  const SizedBox(height: 12),
                  // ── 导出按钮 ──
                  _ExportButton(onExport: _exportAll),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════
// 连接元数据卡片
// ══════════════════════════════════════════════

class _MetadataCard extends StatelessWidget {
  final dynamic config;
  final String phase;
  final DateTime? sessionStart;
  final VoidCallback onViewStore;

  const _MetadataCard({
    required this.config,
    required this.phase,
    required this.sessionStart,
    required this.onViewStore,
  });

  @override
  Widget build(BuildContext context) {
    String duration = '—';
    if (sessionStart != null) {
      final d = DateTime.now().difference(sessionStart!);
      duration =
          '${d.inHours}h ${d.inMinutes.remainder(60)}m ${d.inSeconds.remainder(60)}s';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline, size: 16,
                    color: Color(0xFF0C63E2)),
                const SizedBox(width: 6),
                const Text('连接元数据',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton.icon(
                  onPressed: onViewStore,
                  icon: const Icon(Icons.storage, size: 16),
                  label: const Text('Store', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            const Divider(),
            _MetaRow('模式', config.mode.name.toUpperCase()),
            _MetaRow('主机', '${config.host}:${config.port}'),
            _MetaRow('SN', config.sn),
            _MetaRow('阶段', phase),
            _MetaRow('会话', duration),
          ],
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final String label, value;
  const _MetaRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF999999))),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w500,
                    fontFamily: 'monospace')),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════
// 连接状态卡片
// ══════════════════════════════════════════════

class _StatusCard extends StatelessWidget {
  final MockDeviceMonitor monitor;
  const _StatusCard({required this.monitor});

  @override
  Widget build(BuildContext context) {
    final sessionStart = monitor.sessionStart;
    String duration = '—';
    if (sessionStart != null) {
      final d = DateTime.now().difference(sessionStart);
      duration =
          '${d.inHours}h ${d.inMinutes.remainder(60)}m ${d.inSeconds.remainder(60)}s';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // 状态指示灯
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: monitor.phaseColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '连接状态: ${monitor.phaseLabel}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'LAN 模式 · 会话: $duration',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF666666)),
                  ),
                ],
              ),
            ),
            // 断开按钮
            if (monitor.phase.name == 'connected')
              OutlinedButton(
                onPressed: monitor.disconnect,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFF40004),
                ),
                child: const Text('断开'),
              ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════
// 指标行
// ══════════════════════════════════════════════

class _MetricsRow extends StatelessWidget {
  final dynamic snap;
  const _MetricsRow({required this.snap});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _MetricTile(
            label: '可用率', value: '${(snap.availability * 100).toStringAsFixed(1)}%',
            color: const Color(0xFF00D4AA))),
        const SizedBox(width: 8),
        Expanded(child: _MetricTile(
            label: '连接成功率', value: '${(snap.connectSuccessRate * 100).toStringAsFixed(1)}%',
            color: const Color(0xFF0C63E2))),
        const SizedBox(width: 8),
        Expanded(child: _MetricTile(
            label: '命令成功率', value: '${(snap.commandSuccessRate * 100).toStringAsFixed(1)}%',
            color: const Color(0xFF00D4AA))),
        const SizedBox(width: 8),
        Expanded(child: _MetricTile(
            label: '心跳成功率', value: '${(snap.heartbeatSuccessRate * 100).toStringAsFixed(1)}%',
            color: const Color(0xFF0C63E2))),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label, value;
  final Color color;
  const _MetricTile({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700, color: color)),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFF666666))),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════
// 链路质量 + 延迟
// ══════════════════════════════════════════════

class _QualityCard extends StatelessWidget {
  final MockDeviceMonitor monitor;
  final dynamic snap;
  const _QualityCard({required this.monitor, required this.snap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('链路质量 & 延迟',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Row(
              children: [
                // 链路质量
                _QualityBadge(
                    label: '链路质量',
                    value: monitor.quality.name.toUpperCase(),
                    color: monitor.qualityColor),
                const SizedBox(width: 24),
                // 心跳
                _QualityBadge(
                    label: '心跳',
                    value: monitor.heartbeat.active
                        ? 'OK (${monitor.heartbeat.failCount} fail)'
                        : 'IDLE',
                    color: monitor.heartbeat.active
                        ? const Color(0xFF00D4AA)
                        : const Color(0xFF999999)),
              ],
            ),
            const SizedBox(height: 16),
            // 延迟 P50/P95/P99
            Row(
              children: [
                Expanded(
                    child: _LatencyCol(
                        label: 'PUBACK',
                        p50: snap.pubAckP50Ms,
                        p95: snap.pubAckP95Ms,
                        p99: snap.pubAckP99Ms)),
                const SizedBox(width: 16),
                Expanded(
                    child: _LatencyCol(
                        label: 'RTT',
                        p50: snap.heartbeatRttP50Ms,
                        p95: snap.heartbeatRttP95Ms,
                        p99: snap.heartbeatRttP99Ms)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QualityBadge extends StatelessWidget {
  final String label, value;
  final Color color;
  const _QualityBadge(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style:
                const TextStyle(fontSize: 11, color: Color(0xFF999999))),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color)),
        ),
      ],
    );
  }
}

class _LatencyCol extends StatelessWidget {
  final String label;
  final double p50, p95, p99;
  const _LatencyCol(
      {required this.label,
      required this.p50,
      required this.p95,
      required this.p99});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style:
                const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('P50: ${p50 > 0 ? '${p50.toStringAsFixed(0)}ms' : '—'}',
            style: const TextStyle(fontSize: 11)),
        Text('P95: ${p95 > 0 ? '${p95.toStringAsFixed(0)}ms' : '—'}',
            style: const TextStyle(fontSize: 11)),
        Text('P99: ${p99 > 0 ? '${p99.toStringAsFixed(0)}ms' : '—'}',
            style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}

// ══════════════════════════════════════════════
// 消息/命令计数
// ══════════════════════════════════════════════

class _MessageCard extends StatelessWidget {
  final dynamic snap;
  const _MessageCard({required this.snap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('消息统计',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Row(
              children: [
                _CountChip(
                    label: '发送', count: snap.messagesSent, color: const Color(0xFF0C63E2)),
                const SizedBox(width: 12),
                _CountChip(
                    label: '接收', count: snap.messagesReceived, color: const Color(0xFF00D4AA)),
                const SizedBox(width: 12),
                _CountChip(
                    label: '命令', count: snap.commandsSent, color: const Color(0xFFFF9900)),
                const SizedBox(width: 12),
                _CountChip(
                    label: '心跳', count: snap.heartbeatsSent, color: const Color(0xFF7B68EE)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _CountChip(
      {required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$count',
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w700, color: color)),
        Text(label,
            style:
                const TextStyle(fontSize: 11, color: Color(0xFF999999))),
      ],
    );
  }
}

// ══════════════════════════════════════════════
// 事件时间线
// ══════════════════════════════════════════════

class _EventTimeline extends StatelessWidget {
  final List<MetricsEvent> events;
  const _EventTimeline({required this.events});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('事件时间线',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('${events.length} 条',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF999999))),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 300,
              child: events.isEmpty
                  ? const Center(
                      child: Text('等待事件…',
                          style: TextStyle(color: Color(0xFF999999))))
                  : ListView.separated(
                      itemCount: events.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1),
                      itemBuilder: (_, i) => _EventRow(event: events[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  final MetricsEvent event;
  const _EventRow({required this.event});

  Color get _color {
    switch (event.type) {
      case MetricsEventType.connectSuccess:
      case MetricsEventType.reconnectSuccess:
        return const Color(0xFF00D4AA);
      case MetricsEventType.connectFailure:
      case MetricsEventType.reconnectFailure:
      case MetricsEventType.heartbeatFailure:
      case MetricsEventType.commandTimeout:
      case MetricsEventType.maxBackoffReached:
        return const Color(0xFFF40004);
      case MetricsEventType.qualityChange:
        return const Color(0xFFFF9900);
      case MetricsEventType.latencySample:
        return const Color(0xFF0C63E2);
      case MetricsEventType.messageSent:
        return const Color(0xFF0C63E2);
      case MetricsEventType.messageReceived:
        return const Color(0xFF00D4AA);
      default:
        return const Color(0xFF999999);
    }
  }

  String get _label {
    switch (event.type) {
      case MetricsEventType.connectAttempt: return '连接尝试';
      case MetricsEventType.connectSuccess: return '连接成功';
      case MetricsEventType.connectFailure: return '连接失败';
      case MetricsEventType.disconnect:     return '断开';
      case MetricsEventType.reconnectAttempt: return '重连尝试';
      case MetricsEventType.reconnectSuccess: return '重连成功';
      case MetricsEventType.reconnectFailure: return '重连失败';
      case MetricsEventType.maxBackoffReached: return '最大退避';
      case MetricsEventType.qualityChange:  return '质量变化';
      case MetricsEventType.timeoutExtension: return '超时延长';
      case MetricsEventType.heartbeatFailure: return '心跳失败';
      case MetricsEventType.commandTimeout: return '命令超时';
      case MetricsEventType.latencySample:  return '延迟采样';
      case MetricsEventType.messageSent:    return '消息发送';
      case MetricsEventType.messageReceived: return '消息接收';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ts = event.timestamp.toIso8601String().substring(11, 23);
    final detail = _formatDetail();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
                shape: BoxShape.circle, color: _color),
          ),
          const SizedBox(width: 8),
          Text(ts,
              style: const TextStyle(
                  fontSize: 11, color: Color(0xFF999999),
                  fontFamily: 'monospace')),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: _color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(_label,
                style: TextStyle(fontSize: 10, color: _color)),
          ),
          if (detail.isNotEmpty) ...[
            const SizedBox(width: 8),
            Expanded(
              child: Text(detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 10, color: Color(0xFF666666))),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDetail() {
    final data = event.data;
    if (data == null || data.isEmpty) return '';

    switch (event.type) {
      case MetricsEventType.messageSent:
      case MetricsEventType.messageReceived:
        final topic = data['topic'] ?? '—';
        final size = data['size'];
        final count = data['count'];
        final parts = <String>['topic: $topic'];
        if (size != null) parts.add('${size}B');
        if (count != null) parts.add('#$count');
        return parts.join(' · ');
      case MetricsEventType.qualityChange:
        return '${data['from']} → ${data['to']}';
      case MetricsEventType.latencySample:
        return '${data['link']}: ${data['delayMs']}ms';
      default:
        return data.entries.map((e) => '${e.key}: ${e.value}').join(' ');
    }
  }
}

// ══════════════════════════════════════════════
// 导出按钮
// ══════════════════════════════════════════════

class _ExportButton extends StatelessWidget {
  final VoidCallback onExport;
  const _ExportButton({required this.onExport});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: onExport,
        icon: const Icon(Icons.download, size: 20),
        label: const Text('导出全部数据 (metadata + store + metrics + events)',
            style: TextStyle(fontSize: 13)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0C63E2),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}
