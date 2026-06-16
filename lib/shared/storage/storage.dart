/// Key-Value storage abstraction for the Lava App.
///
/// Provides a unified interface over multiple backends:
/// - [HiveStorage] — fast, typed, supports complex objects
/// - [PrefsStorage] — backed by SharedPreferences, simple types only
library;

import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Interface ──

/// Abstract KV storage contract.
///
/// All read methods return typed values or null when missing.
abstract class IStorage {
  Future<void> init();

  Future<void> setString(String key, String value);
  String? getString(String key);

  Future<void> setInt(String key, int value);
  int? getInt(String key);

  Future<void> setDouble(String key, double value);
  double? getDouble(String key);

  Future<void> setBool(String key, bool value);
  bool? getBool(String key);

  Future<void> setStringList(String key, List<String> value);
  List<String>? getStringList(String key);

  Future<void> remove(String key);
  Future<void> clear();
}

// ── Hive Implementation ──

/// Fast, typed storage backed by [Hive].
///
/// Suitable for structured data, device info, cached API responses.
class HiveStorage implements IStorage {
  late Box _box;
  final String boxName;

  HiveStorage({this.boxName = 'lava_storage'});

  @override
  Future<void> init() async {
    _box = await Hive.openBox(boxName);
  }

  @override
  Future<void> setString(String key, String value) => _box.put(key, value);

  @override
  String? getString(String key) => _box.get(key);

  @override
  Future<void> setInt(String key, int value) => _box.put(key, value);

  @override
  int? getInt(String key) => _box.get(key);

  @override
  Future<void> setDouble(String key, double value) => _box.put(key, value);

  @override
  double? getDouble(String key) => _box.get(key);

  @override
  Future<void> setBool(String key, bool value) => _box.put(key, value);

  @override
  bool? getBool(String key) => _box.get(key);

  @override
  Future<void> setStringList(String key, List<String> value) =>
      _box.put(key, value);

  @override
  List<String>? getStringList(String key) {
    final raw = _box.get(key);
    if (raw is List) return raw.cast<String>();
    return null;
  }

  /// Store an arbitrary object as JSON.
  Future<void> setJson(String key, Object value) =>
      _box.put(key, jsonEncode(value));

  /// Read and decode a JSON-stored value.
  T? getJson<T>(String key, T Function(Map<String, dynamic>) fromJson) {
    final raw = _box.get(key);
    if (raw is String) {
      return fromJson(jsonDecode(raw) as Map<String, dynamic>);
    }
    return null;
  }

  @override
  Future<void> remove(String key) => _box.delete(key);

  @override
  Future<void> clear() => _box.clear();
}

// ── SharedPreferences Implementation ──

/// Lightweight storage backed by [SharedPreferences].
///
/// Suitable for user preferences, settings flags, access tokens.
class PrefsStorage implements IStorage {
  late SharedPreferences _prefs;

  @override
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  @override
  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);

  @override
  String? getString(String key) => _prefs.getString(key);

  @override
  Future<void> setInt(String key, int value) => _prefs.setInt(key, value);

  @override
  int? getInt(String key) => _prefs.getInt(key);

  @override
  Future<void> setDouble(String key, double value) =>
      _prefs.setDouble(key, value);

  @override
  double? getDouble(String key) => _prefs.getDouble(key);

  @override
  Future<void> setBool(String key, bool value) => _prefs.setBool(key, value);

  @override
  bool? getBool(String key) => _prefs.getBool(key);

  @override
  Future<void> setStringList(String key, List<String> value) =>
      _prefs.setStringList(key, value);

  @override
  List<String>? getStringList(String key) => _prefs.getStringList(key);

  @override
  Future<void> remove(String key) => _prefs.remove(key);

  @override
  Future<void> clear() => _prefs.clear();

  /// Expose the underlying [SharedPreferences] for advanced use.
  SharedPreferences get prefs => _prefs;
}
