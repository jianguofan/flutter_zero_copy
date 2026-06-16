import 'dart:async';
import 'package:lava_device_sdk/src/core/state_patch.dart';

class _SubscriptionEntry {
  final String prefix; // "work_status.*", "work_status.temperature", "*"
  final List<String> matchedKeys; // Pre-computed
  final StreamController<StatePatch> controller;
  Timer? _batchTimer;
  final Map<String, dynamic> _pendingValues = {};
  String? _pendingPath;

  _SubscriptionEntry({
    required this.prefix,
    required this.matchedKeys,
    required this.controller,
  });

  void addPatch(String key, dynamic value) {
    _pendingValues[key] = value;
    _pendingPath ??= _computePath(prefix, key);

    _batchTimer?.cancel();
    _batchTimer = Timer(const Duration(milliseconds: 16), () {
      _flush();
    });
  }

  void _flush() {
    if (_pendingValues.isEmpty) return;
    final patch = StatePatch(
      path: _pendingPath!,
      values: Map.unmodifiable(_pendingValues),
      timestamp: DateTime.now(),
    );
    _pendingValues.clear();
    _pendingPath = null;
    controller.add(patch);
  }

  void dispose() {
    _batchTimer?.cancel();
    _pendingValues.clear();
    controller.close();
  }

  static String _computePath(String prefix, String firstKey) {
    if (prefix == '*' || prefix.endsWith('.*')) {
      // For wildcard prefixes, use the category of the first key
      final dot = firstKey.indexOf('.');
      return dot > 0 ? firstKey.substring(0, dot) : firstKey;
    }
    return prefix;
  }
}

class SubscriptionManager {
  final List<_SubscriptionEntry> _subscriptions = [];
  final List<String> Function(String prefix) _keysByPrefix;

  SubscriptionManager(this._keysByPrefix);

  Stream<StatePatch> _createStream(
    List<String> matchedKeys,
    String displayPath,
  ) {
    final controller = StreamController<StatePatch>.broadcast();

    final entry = _SubscriptionEntry(
      prefix: displayPath,
      matchedKeys: matchedKeys,
      controller: controller,
    );
    _subscriptions.add(entry);

    controller.onCancel = () {
      entry.dispose();
      _subscriptions.remove(entry);
    };

    return controller.stream;
  }

  Stream<StatePatch> watch(String prefix) {
    final matchedKeys = _keysByPrefix(prefix);
    return _createStream(matchedKeys, prefix);
  }

  Stream<StatePatch> watchKeys(List<String> keys) {
    return _createStream(keys, keys.join(','));
  }

  void notify(String key, dynamic value) {
    for (final entry in _subscriptions) {
      if (entry.matchedKeys.contains(key)) {
        entry.addPatch(key, value);
      }
    }
  }

  void dispose() {
    for (final entry in List.unmodifiable(_subscriptions)) {
      entry.dispose();
    }
    _subscriptions.clear();
  }
}
