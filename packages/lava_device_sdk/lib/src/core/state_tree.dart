import 'package:lava_device_sdk/src/core/field_definition.dart';
import 'package:lava_device_sdk/src/core/schema.dart';
import 'package:lava_device_sdk/src/core/state_patch.dart';
import 'package:lava_device_sdk/src/core/subscription.dart';
import 'package:lava_device_sdk/src/core/validator.dart';

class StateTree {
  final Map<String, dynamic> _tree = {};
  DeviceSchema? _schema;
  late SubscriptionManager _subscriptions;
  final Map<String, DateTime> _lastUpdated = {};

  StateTree({DeviceSchema? schema}) {
    _schema = schema;
    _initSubscriptions();
    if (schema != null) {
      _initDefaults(schema);
    }
  }

  void _initSubscriptions() {
    _subscriptions = SubscriptionManager((prefix) => _schema?.keysByPrefix(prefix) ?? []);
  }

  void _initDefaults(DeviceSchema schema) {
    for (final field in schema.definitions) {
      _setByPath(field.key, field.defaultValue);
    }
  }

  /// Get a value by dotted key (e.g., "toolhead.position").
  T get<T>(String key) {
    dynamic current = _tree;
    for (final part in key.split('.')) {
      if (current is Map<String, dynamic>) {
        current = current[part];
      } else {
        return _defaultForPrefix(key);
      }
    }
    return current as T;
  }

  T _defaultForPrefix<T>(String key) {
    final field = _schema?.lookup(key);
    return (field?.defaultValue ?? 0) as T;
  }

  /// Batch update multiple fields at once.
  /// Each key is dotted, e.g., "extruder.temperature".
  void patch(Map<String, dynamic> updates) {
    for (final entry in updates.entries) {
      final key = entry.key;
      var value = entry.value;

      final field = _schema?.lookup(key);

      // Validate
      if (field != null) {
        final err = Validator.validate(field, value);
        if (err != null) continue; // Skip invalid values

        // Apply update strategy
        final current = _getByPath(key);
        if (current != null) {
          value = _applyStrategy(field, current, value);
        }
      }

      // Write to tree
      _setByPath(key, value);

      // Track freshness
      _lastUpdated[key] = DateTime.now();

      // Notify subscribers
      _subscriptions.notify(key, value);
    }
  }

  dynamic _applyStrategy(FieldDefinition field, dynamic current, dynamic incoming) {
    switch (field.strategy) {
      case UpdateStrategy.first:
        // Keep current only if it differs from the default (meaning it was explicitly set)
        if (current != field.defaultValue) {
          return current;
        }
        return incoming;
      case UpdateStrategy.max:
        if (current is num && incoming is num) {
          return current > incoming ? current : incoming;
        }
        return incoming;
      case UpdateStrategy.min:
        if (current is num && incoming is num) {
          return current < incoming ? current : incoming;
        }
        return incoming;
      case UpdateStrategy.merge:
        if (current is Map<String, dynamic> && incoming is Map<String, dynamic>) {
          return {...current, ...incoming};
        }
        return incoming;
      case UpdateStrategy.append:
        if (current is List && incoming is List) {
          return [...current, ...incoming];
        }
        return incoming;
      case UpdateStrategy.increment:
        if (current is num && incoming is num) {
          return current + incoming;
        }
        return incoming;
      case UpdateStrategy.replace:
      default:
        return incoming;
    }
  }

  dynamic _getByPath(String dottedKey) {
    final parts = dottedKey.split('.');
    dynamic current = _tree;
    for (int i = 0; i < parts.length; i++) {
      if (current is Map<String, dynamic>) {
        if (i == parts.length - 1) {
          return current[parts[i]];
        }
        current = current[parts[i]];
      } else {
        return null;
      }
    }
    return null;
  }

  void _setByPath(String dottedKey, dynamic value) {
    final parts = dottedKey.split('.');
    dynamic current = _tree;
    for (int i = 0; i < parts.length - 1; i++) {
      if (current[parts[i]] is! Map<String, dynamic>) {
        current[parts[i]] = <String, dynamic>{};
      }
      current = current[parts[i]];
    }
    current[parts.last] = value;
  }

  /// Export the entire state tree as a nested JSON object.
  Map<String, dynamic> export() {
    return _deepCopy(_tree);
  }

  Map<String, dynamic> _deepCopy(Map<String, dynamic> source) {
    final result = <String, dynamic>{};
    for (final entry in source.entries) {
      if (entry.value is Map<String, dynamic>) {
        result[entry.key] = _deepCopy(entry.value as Map<String, dynamic>);
      } else if (entry.value is List) {
        result[entry.key] = List.from(entry.value as List);
      } else {
        result[entry.key] = entry.value;
      }
    }
    return result;
  }

  /// Reset the state tree with a new schema, re-populating defaults.
  void reset(DeviceSchema schema) {
    _tree.clear();
    _lastUpdated.clear();
    _schema = schema;
    _subscriptions.dispose();
    _initSubscriptions();
    _initDefaults(schema);
  }

  /// Reset all values to their schema defaults using the stored schema.
  /// No-op if no schema has been set.
  void clearToDefaults() {
    final schema = _schema;
    if (schema == null) return;
    _tree.clear();
    _lastUpdated.clear();
    _subscriptions.dispose();
    _initSubscriptions();
    _initDefaults(schema);
  }

  /// True if [key] was last updated more than [maxAge] ago, or never updated.
  bool isStale(String key, {Duration maxAge = const Duration(seconds: 60)}) {
    final last = _lastUpdated[key];
    if (last == null) return true;
    return DateTime.now().difference(last) > maxAge;
  }

  /// Timestamp of the last update for [key], or null if never updated.
  DateTime? lastUpdatedAt(String key) => _lastUpdated[key];

  /// All tracked freshness timestamps, keyed by dotted path.
  Map<String, DateTime> get staleTimestamps => Map.unmodifiable(_lastUpdated);

  /// Subscribe to changes matching a prefix.
  /// "print_stats.*" → all print_stats fields
  /// "print_stats.state" → only that one field
  /// "*" → all fields
  Stream<StatePatch> watch(String prefix) {
    return _subscriptions.watch(prefix);
  }

  /// Subscribe to changes for specific keys.
  Stream<StatePatch> watchKeys(List<String> keys) {
    return _subscriptions.watchKeys(keys);
  }

  void dispose() {
    _subscriptions.dispose();
    _tree.clear();
    _lastUpdated.clear();
  }
}
