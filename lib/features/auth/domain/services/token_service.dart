import '../entities/token_entity.dart';

/// Token 服务接口
///
/// 提供 Token 管理功能
abstract class TokenService {
  /// 保存 Token
  Future<void> saveToken(TokenEntity token);

  /// 获取 Token
  Future<TokenEntity?> getToken();

  /// 清除 Token
  Future<void> clearToken();

  /// 检查是否有有效的 Token
  Future<bool> hasValidToken();

  /// 获取访问令牌（如果有效）
  Future<String?> getAccessToken();

  /// 获取刷新令牌
  Future<String?> getRefreshToken();

  /// 检查 Token 是否过期
  Future<bool> isTokenExpired();

  /// 检查 Token 是否即将过期
  Future<bool> isTokenExpiringSoon();

  /// 刷新 Token（从 API 响应更新）
  Future<void> refreshTokenFromResponse(Map<String, dynamic> response);
}
