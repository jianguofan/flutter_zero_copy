import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/token_entity.dart';
import '../../domain/repositories/token_repository.dart';

/// Token 仓库实现
///
/// 使用 SharedPreferences 持久化存储 Token
class TokenRepositoryImpl implements TokenRepository {
  static const String _tokenKey = 'snapmaker_auth_token';

  @override
  Future<void> saveToken(TokenEntity token) async {
    final prefs = await SharedPreferences.getInstance();
    final tokenMap = token.toMap();
    await prefs.setString(_tokenKey, jsonEncode(tokenMap));
  }

  @override
  Future<TokenEntity?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final tokenJson = prefs.getString(_tokenKey);
    if (tokenJson == null) {
      return null;
    }

    try {
      final tokenMap = jsonDecode(tokenJson) as Map<String, dynamic>;
      return TokenEntity.fromMap(tokenMap);
    } catch (e) {
      // 如果解析失败，清除无效的 Token
      await clearToken();
      return null;
    }
  }

  @override
  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  @override
  Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.accessToken.isNotEmpty;
  }

  @override
  Future<String?> getAccessToken() async {
    final token = await getToken();
    if (token == null || token.isExpired) {
      return null;
    }
    return token.accessToken;
  }

  @override
  Future<String?> getRefreshToken() async {
    final token = await getToken();
    return token?.refreshToken;
  }
}
