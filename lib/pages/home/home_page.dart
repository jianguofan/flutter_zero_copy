import 'package:flutter/material.dart';

import 'package:flutter_zero_copy/pages/home/widgets/home_side_menu.dart';
import 'package:flutter_zero_copy/pages/projects/projects_page.dart';
import 'package:flutter_zero_copy/pages/devices/my_devices_page.dart';
import 'package:flutter_zero_copy/pages/recent/recent_files_page.dart';

/// 首页 — visible under the "首页" top tab.
///
/// Contains a left sidebar (模型库 / 我的设备 / 近期文件) and a content area
/// that switches between sub-pages via an internal [PageView].
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedMenuIndex = 0;
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onMenuItemChanged(int index) {
    setState(() => _selectedMenuIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainer,
      body: Row(
        children: [
          // Left sidebar
          HomeSideMenu(
            selectedIndex: _selectedMenuIndex,
            onMenuItemChanged: _onMenuItemChanged,
          ),

          // Divider
          VerticalDivider(
            width: 1,
            thickness: 1,
            color: theme.dividerColor,
          ),

          // Content area
          Expanded(
            child: Column(
              children: [
                // Top action bar
                _buildTopActionBar(context),
                // Sub-pages
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() => _selectedMenuIndex = index);
                    },
                    children: const [
                      ProjectsPage(),
                      MyDevicesPage(),
                      RecentFilesPage(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopActionBar(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 57,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.dividerColor, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: () => debugPrint('打开项目'),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: theme.colorScheme.primary),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: Text('打开项目',
                style: TextStyle(fontSize: 12, color: theme.colorScheme.primary)),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: () => debugPrint('创建项目'),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('创建项目', style: TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }
}
