import 'package:flutter/material.dart';

import 'package:flutter_zero_copy/widgets/top_navigation_bar.dart';

/// Main app tabs shown in the top navigation bar.
const _mainTabs = [
  TopNavTab(label: '首页', path: '/home', icon: Icons.home),
  TopNavTab(label: '预览', path: '/preview'),
  TopNavTab(label: '设备控制', path: '/device-control'),
  TopNavTab(label: '监控', path: '/device-monitor'),
];

/// Main application frame used as the [ShellRoute] builder.
///
/// Provides a persistent top navigation bar with 3 tabs (首页, 预览, 设备控制).
/// The content area renders the route-resolved [child].
class MainFramePage extends StatelessWidget {
  final Widget child;
  final String currentLocation;

  const MainFramePage({
    super.key,
    required this.child,
    required this.currentLocation,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainer,
      body: Column(
        children: [
          // Persistent top tab bar
          TopNavigationBar(
            currentLocation: currentLocation,
            tabs: _mainTabs,
          ),
          // Route-resolved content
          Expanded(child: child),
        ],
      ),
    );
  }
}
