# 登录状态库 - 架构和逻辑图

> 完成时间：2026-06-16  
> 项目：flutter_zero_copy 认证系统

---

## 📐 系统架构图

### 分层架构

```
┌─────────────────────────────────────────────────────────────┐
│                        UI Layer (界面层)                      │
│                                                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │  LoginDialog │  │  HomePage    │  │  Profile     │      │
│  │  (登录对话框) │  │  (首页)      │  │  (个人中心)   │      │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘      │
│         │                  │                  │              │
│         └──────────────────┼──────────────────┘              │
│                            │                                 │
└────────────────────────────┼─────────────────────────────────┘
                             │ context.read/watch<UserState>()
┌────────────────────────────┼─────────────────────────────────┐
│                   State Layer (状态层)                        │
│                            │                                 │
│  ┌────────────────────────▼──────────────────────────┐      │
│  │            UserState (ChangeNotifier)             │      │
│  ├───────────────────────────────────────────────────┤      │
│  │  - _isLoggedIn: bool                              │      │
│  │  - _username: String?                             │      │
│  │  - _userId: String?                               │      │
│  │  - _token: TokenEntity?                           │      │
│  │  - _tokenService: TokenService                    │      │
│  ├───────────────────────────────────────────────────┤      │
│  │  + login(username, token)                         │      │
│  │  + logout()                                       │      │
│  │  + getAccessToken()                               │      │
│  │  + hasValidToken()                                │      │
│  │  + refreshToken(response)                         │      │
│  └────────────────────┬──────────────────────────────┘      │
│                       │                                      │
└───────────────────────┼──────────────────────────────────────┘
                        │
┌───────────────────────┼──────────────────────────────────────┐
│              Domain Layer (领域层 - 业务规则)                 │
│                       │                                      │
│  ┌────────────────────▼────────────────┐                    │
│  │     TokenService (接口)             │                    │
│  ├─────────────────────────────────────┤                    │
│  │  + saveToken(token)                 │                    │
│  │  + getToken()                       │                    │
│  │  + clearToken()                     │                    │
│  │  + hasValidToken()                  │                    │
│  │  + getAccessToken()                 │                    │
│  │  + isTokenExpired()                 │                    │
│  │  + refreshTokenFromResponse()       │                    │
│  └─────────────────┬───────────────────┘                    │
│                    │                                         │
│  ┌─────────────────▼───────────────────┐                    │
│  │     TokenEntity (实体)              │                    │
│  ├─────────────────────────────────────┤                    │
│  │  - accessToken: String              │                    │
│  │  - refreshToken: String             │                    │
│  │  - tokenType: String                │                    │
│  │  - expiresAt: DateTime              │                    │
│  │  - createdAt: DateTime              │                    │
│  ├─────────────────────────────────────┤                    │
│  │  + isExpired: bool                  │                    │
│  │  + isExpiringSoon: bool             │                    │
│  │  + remainingSeconds: int            │                    │
│  └─────────────────┬───────────────────┘                    │
│                    │                                         │
│  ┌─────────────────▼───────────────────┐                    │
│  │   TokenRepository (接口)            │                    │
│  ├─────────────────────────────────────┤                    │
│  │  + saveToken(token)                 │                    │
│  │  + getToken()                       │                    │
│  │  + clearToken()                     │                    │
│  │  + hasToken()                       │                    │
│  │  + getAccessToken()                 │                    │
│  └─────────────────┬───────────────────┘                    │
│                    │                                         │
└────────────────────┼─────────────────────────────────────────┘
                     │ implements
┌────────────────────┼─────────────────────────────────────────┐
│               Data Layer (数据层 - 实现)                      │
│                    │                                         │
│  ┌─────────────────▼───────────────────┐                    │
│  │  TokenServiceImpl (实现)            │                    │
│  ├─────────────────────────────────────┤                    │
│  │  - _repository: TokenRepository     │                    │
│  ├─────────────────────────────────────┤                    │
│  │  实现所有 TokenService 接口方法      │                    │
│  └─────────────────┬───────────────────┘                    │
│                    │                                         │
│  ┌─────────────────▼───────────────────┐                    │
│  │ TokenRepositoryImpl (实现)          │                    │
│  ├─────────────────────────────────────┤                    │
│  │  使用 SharedPreferences 存储         │                    │
│  │  - 键: "snapmaker_auth_token"       │                    │
│  │  - 格式: JSON                       │                    │
│  └─────────────────┬───────────────────┘                    │
│                    │                                         │
└────────────────────┼─────────────────────────────────────────┘
                     │
┌────────────────────▼─────────────────────────────────────────┐
│           Storage Layer (存储层)                              │
│                                                               │
│  ┌───────────────────────────────────────────────┐          │
│  │         SharedPreferences (持久化)             │          │
│  │         本地存储 (iOS/Android/macOS)           │          │
│  └───────────────────────────────────────────────┘          │
│                                                               │
└───────────────────────────────────────────────────────────────┘
```

