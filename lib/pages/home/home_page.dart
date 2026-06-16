import 'package:flutter/material.dart';
import 'package:flutter_zero_copy/pages/home/widgets/home_side_menu.dart';
import 'package:flutter_zero_copy/pages/projects/projects_page.dart';
import 'package:flutter_zero_copy/pages/devices/my_devices_page.dart';

/// 首页
///
/// 包含左侧边栏和主内容区（默认显示模型库/项目网格）
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
    setState(() {
      _selectedMenuIndex = index;
    });
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
          // 左侧边栏
          HomeSideMenu(
            onMenuItemChanged: _onMenuItemChanged,
          ),

          // 分割线
          VerticalDivider(
            width: 1,
            thickness: 1,
            color: theme.dividerColor,
          ),

          // 主内容区
          Expanded(
            child: Column(
              children: [
                // 顶部操作按钮区
                _buildTopActionBar(context),

                // 内容区
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _selectedMenuIndex = index;
                      });
                    },
                    children: [
                      // 模型库页面（显示项目网格）
                      const ProjectsPage(),

                      // 我的设备页面
                      _buildPlaceholderPage(context, '我的设备'),

                      // 近期文件页面
                      _buildPlaceholderPage(context, '近期文件'),
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

  /// 顶部操作栏
  Widget _buildTopActionBar(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 57,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // 打开项目按钮
          OutlinedButton(
            onPressed: () {
              debugPrint('打开项目');
            },
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: theme.colorScheme.primary),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: Text(
              '打开项目',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.primary,
              ),
            ),
          ),

          const SizedBox(width: 16),

          // 创建项目按钮
          ElevatedButton.icon(
            onPressed: () {
              debugPrint('创建项目');
            },
            icon: const Icon(Icons.add, size: 16),
            label: const Text(
              '创建项目',
              style: TextStyle(fontSize: 12),
            ),
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

  /// 占位页面
  Widget _buildPlaceholderPage(BuildContext context, String title) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inbox,
            size: 64,
            color: Theme.of(context)
                .colorScheme
                .onSurfaceVariant
                .withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}
