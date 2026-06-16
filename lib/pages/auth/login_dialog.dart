import 'package:flutter/material.dart';
import 'package:flutter_zero_copy/state/user_state.dart';
import 'package:provider/provider.dart';

/// 登录对话框
///
/// 模态弹窗显示登录表单
class LoginDialog extends StatefulWidget {
  const LoginDialog({super.key});

  @override
  State<LoginDialog> createState() => _LoginDialogState();
}

class _LoginDialogState extends State<LoginDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  bool _agreementAccepted = false;
  bool _rememberMe = false;
  bool _isChina = true; // 默认中国区

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 480,
        height: size.height * 0.8,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            // 顶部关闭按钮
            _buildTopBar(context),

            // Logo区域
            _buildLogoSection(context),

            // Tab切换（验证码/密码登录）
            _buildTabBar(context),

            // 表单内容
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildCodeLoginForm(context),
                  _buildPasswordLoginForm(context),
                ],
              ),
            ),

            // 底部协议和登录按钮
            _buildBottomSection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoSection(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          // Logo
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.account_circle,
              size: 60,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '登录 Snapmaker',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: theme.colorScheme.primary,
        unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
        indicatorColor: theme.colorScheme.primary,
        tabs: const [
          Tab(text: '验证码登录'),
          Tab(text: '密码登录'),
        ],
      ),
    );
  }

  Widget _buildCodeLoginForm(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 手机号/邮箱输入
          TextField(
            controller: _isChina ? _phoneController : _emailController,
            decoration: InputDecoration(
              labelText: _isChina ? '手机号' : '邮箱',
              hintText: _isChina ? '请输入手机号' : '请输入邮箱',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // 验证码输入
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _codeController,
                  decoration: const InputDecoration(
                    labelText: '验证码',
                    hintText: '请输入验证码',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    debugPrint('发送验证码');
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('获取验证码'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordLoginForm(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 手机号/邮箱输入
          TextField(
            controller: _isChina ? _phoneController : _emailController,
            decoration: InputDecoration(
              labelText: _isChina ? '手机号' : '邮箱',
              hintText: _isChina ? '请输入手机号' : '请输入邮箱',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // 密码输入
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: '密码',
              hintText: '请输入密码',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),

          // 忘记密码
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                debugPrint('忘记密码');
              },
              child: const Text('忘记密码？'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSection(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          // 协议复选框
          Row(
            children: [
              Checkbox(
                value: _agreementAccepted,
                onChanged: (value) {
                  setState(() {
                    _agreementAccepted = value ?? false;
                  });
                },
              ),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: '我已阅读并同意 ',
                    style: theme.textTheme.bodySmall,
                    children: [
                      TextSpan(
                        text: '《用户协议》',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      const TextSpan(text: ' 和 '),
                      TextSpan(
                        text: '《隐私政策》',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 登录按钮
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _agreementAccepted
                  ? () {
                      _performLogin(context);
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
              ),
              child: const Text(
                '登录',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 创建账号
          TextButton(
            onPressed: () {
              debugPrint('创建账号');
            },
            child: const Text('没有账号？立即创建'),
          ),
        ],
      ),
    );
  /// 执行登录
  /// 执行登录
  void _performLogin(BuildContext context) {
    final userState = context.read<UserState>();

    // TODO: 实际的登录API调用
    // 这里模拟登录成功
    final account = _isChina
        ? _phoneController.text.trim()
        : _emailController.text.trim();

    debugPrint('执行登录: $account');

    // 模拟登录成功
    userState.login(username: account.isNotEmpty ? account : 'JG_CN1');

    // 关闭对话框
    Navigator.of(context).pop();

    // 显示成功提示
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('登录成功')),
    );
  }