---

## 🔄 登录流程时序图

```
User          LoginDialog       UserState       TokenService    TokenRepository    API
 │                 │                 │                │                │            │
 │  点击登录       │                 │                │                │            │
 ├────────────────>│                 │                │                │            │
 │                 │                 │                │                │            │
 │                 │  输入用户名密码  │                │                │            │
 │                 │  点击确认       │                │                │            │
 │                 │                 │                │                │            │
 │                 │  调用登录API    │                │                │            │
 │                 ├─────────────────────────────────────────────────────────────>│
 │                 │                 │                │                │            │
 │                 │                 │                │                │  返回Token │
 │                 │<────────────────────────────────────────────────────────────┤
 │                 │                 │                │                │            │
 │                 │ TokenEntity.fromApiResponse()   │                │            │
 │                 ├───────────────> │                │                │            │
 │                 │                 │                │                │            │
 │                 │  login(username, token)         │                │            │
 │                 ├───────────────> │                │                │            │
 │                 │                 │                │                │            │
 │                 │                 │  saveToken(token)              │            │
 │                 │                 ├───────────────>│                │            │
 │                 │                 │                │                │            │
 │                 │                 │                │ saveToken()   │            │
 │                 │                 │                ├───────────────>│            │
 │                 │                 │                │                │            │
 │                 │                 │                │ JSON.encode   │            │
 │                 │                 │                │ SharedPrefs   │            │
 │                 │                 │                │<──────────────┤            │
 │                 │                 │                │                │            │
 │                 │                 │  notifyListeners()             │            │
 │                 │                 ├───────────────>Provider         │            │
 │                 │                 │                │                │            │
 │  UI更新         │                 │                │                │            │
 │ (显示用户名)    │                 │                │                │            │
 │<────────────────┤                 │                │                │            │
 │                 │                 │                │                │            │
 │  关闭对话框     │                 │                │                │            │
 │<────────────────┤                 │                │                │            │
```

---

## 🔄 启动自动登录流程

```
App启动       UserState       TokenService    TokenRepository    SharedPreferences
 │                │                 │                │                   │
 │  初始化       │                 │                │                   │
 ├──────────────>│                 │                │                   │
 │                │                 │                │                   │
 │                │  构造函数       │                │                   │
 │                │  _loadTokenAndCheckLogin()      │                   │
 │                ├───────────────> │                │                   │
 │                │                 │                │                   │
 │                │                 │  hasValidToken()                  │
 │                │                 ├───────────────>│                   │
 │                │                 │                │                   │
 │                │                 │                │  getToken()      │
 │                │                 │                ├──────────────────>│
 │                │                 │                │                   │
 │                │                 │                │  读取JSON        │
 │                │                 │                │<─────────────────┤
 │                │                 │                │                   │
 │                │                 │  TokenEntity.fromMap()            │
 │                │                 │<──────────────┤                   │
 │                │                 │                │                   │
 │                │                 │  检查isExpired │                   │
 │                │                 │<──────────────┤                   │
 │                │                 │                │                   │
 │                │  如果Token有效  │                │                   │
 │                │  _isLoggedIn = true             │                   │
 │                │  notifyListeners()              │                   │
 │                ├───────────────> Provider         │                   │
 │                │                 │                │                   │
 │  UI更新        │                 │                │                   │
 │ (自动登录状态) │                 │                │                   │
 │<───────────────┤                 │                │                   │
```

---

## 🚪 退出登录流程

