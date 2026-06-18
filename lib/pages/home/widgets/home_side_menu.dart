import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_zero_copy/pages/auth/login_dialog.dart';
import 'package:flutter_zero_copy/state/user_state.dart';

/// Menu items shown in the left sidebar.
const _menuItems = [
  (Icons.view_in_ar, '模型库'),
  (Icons.devices, '我的设备'),
  (Icons.folder_open, '近期文件'),
];

/// Left sidebar for the Home page.
///
/// Provides sub-navigation within the "首页" tab: 模型库, 我的设备, 近期文件.
/// Selection state is managed by the parent [HomePage] via [selectedIndex]
/// and [onMenuItemChanged].
class HomeSideMenu extends ConsumerWidget {
  final int selectedIndex;
  final ValueChanged<int> onMenuItemChanged;

  const HomeSideMenu({
    super.key,
    required this.selectedIndex,
    required this.onMenuItemChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final userState = ref.watch(userStateProvider);

    return Container(
      width: 262,
      color: theme.colorScheme.surfaceContainer,
      child: Column(
        children: [
          // User info section
          _buildUserSection(context, ref, theme, userState),

          const SizedBox(height: 16),

          // Menu items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: List.generate(_menuItems.length, (i) {
                final (icon, label) = _menuItems[i];
                return _buildMenuItem(
                  context,
                  theme: theme,
                  index: i,
                  icon: icon,
                  label: label,
                  isSelected: i == selectedIndex,
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // ── User section ──────────────────────────────────────────────────

  Widget _buildUserSection(
      BuildContext context, WidgetRef ref, ThemeData theme, UserState userState) {
    return InkWell(
      onTap: () {
        if (userState.isLoggedIn) {
          _showLogoutMenu(context, ref, theme);
        } else {
          _showLoginDialog(context);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
              child: Icon(
                userState.isLoggedIn ? Icons.person : Icons.person_outline,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
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
            Icon(Icons.arrow_drop_down, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  void _showLoginDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const LoginDialog(),
    );
  }

  void _showLogoutMenu(BuildContext context, WidgetRef ref, ThemeData theme) {
    showMenu(
      context: context,
      position: const RelativeRect.fromLTRB(0, 80, 0, 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      items: [
        PopupMenuItem(
          child: Row(
            children: [
              Icon(Icons.logout, size: 20, color: theme.colorScheme.error),
              const SizedBox(width: 12),
              Text('退出登录', style: TextStyle(color: theme.colorScheme.error)),
            ],
          ),
          onTap: () {
            Future.delayed(const Duration(milliseconds: 100), () {
              _confirmLogout(context, ref);
            });
          },
        ),
      ],
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
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
              ref.read(userStateProvider.notifier).logout();
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

  // ── Menu item ─────────────────────────────────────────────────────

  Widget _buildMenuItem(
    BuildContext context, {
    required ThemeData theme,
    required int index,
    required IconData icon,
    required String label,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () => onMenuItemChanged(index),
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
