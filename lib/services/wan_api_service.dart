import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:lava_device_sdk/lava_device_sdk.dart';

/// Concrete [CloudApiClient] implementation backed by Dio HTTP.
///
/// Covers the full WAN connection API surface:
/// - OAuth2 login  →  `POST /oauth2/token`
/// - Bind device   →  `POST /user/device/bind`
/// - Get TLS cert  →  `GET  /user/device/getMqttCert`
/// - Check auth    →  `GET  /user/device/checkAuth`
/// - Root CA       →  `GET  /user/device/rootCA?provider=aws` (fallback)
class WanApiService implements CloudApiClient {
  final Dio _dio;
  final String _apiKey;
  final String _apiSecret;
  String? _token;

  WanApiService({
    required Dio dio,
    String apiKey = 'app-cn',
    String apiSecret = '123456',
  })  : _dio = dio,
        _apiKey = apiKey,
        _apiSecret = apiSecret;

  // ── Token management ──

  /// Whether the service holds a valid access token.
  bool get isLoggedIn => _token != null && _token!.isNotEmpty;

  /// Directly set an existing access token (skips login).
  void setToken(String token) {
    _token = token;
  }

  /// Returns the current access token, or throws if not logged in.
  String get token {
    if (_token == null || _token!.isEmpty) {
      throw Exception('Not logged in — call loginWithPhone() or setToken() first');
    }
    return _token!;
  }

  // ── OAuth2 Login ──

  /// Login with phone number + password via OAuth2 password grant.
  ///
  /// Password is hashed as: `sha256("$phone\$sm-nonce@$password")`.
  /// Client credentials are sent via Basic auth header.
  Future<String> loginWithPhone({
    required String phone,
    required String password,
    String clientId = 'app-cn',
  }) async {
    final hashed = _hashPassword(phone, password);

    final basic = base64Encode(utf8.encode('${clientId}:$_apiSecret'));

    final response = await _dio.post(
      '/oauth2/token',
      data: {
        'grant_type': 'password',
        'username': phone,
        'password': hashed,
      },
      options: Options(headers: {
        'Authorization': 'Basic $basic',
      }),
    );

    _token = response.data['access_token'] as String?;
    if (_token == null || _token!.isEmpty) {
      throw Exception('Login response missing access_token');
    }
    return _token!;
  }

  /// Shortcut: email + password login.
  Future<String> login({
    required String email,
    required String password,
    String clientId = 'app-cn',
  }) async {
    final basic = base64Encode(utf8.encode('${clientId}:$_apiSecret'));

    final response = await _dio.post(
      '/oauth2/token',
      data: {
        'grant_type': 'password',
        'username': email,
        'password': password,
        'email': email,
      },
      options: Options(headers: {
        'Authorization': 'Basic $basic',
      }),
    );

    _token = response.data['access_token'] as String?;
    if (_token == null || _token!.isEmpty) {
      throw Exception('Login response missing access_token');
    }
    return _token!;
  }

  // ── CloudApiClient implementation ──

  @override
  String get baseUrl => _dio.options.baseUrl;

  /// Step 1: Bind device to user account using the PIN/auth code.
  ///
  /// Returns the bind result containing deviceId, sn, name, etc.
  @override
  Future<Map<String, dynamic>> bindDevice(String authCode, String nickname) async {
    final response = await _dio.post(
      '/user/device/bind',
      data: {
        'authCode': authCode,
        'nickname': nickname,
      },
      options: Options(headers: _authHeader),
    );

    final data = response.data as Map<String, dynamic>;

    // Validate required fields
    if (data['sn'] == null) {
      throw Exception('Bind response missing sn');
    }

    return data;
  }

  /// Step 2: Get MQTT mTLS certificate for the bound device.
  @override
  Future<DeviceCertConfig> getDeviceCert() async {
    final response = await _dio.get(
      '/user/device/getMqttCert',
      options: Options(headers: _authHeader),
    );

    final data = response.data as Map<String, dynamic>;

    String? ca = data['ca'] as String?;

    // Fallback: fetch Root CA if not included in cert response
    if (ca == null || ca.isEmpty) {
      try {
        ca = await _getRootCA();
      } catch (_) {
        // Non-fatal — proceed without CA
      }
    }

    return DeviceCertConfig(
      endpoint: data['endpoint'] as String? ?? '',
      port: (data['port'] as num?)?.toInt() ?? 8883,
      clientId: data['clientId'] as String? ?? '',
      cert: data['cert'] as String? ?? '',
      key: data['key'] as String? ?? '',
      ca: ca,
    );
  }

  /// Step 3: Verify online authorization status (non-fatal).
  @override
  Future<void> checkAuthStatus(String deviceId, String certId, String sn) async {
    try {
      await _dio.get(
        '/user/device/checkAuth',
        queryParameters: {
          'deviceId': deviceId,
          'certId': certId,
          'sn': sn,
        },
        options: Options(headers: _authHeader),
      );
    } catch (_) {
      // Non-fatal — endpoint may be deprecated
    }
  }

  // ── Private helpers ──

  Map<String, String> get _authHeader => {
        'Authorization': 'Bearer $token',
      };

  /// Fetch AWS IoT Root CA as fallback.
  Future<String> _getRootCA() async {
    final response = await _dio.get(
      '/user/device/rootCA',
      queryParameters: {'provider': 'aws'},
      options: Options(headers: _authHeader),
    );
    return response.data as String? ?? '';
  }

  /// Password hashing: sha256("$phone\$sm-nonce@$password")
  static String _hashPassword(String phone, String password) {
    final input = '$phone\$sm-nonce@$password';
    return sha256.convert(utf8.encode(input)).toString();
  }
}
