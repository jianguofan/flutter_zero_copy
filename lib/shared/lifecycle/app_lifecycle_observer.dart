import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_zero_copy/features/device/domain/interfaces/i_device_session.dart';
import 'package:flutter_zero_copy/shared/logger/logger.dart';

/// Observes app lifecycle changes and manages device connection accordingly.
///
/// - On [AppLifecycleState.paused]: deactivates the active device session.
/// - On [AppLifecycleState.resumed]: restores the previously active device.
/// - On [AppLifecycleState.detached]: full cleanup.
class AppLifecycleObserver with WidgetsBindingObserver {
  final IDeviceSession _session;
  final IAppLogger _logger;

  String? _lastActiveDeviceId;
  bool _wasActive = false;

  AppLifecycleObserver({
    required IDeviceSession session,
    required IAppLogger logger,
  })  : _session = session,
        _logger = logger {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _logger.info('App lifecycle: $state');

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _onBackground();
      case AppLifecycleState.resumed:
        _onForeground();
      case AppLifecycleState.detached:
        _onTerminate();
      case AppLifecycleState.hidden:
        break; // No action needed
    }
  }

  Future<void> _onBackground() async {
    _wasActive = _session.activeDevice != null;
    if (_wasActive) {
      _lastActiveDeviceId = _session.activeDeviceInfo?.id;
      _logger.info('App entering background — deactivating device');
      await _session.deactivate();
    }
  }

  Future<void> _onForeground() async {
    if (_wasActive && _lastActiveDeviceId != null) {
      _logger.info('App resumed — restoring device: $_lastActiveDeviceId');
      try {
        await _session.activate(_lastActiveDeviceId!);
      } catch (e) {
        _logger.warn('Failed to restore device on resume: $e');
      }
    }
  }

  Future<void> _onTerminate() async {
    _logger.info('App terminating — full cleanup');
    await _session.deactivate();
  }

  /// Remove the observer (call in dispose).
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }

  /// Attempt to restore the last active device ID from persisted storage.
  Future<String?> getLastActiveDeviceId() async {
    return _lastActiveDeviceId;
  }
}
