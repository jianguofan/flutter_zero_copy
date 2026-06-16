import 'package:flutter/material.dart';
import 'package:flutter_zero_copy/pages/auth/login_dialog.dart';

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

    return InkWell(
      onTap: () {
        // 显示登录对话框
        showDialog(
          context: context,
          builder: (context) => const LoginDialog(),
        );
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
                Icons.person,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),

            // 用户名
            Expanded(
              child: Text(
                'JG_CN1',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
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
