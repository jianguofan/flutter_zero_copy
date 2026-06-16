# 登录状态库 - 架构和逻辑图 (Mermaid版)

> 完成时间：2026-06-16  
> 项目：flutter_zero_copy 认证系统  
> 图表格式：Mermaid

---

## 📐 系统架构图

### 分层架构 (Mermaid)

```mermaid
graph TB
    subgraph UI["UI Layer (界面层)"]
        LoginDialog["LoginDialog<br/>登录对话框"]
        HomePage["HomePage<br/>首页"]
        Profile["Profile<br/>个人中心"]
    end
    
    subgraph State["State Layer (状态层)"]
        UserState["UserState<br/>(ChangeNotifier)<br/>━━━━━━━━━━━━━━━<br/>- _isLoggedIn: bool<br/>- _username: String?<br/>- _userId: String?<br/>- _token: TokenEntity?<br/>- _tokenService: TokenService<br/>━━━━━━━━━━━━━━━<br/>+ login()<br/>+ logout()<br/>+ getAccessToken()<br/>+ hasValidToken()"]
    end
    
    subgraph Domain["Domain Layer (领域层)"]
        TokenService["TokenService<br/>(接口)<br/>━━━━━━━━━━━━━━━<br/>+ saveToken()<br/>+ getToken()<br/>+ clearToken()<br/>+ hasValidToken()<br/>+ getAccessToken()<br/>+ isTokenExpired()"]
        
        TokenEntity["TokenEntity<br/>(实体)<br/>━━━━━━━━━━━━━━━<br/>- accessToken<br/>- refreshToken<br/>- tokenType<br/>- expiresAt<br/>━━━━━━━━━━━━━━━<br/>+ isExpired<br/>+ isExpiringSoon<br/>+ remainingSeconds"]
        
        TokenRepo["TokenRepository<br/>(接口)<br/>━━━━━━━━━━━━━━━<br/>+ saveToken()<br/>+ getToken()<br/>+ clearToken()<br/>+ hasToken()"]
    end
    
    subgraph Data["Data Layer (数据层)"]
        TokenServiceImpl["TokenServiceImpl<br/>(实现)<br/>━━━━━━━━━━━━━━━<br/>- _repository"]
        
        TokenRepoImpl["TokenRepositoryImpl<br/>(实现)<br/>━━━━━━━━━━━━━━━<br/>使用 SharedPreferences<br/>键: snapmaker_auth_token<br/>格式: JSON"]
    end
    
    subgraph Storage["Storage Layer (存储层)"]
        SharedPrefs["SharedPreferences<br/>持久化存储"]
    end
    
    LoginDialog -->|context.read| UserState
    HomePage -->|context.watch| UserState
    Profile -->|context.read| UserState
    
    UserState -->|使用| TokenService
    
    TokenService -->|包含| TokenEntity
    TokenService -->|依赖| TokenRepo
    
    TokenServiceImpl -.实现.-> TokenService
    TokenRepoImpl -.实现.-> TokenRepo
    
    TokenServiceImpl -->|使用| TokenRepoImpl
    TokenRepoImpl -->|读写| SharedPrefs
    
    style UI fill:#e3f2fd
    style State fill:#fff3e0
    style Domain fill:#f3e5f5
    style Data fill:#e8f5e9
    style Storage fill:#fce4ec
```

---

## 🔄 登录流程时序图

```mermaid
sequenceDiagram
    participant User as 用户
    participant Dialog as LoginDialog
    participant State as UserState
    participant Service as TokenService
    participant Repo as TokenRepository
    participant API as 登录API
    participant Storage as SharedPreferences
    
    User->>Dialog: 1. 点击登录
    User->>Dialog: 2. 输入用户名密码
    User->>Dialog: 3. 点击确认
    
    Dialog->>API: 4. 调用登录API
    API-->>Dialog: 5. 返回Token和用户信息
    
    Dialog->>Dialog: 6. TokenEntity.fromApiResponse()
    
    Dialog->>State: 7. login(username, token)
    
    State->>Service: 8. saveToken(token)
    Service->>Repo: 9. saveToken(token)
    Repo->>Storage: 10. JSON.encode + save
    Storage-->>Repo: 11. 保存成功
    Repo-->>Service: 12. 完成
    Service-->>State: 13. 完成
    
    State->>State: 14. 更新内存状态<br/>_isLoggedIn = true<br/>_username = xxx<br/>_token = TokenEntity
    
    State->>State: 15. notifyListeners()
    State-->>Dialog: 16. Provider通知
    
    Dialog->>User: 17. UI更新<br/>显示用户名
    Dialog->>User: 18. 关闭对话框
```

---

## 🚀 启动自动登录流程