```
User        HomePage/Profile   UserState      TokenService    TokenRepository    SharedPrefs
 │               │                 │                │                │              │
 │  点击退出     │                 │                │                │              │
 ├──────────────>│                 │                │                │              │
 │               │                 │                │                │              │
 │               │  确认对话框     │                │                │              │
 │<──────────────┤                 │                │                │              │
 │               │                 │                │                │              │
 │  确认退出     │                 │                │                │              │
 ├──────────────>│                 │                │                │              │
 │               │                 │                │                │              │
 │               │  logout()       │                │                │              │
 │               ├───────────────> │                │                │              │
 │               │                 │                │                │              │
 │               │                 │  clearToken()  │                │              │
 │               │                 ├───────────────>│                │              │
 │               │                 │                │                │              │
 │               │                 │                │  clearToken() │              │
 │               │                 │                ├───────────────>│              │
 │               │                 │                │                │              │
 │               │                 │                │                │  remove()   │
 │               │                 │                │                ├─────────────>│
 │               │                 │                │                │              │
 │               │                 │  清除内存状态  │                │              │
 │               │                 │  _isLoggedIn = false           │              │
 │               │                 │  _username = null              │              │
 │               │                 │  _token = null                 │              │
 │               │                 │  notifyListeners()             │              │
 │               │                 ├───────────────> Provider        │              │
 │               │                 │                │                │              │
 │  UI更新       │                 │                │                │              │
 │ (显示未登录)  │                 │                │                │              │
 │<──────────────┤                 │                │                │              │
 │               │                 │                │                │              │
 │  显示提示     │                 │                │                │              │
 │  "已退出登录" │                 │                │                │              │
 │<──────────────┤                 │                │                │              │
```

---

## 🔑 Token过期检查流程

```
UserState      TokenService    TokenRepository    TokenEntity    
 │                 │                │                  │
 │  getAccessToken()                │                  │
 ├───────────────> │                │                  │
 │                 │                │                  │
 │                 │  getToken()    │                  │
 │                 ├───────────────>│                  │
 │                 │                │                  │
 │                 │  TokenEntity   │                  │
 │                 │<──────────────┤                  │
 │                 │                │                  │
 │                 │  检查 isExpired                   │
 │                 ├─────────────────────────────────>│
 │                 │                │                  │
 │                 │                │  DateTime.now() │
 │                 │                │  vs expiresAt   │
 │                 │                │                  │
 │                 │  if expired    │                  │
 │                 │  return null   │                  │
 │                 │<──────────────────────────────────┤
 │                 │                │                  │
 │                 │  if valid      │                  │
 │                 │  检查 isExpiringSoon              │
 │                 ├─────────────────────────────────>│
 │                 │                │                  │
 │                 │  如果即将過期(1小時內)            │
 │                 │  觸發刷新提醒   │                  │
 │                 │                │                  │
 │                 │  return accessToken              │
 │  accessToken    │<──────────────┤                  │
 │<────────────────┤                │                  │
 │                 │                │                  │
 │  用於API請求    │                │                  │
```

---

## 🔄 Token自动刷新流程（架构已完成）

```
UserState      TokenService    API          TokenRepository
 │                 │            │                │
 │  getAccessToken()            │                │
 ├───────────────> │            │                │
 │                 │            │                │
 │                 │  检测Token即将过期            │
 │                 │  isExpiringSoon = true       │
 │                 │            │                │
 │                 │  获取refreshToken           │
 │                 ├───────────>Repository       │
 │                 │            │                │
 │                 │  调用刷新API │                │
 │                 ├────────────>│                │
 │                 │            │                │
 │                 │  返回新Token │                │
 │                 │<───────────┤                │
 │                 │            │                │
 │                 │  refreshTokenFromResponse() │
 │                 │  TokenEntity.fromApiResponse()
 │                 │            │                │
 │                 │  saveToken(newToken)        │
 │                 ├────────────────────────────>│
 │                 │            │                │
 │  refreshToken(response)     │                │
 │<────────────────┤            │                │
 │                 │            │                │
 │  notifyListeners()          │                │
 │  (UI无感知刷新)  │            │                │
```

---

## 📊 数据流图

```
┌─────────────────────────────────────────────────────────┐
│                     数据流向                             │
└─────────────────────────────────────────────────────────┘

用户输入 (用户名/密码)
    │
    ▼
LoginDialog (UI层)
    │
    ▼
API调用 (网络层)
    │
    ▼
TokenEntity.fromApiResponse() (实体创建)
    │
    ▼
UserState.login() (状态层)
    │
    ├──> TokenService.saveToken() (服务层)
    │        │
    │        ▼
    │    TokenRepository.saveToken() (仓库层)
    │        │
    │        ▼
    │    SharedPreferences (持久化)
    │
    ├──> 更新内存状态
    │    - _isLoggedIn = true
    │    - _username = "xxx"
    │    - _token = TokenEntity
    │
    └──> notifyListeners() (Provider通知)
             │
             ▼
         UI自动更新
         - 显示用户名
         - 显示登录状态
```

