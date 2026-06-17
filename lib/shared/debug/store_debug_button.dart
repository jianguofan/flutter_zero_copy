import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_zero_copy/features/device/application/providers/device_metadata_store_provider.dart';
import 'package:flutter_zero_copy/features/device/domain/entities/device_metadata.dart';

/// 全局浮动的 Store 调试按钮
///
/// 点击后弹出面板，实时查看 DeviceMetadataStore 的全部数据。
/// 仅在 debug 模式下可用。
class StoreDebugButton extends ConsumerStatefulWidget {
  const StoreDebugButton({super.key});

  @override
  ConsumerState<StoreDebugButton> createState() => _StoreDebugButtonState();
}

class _StoreDebugButtonState extends ConsumerState<StoreDebugButton> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    // 实时监听 Store 数据变化
    ref.watch(deviceMetadataStoreProvider);
    final notifier = ref.read(deviceMetadataStoreProvider.notifier);
    final devices = notifier.allDevices;

    if (!_isExpanded) {
      return Positioned(
        right: 16,
        bottom: 80,
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(77),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _isExpanded = true),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bug_report, color: Colors.greenAccent, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Store: ${devices.length}',
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 11,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.expand_less, color: Colors.greenAccent, size: 14),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    // 展开状态：半屏面板
    return Positioned(
      right: 0,
      bottom: 0,
      width: MediaQuery.of(context).size.width * 0.45,
      height: MediaQuery.of(context).size.height * 0.6,
      child: Material(
        elevation: 16,
        color: const Color(0xFF1A1A2E),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
        ),
        child: Column(
          children: [
            // 标题栏
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFF0F3460),
                borderRadius: BorderRadius.only(topLeft: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.storage, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'DeviceMetadataStore',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '${devices.length} devices',
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => setState(() => _isExpanded = false),
                    child: const Icon(Icons.close, color: Colors.white, size: 18),
                  ),
                ],
              ),
            ),
            // 内容区
            Expanded(
              child: devices.isEmpty
                  ? const Center(
                      child: Text(
                        'No devices in store',
                        style: TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: devices.length,
                      separatorBuilder: (_, __) => const Divider(
                        color: Colors.white12,
                        height: 1,
                      ),
                      itemBuilder: (context, index) {
                        final d = devices[index];
                        return _buildDeviceItem(d);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceItem(DeviceMetadata d) {
    final staleCount = [
      d.nozzleTemp?.isStale,
      d.bedTemp?.isStale,
      d.chamberTemp?.isStale,
      d.printState?.isStale,
      d.progress?.isStale,
    ].where((s) => s == true).length;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 在线状态 + 名称
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: d.isOnline ? Colors.green.withAlpha(40) : Colors.grey.withAlpha(40),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  d.isOnline ? '● ONLINE' : '○ OFFLINE',
                  style: TextStyle(
                    fontSize: 9,
                    color: d.isOnline ? Colors.greenAccent : Colors.white38,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  d.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _kv('sn', d.sn),
          if (d.ipAddress != null) _kv('ip', d.ipAddress!),
          if (d.accessCode != null) _kv('accessCode', d.accessCode!),
          if (d.model != null) _kv('model', d.model!),
          if (d.firmwareVersion != null) _kv('fw', d.firmwareVersion!),
          _kv('connState', d.connectionState.name),
          _kv('staleFields', '$staleCount/5'),
          // 遥测数据
          if (d.nozzleTemp != null || d.bedTemp != null || d.printState != null) ...[
            const SizedBox(height: 4),
            const Text(
              'Telemetry:',
              style: TextStyle(color: Colors.white38, fontSize: 10, fontFamily: 'monospace'),
            ),
            if (d.nozzleTemp != null)
              _kv('nozzle', '${d.nozzleTemp!.value}°C${d.nozzleTemp!.isStale ? " [stale]" : ""}'),
            if (d.bedTemp != null)
              _kv('bed', '${d.bedTemp!.value}°C${d.bedTemp!.isStale ? " [stale]" : ""}'),
            if (d.chamberTemp != null)
              _kv('chamber', '${d.chamberTemp!.value}°C${d.chamberTemp!.isStale ? " [stale]" : ""}'),
            if (d.printState != null)
              _kv('state', '${d.printState!.value}${d.printState!.isStale ? " [stale]" : ""}'),
            if (d.progress != null)
              _kv('progress', '${d.progress!.value}%${d.progress!.isStale ? " [stale]" : ""}'),
            if (d.filamentUsed != null) _kv('filament', '${d.filamentUsed!.toStringAsFixed(1)}m'),
            if (d.totalDuration != null) _kv('duration', '${d.totalDuration}s'),
          ],
          // 云端字段
          if (d.cloudName != null || d.cloudOnline != null) ...[
            const SizedBox(height: 4),
            const Text(
              'Cloud:',
              style: TextStyle(color: Colors.white38, fontSize: 10, fontFamily: 'monospace'),
            ),
            if (d.cloudName != null) _kv('cName', d.cloudName!),
            if (d.cloudOnline != null) _kv('cOnline', '${d.cloudOnline}'),
            if (d.cloudDeviceId != null) _kv('cId', '${d.cloudDeviceId}'),
          ],
          // 快照
          if (d.snapshots.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Snapshots: ${d.snapshots.length} (last: ${d.snapshots.last.reason})',
                style: const TextStyle(color: Colors.white30, fontSize: 9, fontFamily: 'monospace'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _kv(String key, String value) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 1),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
          children: [
            TextSpan(text: key.padRight(14), style: const TextStyle(color: Colors.white38)),
            TextSpan(text: value, style: const TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}