```mermaid
sequenceDiagram
    participant App as 应用启动
    participant State as UserState
    participant Service as TokenService
    participant Repo as TokenRepository
    participant Storage as SharedPreferences
    participant UI as UI界面
    
    App->>State: 1. 初始化 UserState
    State->>State: 2. 构造函数调用<br/>_loadTokenAndCheckLogin()
    
    State->>Service: 3. hasValidToken()
    Service->>Repo: 4. getToken()
    Repo->>Storage: 5. getString(key)
    Storage-->>Repo: 6. 返回JSON字符串
    
    Repo->>Repo: 7. JSON.decode<br/>TokenEntity.fromMap()
    
    Repo->>Repo: 8. 检查 token.isExpired
    
    alt Token有效
        Repo-->>Service: 9. 返回 TokenEntity
        Service-->>State: 10. true (有效)
        
        State->>State: 11. _isLoggedIn = true<br/>_token = TokenEntity
        State->>State: 12. notifyListeners()
        State-->>UI: 13. Provider通知
        UI->>UI: 14. UI更新为登录状态
    else Token无效或过期
        Repo-->>Service: 返回 null
        Service-->>State: false (无效)
        State-->>UI: 显示未登录状态
    end
```

---

## 🚪 退出登录流程

```mermaid
sequenceDiagram
    participant User as 用户
    participant Page as 页面
    participant State as UserState
    participant Service as TokenService
    participant Repo as TokenRepository
    participant Storage as SharedPreferences
    
    User->>Page: 1. 点击退出登录
    Page->>Page: 2. 显示确认对话框
    User->>Page: 3. 确认退出
    
    Page->>State: 4. logout()
    
    State->>Service: 5. clearToken()
    Service->>Repo: 6. clearToken()
    Repo->>Storage: 7. remove(key)
    Storage-->>Repo: 8. 删除成功
    Repo-->>Service: 9. 完成
    Service-->>State: 10. 完成
    
    State->>State: 11. 清除内存状态<br/>_isLoggedIn = false<br/>_username = null<br/>_userId = null<br/>_token = null
    
    State->>State: 12. notifyListeners()
    State-->>Page: 13. Provider通知
    
    Page->>User: 14. UI更新为未登录
    Page->>User: 15. 显示提示"已退出登录"
```

---

## 🔑 Token过期检查流程

```mermaid
flowchart TD
    Start([调用 getAccessToken]) --> GetToken[从 Repository<br/>获取 Token]
    
    GetToken --> CheckNull{Token<br/>是否存在?}
    
    CheckNull -->|否| ReturnNull1[返回 null]
    CheckNull -->|是| CheckExpired{Token<br/>是否过期?}
    
    CheckExpired -->|是| ReturnNull2[返回 null]
    CheckExpired -->|否| CheckExpiring{Token<br/>即将过期?<br/>剩余<1小时}
    
    CheckExpiring -->|是| TriggerRefresh[触发刷新提醒]
    CheckExpiring -->|否| ReturnToken[返回<br/>accessToken]
    
    TriggerRefresh --> ReturnToken
    
    ReturnNull1 --> End([结束])
    ReturnNull2 --> End
    ReturnToken --> End
    
    style Start fill:#e3f2fd
    style End fill:#e3f2fd
    style CheckNull fill:#fff3e0
    style CheckExpired fill:#fff3e0
    style CheckExpiring fill:#fff3e0
    style ReturnToken fill:#c8e6c9
    style ReturnNull1 fill:#ffcdd2
    style ReturnNull2 fill:#ffcdd2
    style TriggerRefresh fill:#ffe0b2
```

---

## 🔄 Token自动刷新流程

```mermaid
sequenceDiagram
    participant State as UserState
    participant Service as TokenService
    participant Repo as TokenRepository
    participant API as 刷新API
    
    Note over State,API: Token即将过期场景
    
    State->>Service: 1. getAccessToken()
    Service->>Service: 2. 检测 isExpiringSoon = true
    
    Service->>Repo: 3. getRefreshToken()
    Repo-->>Service: 4. 返回 refreshToken
    
    Service->>API: 5. 调用刷新API<br/>传入 refreshToken
    API-->>Service: 6. 返回新的Token
    
    Service->>Service: 7. TokenEntity.fromApiResponse()
    Service->>Repo: 8. saveToken(newToken)
    Repo-->>Service: 9. 保存成功
    
    Service-->>State: 10. 返回新的 accessToken
    State->>State: 11. 更新内存中的 _token
    State->>State: 12. notifyListeners()
    
    Note over State: UI无感知自动刷新完成
```

---

## 📊 数据流图

