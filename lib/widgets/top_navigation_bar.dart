import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// A tab item in the top navigation bar.
class TopNavTab {
  final String label;
  final String path;
  final IconData? icon;

  const TopNavTab({required this.label, required this.path, this.icon});
}

/// Top navigation bar with route-aware tab selection.
///
/// Each tab maps to a route path. The selected tab is determined by matching
/// [currentLocation] against tab paths. Tapping a tab calls `context.go(path)`.
class TopNavigationBar extends StatelessWidget {
  final String currentLocation;
  final List<TopNavTab> tabs;
  final List<Widget>? actions;

  const TopNavigationBar({
    super.key,
    required this.currentLocation,
    required this.tabs,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedIndex = _resolveSelectedIndex();

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.dividerColor, width: 1),
        ),
      ),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++)
            _buildTab(context, theme, i, tabs[i], i == selectedIndex),

          const Spacer(),

          if (actions != null) ...actions!,
          const SizedBox(width: 16),
        ],
      ),
    );
  }

  int _resolveSelectedIndex() {
    for (var i = 0; i < tabs.length; i++) {
      if (currentLocation.startsWith(tabs[i].path)) return i;
    }
    return 0;
  }

  Widget _buildTab(
      BuildContext context, ThemeData theme, int index, TopNavTab tab, bool isSelected) {
    final Widget content = tab.icon != null
        ? Icon(
            tab.icon,
            size: 20,
            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
          )
        : Text(
            tab.label,
            style: theme.textTheme.titleSmall?.copyWith(
              color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          );

    return InkWell(
      onTap: () {
        if (!isSelected) context.go(tab.path);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? theme.colorScheme.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: content,
      ),
    );
  }
}
