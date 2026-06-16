/// Token 实体
///
/// 存储用户的访问令牌和刷新令牌信息
class TokenEntity {
  /// 访问令牌
  final String accessToken;

  /// 刷新令牌
  final String refreshToken;

  /// Token 类型（如 Bearer）
  final String tokenType;

  /// 过期时间（秒）
  final int expiresIn;

  /// 过期时间戳
  final DateTime expiresAt;

  /// 创建时间
  final DateTime createdAt;

  const TokenEntity({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.expiresIn,
    required this.expiresAt,
    required this.createdAt,
  });

  /// 从 Map 创建
  factory TokenEntity.fromMap(Map<String, dynamic> map) {
    final expiresIn = map['expires_in'] as int? ?? 3600;
    final createdAt = map['created_at'] != null
        ? DateTime.parse(map['created_at'] as String)
        : DateTime.now();
    final expiresAt = map['expires_at'] != null
        ? DateTime.parse(map['expires_at'] as String)
        : createdAt.add(Duration(seconds: expiresIn));

    return TokenEntity(
      accessToken: map['access_token'] as String? ?? '',
      refreshToken: map['refresh_token'] as String? ?? '',
      tokenType: map['token_type'] as String? ?? 'Bearer',
      expiresIn: expiresIn,
      expiresAt: expiresAt,
      createdAt: createdAt,
    );
  }

  /// 从 API 响应创建
  factory TokenEntity.fromApiResponse(
    Map<String, dynamic> response, {
    DateTime? createdAt,
  }) {
    final now = createdAt ?? DateTime.now();
    final expiresIn = response['expires_in'] as int? ?? 3600;

    return TokenEntity(
      accessToken: response['access_token'] as String? ?? '',
      refreshToken: response['refresh_token'] as String? ?? '',
      tokenType: response['token_type'] as String? ?? 'Bearer',
      expiresIn: expiresIn,
      expiresAt: now.add(Duration(seconds: expiresIn)),
      createdAt: now,
    );
  }

  /// 转换为 Map
  Map<String, dynamic> toMap() {
    return {
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'token_type': tokenType,
      'expires_in': expiresIn,
      'expires_at': expiresAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// 检查 Token 是否过期
  bool get isExpired {
    return DateTime.now().isAfter(expiresAt);
  }

  /// 检查 Token 是否即将过期（提前 1 小时）
  bool get isExpiringSoon {
    final threshold = expiresAt.subtract(const Duration(hours: 1));
    return DateTime.now().isAfter(threshold);
  }

  /// 获取剩余有效时间（秒）
  int get remainingSeconds {
    final now = DateTime.now();
    if (now.isAfter(expiresAt)) {
      return 0;
    }
    return expiresAt.difference(now).inSeconds;
  }

  /// 复制并更新
  TokenEntity copyWith({
    String? accessToken,
    String? refreshToken,
    String? tokenType,
    int? expiresIn,
    DateTime? expiresAt,
    DateTime? createdAt,
  }) {
    return TokenEntity(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      tokenType: tokenType ?? this.tokenType,
      expiresIn: expiresIn ?? this.expiresIn,
      expiresAt: expiresAt ?? this.expiresAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
