import '../../domain/entities/token_entity.dart';
import '../../domain/repositories/token_repository.dart';
import '../../domain/services/token_service.dart';

/// Token 服务实现
class TokenServiceImpl implements TokenService {
  final TokenRepository _repository;

  TokenServiceImpl(this._repository);

  @override
  Future<void> saveToken(TokenEntity token) {
    return _repository.saveToken(token);
  }

  @override
  Future<TokenEntity?> getToken() {
    return _repository.getToken();
  }

  @override
  Future<void> clearToken() {
    return _repository.clearToken();
  }

  @override
  Future<bool> hasValidToken() async {
    final token = await _repository.getToken();
    return token != null && !token.isExpired && token.accessToken.isNotEmpty;
  }

  @override
  Future<String?> getAccessToken() async {
    final token = await _repository.getToken();
    if (token == null || token.isExpired) {
      return null;
    }
    return token.accessToken;
  }

  @override
  Future<String?> getRefreshToken() {
    return _repository.getRefreshToken();
  }

  @override
  Future<bool> isTokenExpired() async {
    final token = await _repository.getToken();
    return token == null || token.isExpired;
  }

  @override
  Future<bool> isTokenExpiringSoon() async {
    final token = await _repository.getToken();
    return token == null || token.isExpiringSoon;
  }

  @override
  Future<void> refreshTokenFromResponse(Map<String, dynamic> response) async {
    final token = TokenEntity.fromApiResponse(response);
    await saveToken(token);
  }
}
