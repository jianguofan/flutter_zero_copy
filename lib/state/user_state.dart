import 'package:flutter/material.dart';

/// 用户状态管理
///
/// 简单的用户登录状态管理
class UserState extends ChangeNotifier {
  bool _isLoggedIn = false;
  String? _username;
  String? _avatar;

  bool get isLoggedIn => _isLoggedIn;
  String? get username => _username;
  String? get avatar => _avatar;

  /// 登录
  void login({required String username, String? avatar}) {
    _isLoggedIn = true;
    _username = username;
    _avatar = avatar;
    notifyListeners();
  }

  /// 退出登录
  void logout() {
    _isLoggedIn = false;
    _username = null;
    _avatar = null;
    notifyListeners();
  }
}
