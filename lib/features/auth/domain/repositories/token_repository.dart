import '../entities/token_entity.dart';

/// Token 仓库接口
///
/// 定义 Token 的存储和获取操作
abstract class TokenRepository {
  /// 保存 Token
  Future<void> saveToken(TokenEntity token);

  /// 获取 Token
  Future<TokenEntity?> getToken();

  /// 清除 Token
  Future<void> clearToken();

  /// 检查是否有 Token
  Future<bool> hasToken();

  /// 获取访问令牌
  Future<String?> getAccessToken();

  /// 获取刷新令牌
  Future<String?> getRefreshToken();
}
