import 'package:flutter/material.dart';
import 'package:flutter_zero_copy/pages/auth/login_dialog.dart';
import 'package:flutter_zero_copy/state/user_state.dart';
import 'package:provider/provider.dart';

/// 首页侧边栏组件
///
/// 包含用户信息、模型库、我的设备、近期文件等菜单
class HomeSideMenu extends StatefulWidget {
  final Function(int)? onMenuItemChanged;

  const HomeSideMenu({
    super.key,
    this.onMenuItemChanged,
  });

  @override
  State<HomeSideMenu> createState() => _HomeSideMenuState();
}

class _HomeSideMenuState extends State<HomeSideMenu> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 262,
      color: theme.colorScheme.surfaceContainer,
      child: Column(
        children: [
          // 用户信息区域
          _buildUserSection(context),

          const SizedBox(height: 16),

          // 菜单项
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildMenuItem(
                  context,
                  index: 0,
                  icon: Icons.view_in_ar,
                  label: '模型库',
                ),
                _buildMenuItem(
                  context,
                  index: 1,
                  icon: Icons.devices,
                  label: '我的设备',
                ),
                _buildMenuItem(
                  context,
                  index: 2,
                  icon: Icons.folder_open,
                  label: '近期文件',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 用户信息区域
  Widget _buildUserSection(BuildContext context) {
    final theme = Theme.of(context);
    final userState = context.watch<UserState>();

    return InkWell(
      onTap: () {
        if (userState.isLoggedIn) {
          // 已登录，显示退出登录菜单
          _showLogoutMenu(context);
        } else {
          // 未登录，显示登录对话框
          _showLoginDialog(context);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            // 用户头像
            CircleAvatar(
              radius: 20,
              backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
              child: Icon(
                userState.isLoggedIn ? Icons.person : Icons.person_outline,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),

            // 用户名
            Expanded(
              child: Text(
                userState.isLoggedIn
                    ? (userState.username ?? 'JG_CN1')
                    : '未登录',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: userState.isLoggedIn
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),

            // 下拉箭头
            Icon(
              Icons.arrow_drop_down,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  /// 显示登录对话框
  void _showLoginDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const LoginDialog(),
    );
  }

  /// 显示退出登录菜单
  void _showLogoutMenu(BuildContext context) {
    final theme = Theme.of(context);
    final userState = context.read<UserState>();

    showMenu(
      context: context,
      position: const RelativeRect.fromLTRB(0, 80, 0, 0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      items: [
        PopupMenuItem(
          child: Row(
            children: [
              Icon(
                Icons.logout,
                size: 20,
                color: theme.colorScheme.error,
              ),
              const SizedBox(width: 12),
              Text(
                '退出登录',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
          ),
          onTap: () {
            // 延迟执行，避免菜单关闭动画冲突
            Future.delayed(const Duration(milliseconds: 100), () {
              _confirmLogout(context, userState);
            });
          },
        ),
      ],
    );
  }

  /// 确认退出登录
  void _confirmLogout(BuildContext context, UserState userState) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认退出'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              userState.logout();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已退出登录')),
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('退出'),
          ),
        ],
      ),
    );
  }

  /// 菜单项
  Widget _buildMenuItem(
    BuildContext context, {
    required int index,
    required IconData icon,
    required String label,
  }) {
    final theme = Theme.of(context);
    final isSelected = _selectedIndex == index;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
        widget.onMenuItemChanged?.call(index);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
