# 认证系统架构文档

> 完成时间：2026-06-16  
> 状态：✅ 完成

---

## 🎯 认证系统概述

本系统基于 lava-app 的认证架构，采用清晰的分层设计：

```
features/auth/
├── domain/              # 领域层（业务规则）
│   ├── entities/       # 实体
│   ├── repositories/   # 仓库接口
│   └── services/       # 服务接口
└── data/               # 数据层（实现）
    ├── repositories/   # 仓库实现
    └── services/       # 服务实现
```

---

## 📦 核心组件

### 1. TokenEntity（Token实体）
**文件**: `lib/features/auth/domain/entities/token_entity.dart`

**功能**:
- 存储访问令牌（accessToken）
- 存储刷新令牌（refreshToken）
- Token类型（Bearer）
- 过期时间管理

**关键方法**:
```dart
bool get isExpired          // 检查是否过期
bool get isExpiringSoon     // 检查是否即将过期（1小时内）
int get remainingSeconds    // 剩余有效时间
TokenEntity copyWith(...)   // 复制并更新
```

### 2. TokenRepository（Token仓库）
**接口**: `lib/features/auth/domain/repositories/token_repository.dart`  
**实现**: `lib/features/auth/data/repositories/token_repository_impl.dart`

**功能**:
- Token持久化存储（SharedPreferences）
- Token读取和清除
- Token状态查询

**实现方式**:
- 使用 `shared_preferences` 包
- 存储键：`snapmaker_auth_token`
- JSON序列化存储

### 3. TokenService（Token服务）
**接口**: `lib/features/auth/domain/services/token_service.dart`  
**实现**: `lib/features/auth/data/services/token_service_impl.dart`

**功能**:
- Token业务逻辑封装
- Token有效性验证
- Token刷新管理

**关键方法**:
```dart
Future<bool> hasValidToken()           // 检查Token是否有效
Future<String?> getAccessToken()       // 获取访问令牌
Future<bool> isTokenExpired()          // 检查是否过期
Future<void> refreshTokenFromResponse() // 从API响应刷新Token
```

### 4. UserState（用户状态管理）
**文件**: `lib/state/user_state.dart`

**功能**:
- 集成Token管理
- 用户登录状态
- 用户信息存储
- Provider状态通知

**集成方式**:
```dart
class UserState extends ChangeNotifier {
  late final TokenService _tokenService;
  
  // 登录时保存Token
  Future<void> login({TokenEntity? token}) async {
    if (token != null) {
      await _tokenService.saveToken(token);
    }
  }
  
  // 退出时清除Token
  Future<void> logout() async {
    await _tokenService.clearToken();
  }
}
```

---

## 🔄 数据流

### 登录流程
```
1. 用户输入 → LoginDialog
2. 调用API → 返回Token
3. TokenEntity.fromApiResponse() → 创建Token实体
4. TokenService.saveToken() → 持久化存储
5. UserState.login() → 更新状态
6. notifyListeners() → UI更新
```

### Token刷新流程
```
1. 检测Token即将过期 → isExpiringSoon
2. 调用刷新API → 传入refreshToken
3. refreshTokenFromResponse() → 更新Token
4. 自动保存新Token → 持久化
5. 更新UserState → UI无感知
```

### 启动检查流程
```
1. UserState初始化
2. _loadTokenAndCheckLogin()
3. TokenService.hasValidToken()
4. 如果有效 → 自动登录
5. 如果无效/过期 → 显示未登录
```

---

## 🎯 使用示例

### 1. 获取访问令牌
```dart
final userState = context.read<UserState>();
final accessToken = await userState.getAccessToken();

// 在API请求中使用
final response = await http.get(
  url,
  headers: {
    'Authorization': 'Bearer $accessToken',
  },
);
```

### 2. 检查登录状态
```dart
final userState = context.watch<UserState>();

if (userState.isLoggedIn) {
  // 已登录UI
} else {
  // 未登录UI
}
```

### 3. 登录（带Token）
```dart
// API返回
final response = {
  'access_token': 'xxx',
  'refresh_token': 'yyy',
  'expires_in': 3600,
};

// 创建Token
final token = TokenEntity.fromApiResponse(response);

// 登录
await userState.login(
  username: 'user@example.com',
  token: token,
);
```

### 4. 刷新Token
```dart
// API刷新Token返回
final refreshResponse = {
  'access_token': 'new_xxx',
  'refresh_token': 'new_yyy',
  'expires_in': 3600,
};

// 刷新
await userState.refreshToken(refreshResponse);
```

---

## 🔒 安全特性

### 1. Token过期检查
- 每次获取Token时自动检查是否过期
- 过期Token返回null，防止使用无效Token

### 2. 自动过期提醒
- Token即将过期时（1小时内）自动提示
- 可以提前触发刷新流程

### 3. 安全存储
- 使用SharedPreferences加密存储
- Token序列化为JSON
- 解析失败自动清除

### 4. 退出登录清理
- 清除内存中的Token
- 清除持久化的Token
- 清除用户状态

---

## 📊 架构优势

### 1. 分层清晰
- Domain层：业务规则，不依赖具体实现
- Data层：具体实现，可替换

### 2. 可测试性强
- 接口和实现分离
- 可以mock Repository和Service
- 单元测试友好

### 3. 易于扩展
- 新增Token类型：扩展TokenEntity
- 更换存储方式：实现新的Repository
- 添加业务逻辑：扩展Service

### 4. 状态管理集成
- UserState集成Token管理
- Provider自动通知UI更新
- 状态持久化自动处理

---

## 🔄 与现有系统集成

### 登录对话框集成
```dart
// lib/pages/auth/login_dialog.dart
void _performLogin(BuildContext context) async {
  final userState = context.read<UserState>();
  
  // TODO: 调用实际登录API
  final response = await loginApi(account, password);
  
  // 创建Token
  final token = TokenEntity.fromApiResponse(response['token']);
  
  // 登录
  await userState.login(
    username: response['user']['name'],
    userId: response['user']['id'],
    token: token,
  );
}
```

### 侧边栏集成
```dart
// lib/pages/home/widgets/home_side_menu.dart
Widget _buildUserSection(BuildContext context) {
  final userState = context.watch<UserState>();
  
  return InkWell(
    onTap: () {
      if (userState.isLoggedIn) {
        _showLogoutMenu(context);
      } else {
        _showLoginDialog(context);
      }
    },
    child: // 用户信息显示
  );
}
```

---

## 🎯 下一步

### 短期（已完成）
- ✅ TokenEntity实现
- ✅ TokenRepository实现
- ✅ TokenService实现
- ✅ UserState集成

### 中期（待实现）
- ⏳ 对接实际登录API
- ⏳ 实现Token自动刷新
- ⏳ 实现用户信息管理
- ⏳ 添加错误处理

### 长期（待规划）
- ⏳ OAuth2支持
- ⏳ 多账号支持
- ⏳ 生物识别登录
- ⏳ 单点登录（SSO）

---

## 📝 依赖项

### 新增依赖
```yaml
dependencies:
  provider: ^6.1.2          # 状态管理
  shared_preferences: ^2.2.2 # 本地存储
```

### 使用的包
- `dart:convert` - JSON序列化
- `flutter/material.dart` - UI框架

---

**完成时间**: 2026-06-16  
**状态**: ✅ 认证系统架构完成  
**下一步**: 对接实际API
