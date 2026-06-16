import 'package:flutter_zero_copy/features/auth/domain/entities/token_entity.dart';
import 'package:flutter_zero_copy/features/auth/domain/services/token_service.dart';
import 'package:flutter_zero_copy/features/auth/data/services/token_service_impl.dart';
import 'package:flutter_zero_copy/features/auth/data/repositories/token_repository_impl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 用户状态类
///
/// 使用 Riverpod 管理用户登录状态和Token
class UserState {
  final bool isLoggedIn;
  final String? username;
  final String? avatar;
  final String? userId;
  final TokenEntity? token;

  const UserState({
    this.isLoggedIn = false,
    this.username,
    this.avatar,
    this.userId,
    this.token,
  });

  UserState copyWith({
    bool? isLoggedIn,
    String? username,
    String? avatar,
    String? userId,
    TokenEntity? token,
  }) {
    return UserState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      username: username ?? this.username,
      avatar: avatar ?? this.avatar,
      userId: userId ?? this.userId,
      token: token ?? this.token,
    );
  }
}

/// TokenService Provider
final tokenServiceProvider = Provider<TokenService>((ref) {
  return TokenServiceImpl(TokenRepositoryImpl());
});

/// UserState StateNotifier
class UserStateNotifier extends StateNotifier<UserState> {
  final TokenService _tokenService;

  UserStateNotifier(this._tokenService) : super(const UserState()) {
    _loadTokenAndCheckLogin();
  }

  /// 加载Token并检查登录状态
  Future<void> _loadTokenAndCheckLogin() async {
    final hasValid = await _tokenService.hasValidToken();
    if (hasValid) {
      final token = await _tokenService.getToken();
      state = state.copyWith(
        isLoggedIn: true,
        token: token,
      );
    }
  }

  /// 登录
  Future<void> login({
    required String username,
    String? avatar,
    String? userId,
    TokenEntity? token,
  }) async {
    // 保存Token
    if (token != null) {
      await _tokenService.saveToken(token);
    }

    // 更新状态
    state = UserState(
      isLoggedIn: true,
      username: username,
      avatar: avatar,
      userId: userId,
      token: token,
    );
  }

  /// 退出登录
  Future<void> logout() async {
    // 清除Token
    await _tokenService.clearToken();

    // 更新状态
    state = const UserState(
      isLoggedIn: false,
    );
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
    final token = await _tokenService.getToken();
    state = state.copyWith(token: token);
  }
}

/// UserState Provider
final userStateProvider = StateNotifierProvider<UserStateNotifier, UserState>((ref) {
  final tokenService = ref.watch(tokenServiceProvider);
  return UserStateNotifier(tokenService);
});
