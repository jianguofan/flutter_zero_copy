import 'package:flutter_zero_copy/features/device/data/adapters/lava_sdk_connection.dart';
import 'package:flutter_zero_copy/features/device/data/certificate_storage.dart';
import 'package:flutter_zero_copy/features/device/data/models/device_impl.dart';
import 'package:flutter_zero_copy/features/device/application/providers/device_metadata_store_provider.dart';
import 'package:flutter_zero_copy/features/device/domain/entities/device_info.dart';
import 'package:flutter_zero_copy/features/device/domain/interfaces/i_connection.dart';
import 'package:flutter_zero_copy/features/device/domain/interfaces/i_device_facade.dart';
import 'package:flutter_zero_copy/features/device/domain/interfaces/i_device_registry.dart';
import 'package:flutter_zero_copy/features/device/domain/interfaces/i_device_session.dart';
import 'package:rxdart/rxdart.dart';

/// [IDeviceSession] implementation — the Mediator.
///
/// Orchestrates [IDeviceRegistry] lookups + [IDeviceFacade] lifecycle.
/// The ONLY component that owns the "current active device" concept.
///
/// **重构**: 注入 DeviceMetadataStoreNotifier，传递给 DeviceImpl
class DeviceSessionImpl implements IDeviceSession {
  final IDeviceRegistry _registry;
  final DeviceMetadataStoreNotifier _notifier; // ← 注入 Notifier

  final BehaviorSubject<DeviceSessionState> _stateController;
  DeviceImpl? _activeDevice;

  DeviceSessionImpl({
    required IDeviceRegistry registry,
    required DeviceMetadataStoreNotifier notifier, // ← 构造函数注入
  })  : _registry = registry,
        _notifier = notifier,
        _stateController =
            BehaviorSubject<DeviceSessionState>.seeded(const DeviceSessionIdle());

  @override
  DeviceSessionState get state => _stateController.value;

  @override
  Stream<DeviceSessionState> get stateStream => _stateController.stream;

  @override
  IDeviceFacade? get activeDevice => _activeDevice;

  @override
  DeviceInfo? get activeDeviceInfo {
    final current = _stateController.value;
    return switch (current) {
      DeviceSessionActive(:final device) => device.info,
      DeviceSessionActivating(:final info) => info,
      DeviceSessionError(:final info) => info,
      _ => null,
    };
  }

  @override
  Future<void> activate(String deviceId) async {
    // Step 1: Look up device in registry
    final info = _registry.lookup(deviceId);
    if (info == null) {
      _stateController.add(DeviceSessionError(
        DeviceInfo(id: deviceId, name: 'Unknown', sn: ''),
        Exception('Device not found in registry'),
      ));
      return;
    }

    // Step 2: Transition to activating
    _stateController.add(DeviceSessionActivating(info));

    try {
      // Step 3: Deactivate existing device if any
      await deactivate();

      // Step 4: Create connection
      final connection = await _createConnection(info);
      if (connection == null) {
        _stateController.add(DeviceSessionError(
          info,
          Exception('Failed to create connection'),
        ));
        return;
      }

      // Step 5: Create DeviceImpl aggregate (注入 Notifier)
      _activeDevice = DeviceImpl(
        info: info,
        connection: connection,
        notifier: _notifier, // ← 传递 Notifier
      );

      // Step 6: Establish transport connection
      await _activeDevice!.connect();

      // Step 7: Transition to active
      _stateController.add(DeviceSessionActive(_activeDevice!));

      // Step 8: Persist active state
      await _registry.setActiveDevice(deviceId);
    } catch (e, st) {
      _stateController.add(DeviceSessionError(info, e, st));
    }
  }

  @override
  Future<void> deactivate() async {
    if (_activeDevice != null) {
      await _activeDevice!.disconnect();
      await _activeDevice!.dispose();
      _activeDevice = null;
    }
    await _registry.clearActiveDevice();
    _stateController.add(const DeviceSessionIdle());
  }

  /// Release all resources.
  Future<void> dispose() async {
    await deactivate();
    await _stateController.close();
  }

  // ── Internal: Connection factory ──

  Future<IConnection?> _createConnection(DeviceInfo info) async {
    if (info.networkType == NetworkType.lan) {
      // 1) Try cached certificate first (skip auth)
      final cached = await CertificateStorage.load(info.sn);
      if (cached != null) {
        try {
          final conn = await LavaSdkConnection.createWithCredentials(cached);
          if (conn != null) return conn;
        } catch (_) {
          // Cached cert failed — fall through to full auth
        }
      }

      // 2) Full LAN auth flow
      final conn = await LavaSdkConnection.createLan(
        ip: info.ipAddress!,
        accessCode: info.accessCode ?? '12345678',
      );

      // 3) Persist certificate for future reconnections
      if (conn?.credentials?.hasTlsCredentials == true) {
        await CertificateStorage.save(conn!.credentials!);
      }

      return conn;
    }
    // WAN not implemented yet (Phase 2)
    return null;
  }
}
