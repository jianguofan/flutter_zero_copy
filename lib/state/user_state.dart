import 'package:flutter/material.dart';
import 'package:flutter_zero_copy/features/auth/domain/entities/token_entity.dart';
import 'package:flutter_zero_copy/features/auth/domain/services/token_service.dart';
import 'package:flutter_zero_copy/features/auth/data/services/token_service_impl.dart';
import 'package:flutter_zero_copy/features/auth/data/repositories/token_repository_impl.dart';

/// 用户状态管理
///
/// 集成Token管理和用户信息管理
class UserState extends ChangeNotifier {
  bool _isLoggedIn = false;
  String? _username;
  String? _avatar;
  String? _userId;
  TokenEntity? _token;

  late final TokenService _tokenService;

  UserState() {
    _tokenService = TokenServiceImpl(TokenRepositoryImpl());
    _loadTokenAndCheckLogin();
  }

  bool get isLoggedIn => _isLoggedIn;
  String? get username => _username;
  String? get avatar => _avatar;
  String? get userId => _userId;
  TokenEntity? get token => _token;

  /// 加载Token并检查登录状态
  Future<void> _loadTokenAndCheckLogin() async {
    final hasValid = await _tokenService.hasValidToken();
    if (hasValid) {
      _token = await _tokenService.getToken();
      _isLoggedIn = true;
      notifyListeners();
    }
  }

  /// 登录
  Future<void> login({
    required String username,
    String? avatar,
    String? userId,
    TokenEntity? token,
  }) async {
    _isLoggedIn = true;
    _username = username;
    _avatar = avatar;
    _userId = userId;
    _token = token;

    // 保存Token
    if (token != null) {
      await _tokenService.saveToken(token);
    }

    notifyListeners();
  }

  /// 退出登录
  Future<void> logout() async {
    _isLoggedIn = false;
    _username = null;
    _avatar = null;
    _userId = null;
    _token = null;

    // 清除Token
    await _tokenService.clearToken();

    notifyListeners();
  }

  /// 获取访问令牌
  Future<String?> getAccessToken() async {
    return await _tokenService.getAccessToken();
  }

  /// 检查Token是否有效
  Future<bool> hasValidToken() async {
    return await _tokenService.hasValidToken();
  }

  /// 刷新Token
  Future<void> refreshToken(Map<String, dynamic> response) async {
    await _tokenService.refreshTokenFromResponse(response);
    _token = await _tokenService.getToken();
    notifyListeners();
  }
}
