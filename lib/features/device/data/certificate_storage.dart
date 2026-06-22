import 'dart:convert';
import 'package:lava_device_sdk/lava_device_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists LAN-authorized [MqttCredentials] (ca + cert + key) to local storage.
///
/// Keyed by device SN. On subsequent connections, load the cached credentials
/// and call [DeviceHub.connectWithCredentials] to skip the authorization dance.
class CertificateStorage {
  static const _keyPrefix = 'device_cert_';

  /// Save credentials for a device (keyed by [MqttCredentials.sn]).
  static Future<void> save(MqttCredentials creds) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(creds.toJson());
    await prefs.setString(_key(creds.sn), json);
  }

  /// Load cached credentials for a device, or null if not cached.
  static Future<MqttCredentials?> load(String sn) async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_key(sn));
    if (json == null) return null;
    try {
      return MqttCredentials.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } catch (_) {
      // Corrupted data — clean up
      await prefs.remove(_key(sn));
      return null;
    }
  }

  /// Delete cached credentials for a device.
  static Future<void> delete(String sn) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(sn));
  }

  /// Whether cached credentials exist for a device.
  static Future<bool> exists(String sn) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_key(sn));
  }

  static String _key(String sn) => '$_keyPrefix$sn';
}