```mermaid
flowchart LR
    subgraph Input["输入层"]
        UserInput[用户输入<br/>用户名/密码]
    end
    
    subgraph UI["UI层"]
        Dialog[LoginDialog]
    end
    
    subgraph Network["网络层"]
        API[API调用]
    end
    
    subgraph Entity["实体层"]
        CreateEntity[TokenEntity<br/>.fromApiResponse]
    end
    
    subgraph State["状态层"]
        StateLogin[UserState<br/>.login]
    end
    
    subgraph Service["服务层"]
        SaveToken[TokenService<br/>.saveToken]
    end
    
    subgraph Repo["仓库层"]
        RepoSave[TokenRepository<br/>.saveToken]
    end
    
    subgraph Storage["存储层"]
        SharedPrefs[SharedPreferences<br/>持久化]
    end
    
    subgraph Memory["内存层"]
        UpdateState[更新状态<br/>_isLoggedIn<br/>_username<br/>_token]
    end
    
    subgraph Output["输出层"]
        UIUpdate[UI自动更新]
    end
    
    UserInput --> Dialog
    Dialog --> API
    API --> CreateEntity
    CreateEntity --> StateLogin
    StateLogin --> SaveToken
    SaveToken --> RepoSave
    RepoSave --> SharedPrefs
    StateLogin --> UpdateState
    UpdateState --> UIUpdate
    
    style Input fill:#e3f2fd
    style UI fill:#e3f2fd
    style Network fill:#fff3e0
    style Entity fill:#f3e5f5
    style State fill:#fff9c4
    style Service fill:#c8e6c9
    style Repo fill:#b2dfdb
    style Storage fill:#b2ebf2
    style Memory fill:#ffe0b2
    style Output fill:#c5e1a5
```

---

## 🎯 Provider状态管理流程

```mermaid
graph TD
    Main[main.dart] --> Provider[ChangeNotifierProvider]
    
    Provider --> Create[create: UserState]
    Provider --> App[MaterialApp]
    
    App --> Pages[应用页面]
    
    Pages --> Watch[context.watch<br/>UserState]
    Pages --> Read[context.read<br/>UserState]
    
    Watch --> Listen[监听状态变化<br/>自动重建UI]
    Read --> Call[调用方法<br/>不监听变化]
    
    Call --> Method[login/logout<br/>等方法]
    
    Method --> Notify[notifyListeners]
    
    Notify --> Watch
    
    style Main fill:#e3f2fd
    style Provider fill:#fff3e0
    style Watch fill:#c8e6c9
    style Read fill:#ffccbc
    style Notify fill:#f48fb1
    style Listen fill:#ce93d8
```

---

## 🔒 安全检查流程

```mermaid
flowchart TD
    subgraph GetToken["获取Token流程"]
        Start1([getAccessToken]) --> Check1{Token<br/>存在?}
        Check1 -->|否| Fail1[❌ 返回 null]
        Check1 -->|是| Check2{Token<br/>过期?}
        Check2 -->|是| Fail2[❌ 返回 null]
        Check2 -->|否| Check3{即将过期?<br/>1小时内}
        Check3 -->|是| Alert[⚠️ 触发刷新]
        Check3 -->|否| Success1[✅ 返回Token]
        Alert --> Success1
    end
    
    subgraph Logout["退出登录流程"]
        Start2([logout]) --> Clear1[清除内存状态<br/>_isLoggedIn = false<br/>_username = null<br/>_token = null]
        Clear1 --> Clear2[清除持久化<br/>SharedPreferences<br/>.remove]
        Clear2 --> Notify[通知UI更新<br/>notifyListeners]
        Notify --> Success2[✅ 完成]
    end
    
    subgraph Startup["启动检查流程"]
        Start3([应用启动]) --> Load[读取持久化Token<br/>SharedPreferences]
        Load --> Parse[解析JSON<br/>TokenEntity.fromMap]
        Parse --> Validate{Token<br/>有效?}
        Validate -->|是| Auto[✅ 自动登录<br/>_isLoggedIn = true]
        Validate -->|否| Manual[⚪ 显示未登录]
    end
    
    style Start1 fill:#e3f2fd
    style Start2 fill:#e3f2fd
    style Start3 fill:#e3f2fd
    style Fail1 fill:#ffcdd2
    style Fail2 fill:#ffcdd2
    style Success1 fill:#c8e6c9
    style Success2 fill:#c8e6c9
    style Alert fill:#fff9c4
    style Auto fill:#c8e6c9
    style Manual fill:#e0e0e0
```

---

## 🏗️ 类图和依赖关系