---

## 🎯 状态管理流程

```
┌─────────────────────────────────────────────────────────┐
│              Provider 状态管理                           │
└─────────────────────────────────────────────────────────┘

main.dart
    │
    └──> ChangeNotifierProvider(
             create: (_) => UserState(),
             child: MaterialApp(...)
         )
              │
              ├──> context.watch<UserState>()
              │    - 监听状态变化
              │    - UI自动重建
              │
              ├──> context.read<UserState>()
              │    - 调用方法
              │    - 不监听变化
              │
              └──> UserState.notifyListeners()
                   - 通知所有监听者
                   - 触发UI重建
```

---

## 🔒 安全机制

```
┌─────────────────────────────────────────────────────────┐
│                  安全检查流程                            │
└─────────────────────────────────────────────────────────┘

每次获取Token时:
    │
    ├──> 1. 检查Token是否存在
    │       if (token == null) return null
    │
    ├──> 2. 检查Token是否过期
    │       if (DateTime.now() > expiresAt) return null
    │
    ├──> 3. 检查Token是否即将过期
    │       if (expiresAt - now < 1hour) 触发刷新提醒
    │
    └──> 4. 返回有效Token
            return accessToken

退出登录时:
    │
    ├──> 1. 清除内存状态
    │       _isLoggedIn = false
    │       _username = null
    │       _token = null
    │
    ├──> 2. 清除持久化Token
    │       SharedPreferences.remove(key)
    │
    └──> 3. 通知UI更新
            notifyListeners()

启动时:
    │
    ├──> 1. 读取持久化Token
    │       SharedPreferences.getString(key)
    │
    ├──> 2. 解析并验证Token
    │       TokenEntity.fromMap(json)
    │       检查isExpired
    │
    └──> 3. 自动恢复登录状态
            if (valid) _isLoggedIn = true
```

---

## 📁 文件组织结构

```
lib/
├── features/auth/                    # 认证功能模块
│   ├── domain/                       # 领域层（业务规则）
│   │   ├── entities/
│   │   │   └── token_entity.dart     # Token实体
│   │   ├── repositories/
│   │   │   └── token_repository.dart # Token仓库接口
│   │   └── services/
│   │       └── token_service.dart    # Token服务接口
│   └── data/                         # 数据层（实现）
│       ├── repositories/
│       │   └── token_repository_impl.dart  # 仓库实现
│       └── services/
│           └── token_service_impl.dart     # 服务实现
│
├── state/
│   └── user_state.dart               # 用户状态管理（集成Token）
│
└── pages/auth/
    └── login_dialog.dart             # 登录对话框（UI）
```

---

## 🔄 依赖关系图

```
┌─────────────────────────────────────────────────────────┐
│                  依赖关系                                │
└─────────────────────────────────────────────────────────┘

LoginDialog (UI)
    │
    └──> UserState (状态管理)
            │
            └──> TokenService (服务接口)
                    │
                    ├──> TokenEntity (实体)
                    │
                    └──> TokenRepository (仓库接口)
                            │
                            └──> TokenRepositoryImpl (实现)
                                    │
                                    └──> SharedPreferences (存储)

依赖原则:
- UI层 → 状态层
- 状态层 → 领域层
- 领域层 ← 数据层实现
- 数据层 → 存储层
```

---

## 🎯 关键API

### UserState API
```dart
// 登录
Future<void> login({
  required String username,
  String? userId,
  TokenEntity? token,
})

// 退出
Future<void> logout()

// 获取Token
Future<String?> getAccessToken()

// 检查状态
Future<bool> hasValidToken()

// 刷新Token
Future<void> refreshToken(Map<String, dynamic> response)
```

### TokenService API
```dart
Future<void> saveToken(TokenEntity token)
Future<TokenEntity?> getToken()
Future<void> clearToken()
Future<bool> hasValidToken()
Future<String?> getAccessToken()
Future<bool> isTokenExpired()
Future<bool> isTokenExpiringSoon()
Future<void> refreshTokenFromResponse(Map<String, dynamic> response)
```

---

**创建时间**: 2026-06-16  
**状态**: ✅ 完成  
**文档类型**: 架构和逻辑图
