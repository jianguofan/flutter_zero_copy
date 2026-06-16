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
}