```mermaid
classDiagram
    class LoginDialog {
        +BuildContext context
        +_performLogin()
        +build()
    }
    
    class UserState {
        -bool _isLoggedIn
        -String? _username
        -String? _userId
        -TokenEntity? _token
        -TokenService _tokenService
        +login(username, token)
        +logout()
        +getAccessToken()
        +hasValidToken()
        +refreshToken(response)
        +notifyListeners()
    }
    
    class TokenService {
        <<interface>>
        +saveToken(token)*
        +getToken()*
        +clearToken()*
        +hasValidToken()*
        +getAccessToken()*
        +isTokenExpired()*
        +isTokenExpiringSoon()*
        +refreshTokenFromResponse()*
    }
    
    class TokenServiceImpl {
        -TokenRepository _repository
        +saveToken(token)
        +getToken()
        +clearToken()
        +hasValidToken()
        +getAccessToken()
        +isTokenExpired()
        +isTokenExpiringSoon()
        +refreshTokenFromResponse()
    }
    
    class TokenEntity {
        -String accessToken
        -String refreshToken
        -String tokenType
        -int expiresIn
        -DateTime expiresAt
        -DateTime createdAt
        +bool isExpired
        +bool isExpiringSoon
        +int remainingSeconds
        +fromMap(map)
        +fromApiResponse(response)
        +toMap()
        +copyWith()
    }
    
    class TokenRepository {
        <<interface>>
        +saveToken(token)*
        +getToken()*
        +clearToken()*
        +hasToken()*
        +getAccessToken()*
        +getRefreshToken()*
    }
    
    class TokenRepositoryImpl {
        -String _tokenKey
        +saveToken(token)
        +getToken()
        +clearToken()
        +hasToken()
        +getAccessToken()
        +getRefreshToken()
    }
    
    class SharedPreferences {
        +setString(key, value)
        +getString(key)
        +remove(key)
    }
    
    LoginDialog --> UserState : uses
    UserState --> TokenService : uses
    TokenService --> TokenEntity : uses
    TokenService --> TokenRepository : depends on
    TokenServiceImpl ..|> TokenService : implements
    TokenRepositoryImpl ..|> TokenRepository : implements
    TokenServiceImpl --> TokenRepositoryImpl : uses
    TokenRepositoryImpl --> SharedPreferences : uses
    TokenRepositoryImpl --> TokenEntity : creates
    
    style LoginDialog fill:#e3f2fd
    style UserState fill:#fff3e0
    style TokenService fill:#f3e5f5
    style TokenServiceImpl fill:#e8f5e9
    style TokenEntity fill:#fff9c4
    style TokenRepository fill:#f3e5f5
    style TokenRepositoryImpl fill:#e8f5e9
    style SharedPreferences fill:#cfd8dc
```

---

## 📁 文件组织结构

```mermaid
graph LR
    Root[lib/] --> Features[features/]
    Root --> State[state/]
    Root --> Pages[pages/]
    
    Features --> Auth[auth/]
    
    Auth --> Domain[domain/]
    Auth --> Data[data/]
    
    Domain --> Entities[entities/]
    Domain --> Repositories[repositories/]
    Domain --> Services[services/]
    
    Entities --> TokenEntity[token_entity.dart]
    Repositories --> TokenRepo[token_repository.dart]
    Services --> TokenService[token_service.dart]
    
    Data --> DataRepos[repositories/]
    Data --> DataServices[services/]
    
    DataRepos --> TokenRepoImpl[token_repository_impl.dart]
    DataServices --> TokenServiceImpl[token_service_impl.dart]
    
    State --> UserState[user_state.dart]
    
    Pages --> AuthPages[auth/]
    AuthPages --> LoginDialog[login_dialog.dart]
    
    style Root fill:#e3f2fd
    style Features fill:#fff3e0
    style Domain fill:#f3e5f5
    style Data fill:#e8f5e9
    style State fill:#fff9c4
    style Pages fill:#ffccbc
```

---

## 🔄 完整的用户交互流程

```mermaid
stateDiagram-v2
    [*] --> 未登录
    
    未登录 --> 登录中 : 用户点击登录
    登录中 --> 已登录 : 登录成功<br/>保存Token
    登录中 --> 未登录 : 登录失败
    
    已登录 --> Token检查 : 每次API请求
    Token检查 --> 已登录 : Token有效
    Token检查 --> Token刷新中 : Token即将过期
    Token检查 --> 未登录 : Token已过期
    
    Token刷新中 --> 已登录 : 刷新成功
    Token刷新中 --> 未登录 : 刷新失败
    
    已登录 --> 退出中 : 用户点击退出
    退出中 --> 未登录 : 清除Token和状态
    
    未登录 --> [*]
    
    note right of 未登录
        - 显示"未登录"
        - 点击头像弹出登录框
    end note
    
    note right of 已登录
        - 显示用户名
        - Token持久化存储
        - 自动检查过期
    end note
    
    note right of Token刷新中
        - 使用refreshToken
        - UI无感知刷新
        - 自动保存新Token
    end note
```

---

## 📋 关键API总结

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

// Getter
bool get isLoggedIn
String? get username
String? get userId
TokenEntity? get token
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
**文档类型**: Mermaid 架构和逻辑图  
**图表数量**: 12个
