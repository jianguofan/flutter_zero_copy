# 认证状态架构文档

> 父文档：[状态管理架构](../STATE_MANAGEMENT.md)  
> 流程图：[认证状态流程图](./AUTH_STATE_MERMAID.md)  
> 版本：1.0.0

---

## 📐 认证状态概览

认证状态是**全局状态**的核心组件之一，负责管理用户的登录状态和Token。

### 架构图

详细的架构图和流程图请参考：→ [认证状态流程图（Mermaid）](./AUTH_STATE_MERMAID.md)

---

## 🎯 核心组件

### 1. UserState（不可变状态）

```dart
class UserState {
  final bool isLoggedIn;
  final String? username;
  final String? userId;
  final TokenEntity? token;
  
  const UserState({
    this.isLoggedIn = false,
    this.username,
    this.userId,
    this.token,
  });
  
  UserState copyWith({...}) {
    // 不可变更新
  }
}
```

### 2. UserStateNotifier（状态管理器）

```dart
class UserStateNotifier extends StateNotifier<UserState> {
  final TokenService _tokenService;
  
  UserStateNotifier(this._tokenService) : super(const UserState()) {
    _init();
  }
  
  Future<void> login({required String username, TokenEntity? token}) async {
    // 登录逻辑
    state = UserState(isLoggedIn: true, username: username, token: token);
  }
  
  Future<void> logout() async {
    // 退出逻辑
    state = const UserState();
  }
}
```

### 3. Providers

```dart
// Token服务Provider
final tokenServiceProvider = Provider<TokenService>((ref) {
  return TokenServiceImpl(TokenRepositoryImpl());
});

// 用户状态Provider
final userStateProvider = StateNotifierProvider<UserStateNotifier, UserState>((ref) {
  final tokenService = ref.watch(tokenServiceProvider);
  return UserStateNotifier(tokenService);
});
```

---

## 🔄 核心流程

### 登录流程
详细的登录流程时序图：→ [AUTH_STATE_MERMAID.md#登录流程](./AUTH_STATE_MERMAID.md#登录流程时序图)

### 启动自动登录
详细的自动登录流程：→ [AUTH_STATE_MERMAID.md#启动自动登录](./AUTH_STATE_MERMAID.md#启动自动登录流程)

### 退出登录
详细的退出流程：→ [AUTH_STATE_MERMAID.md#退出登录](./AUTH_STATE_MERMAID.md#退出登录流程)

---

## 💾 Token管理

### TokenEntity（Token实体）

完整的Token实体定义和说明：→ [AUTH_ARCHITECTURE.md](../../AUTH_ARCHITECTURE.md#TokenEntity)

### TokenService（Token服务）

Token服务接口和实现：→ [AUTH_ARCHITECTURE.md](../../AUTH_ARCHITECTURE.md#TokenService)

### Token持久化

Token持久化策略：
- 使用SharedPreferences存储
- JSON序列化
- 自动过期检查

---

## 📊 使用示例

### 在UI中使用

```dart
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userState = ref.watch(userStateProvider);
    
    if (userState.isLoggedIn) {
      return Text('欢迎，${userState.username}');
    } else {
      return ElevatedButton(
        onPressed: () {
          ref.read(userStateProvider.notifier).login(username: 'xxx');
        },
        child: const Text('登录'),
      );
    }
  }
}
```

### 获取Token

```dart
// 获取访问令牌
final userState = ref.read(userStateProvider);
final token = userState.token?.accessToken;

// 或者通过Notifier获取
final notifier = ref.read(userStateProvider.notifier);
final accessToken = await notifier.getAccessToken();
```

---

## 🔒 安全机制

### Token过期检查

详细的Token过期检查流程：→ [AUTH_STATE_MERMAID.md#Token过期检查](./AUTH_STATE_MERMAID.md#Token过期检查流程)

### Token自动刷新

详细的Token刷新流程：→ [AUTH_STATE_MERMAID.md#Token自动刷新](./AUTH_STATE_MERMAID.md#Token自动刷新流程)

---

## 📝 相关文档

### 详细文档
- ✅ [认证状态流程图](./AUTH_STATE_MERMAID.md) - 12个Mermaid图表
- ✅ [认证系统架构](../../AUTH_ARCHITECTURE.md) - 完整的实现说明
- ✅ [状态管理设计](../../STATE_MANAGEMENT_DESIGN.md) - 设计原则

### 父级文档
- ← [状态管理架构](../STATE_MANAGEMENT.md)
- ← [整体架构](../ARCHITECTURE.md)

---

**创建时间**：2026-06-16  
**父文档**：[STATE_MANAGEMENT.md](../STATE_MANAGEMENT.md)  
**维护者**：开发团队
