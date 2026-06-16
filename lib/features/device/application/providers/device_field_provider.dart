import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_zero_copy/features/device/application/providers/device_session_provider.dart';

/// Subscribe to a specific field of the active device as a [Stream].
///
/// Usage:
/// ```dart
/// final tempStream = ref.watch(deviceFieldStreamProvider('temperature.nozzle'));
/// // Use with StreamBuilder or .when() pattern
/// ```
///
/// Returns an empty stream when no device is active.
final deviceFieldStreamProvider =
    Provider.family<Stream<dynamic>, String>((ref, fieldPath) {
  final activeDevice = ref.watch(activeDeviceProvider);

  if (activeDevice == null) {
    return const Stream.empty();
  }

  return activeDevice.fieldStream<dynamic>(fieldPath);
});

/// Get the current value of a field (snapshot, not streaming).
///
/// Returns `null` if the device is not active or the field is unknown.
final deviceFieldValueProvider =
    Provider.family<Object?, String>((ref, fieldPath) {
  final activeDevice = ref.watch(activeDeviceProvider);
  return activeDevice?.getField<dynamic>(fieldPath);
});
