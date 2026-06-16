import 'package:flutter/material.dart';
import 'package:flutter_zero_copy/widgets/top_navigation_bar.dart';

/// 主框架页面
///
/// 统一的页面框架，包含：
/// - 顶部导航栏
/// - 左侧边栏（可选）
/// - 主内容区
class MainFramePage extends StatefulWidget {
  final int initialTabIndex;
  final Widget? sidebar;
  final List<Widget> pages;
  final List<List<Widget>>? pageActions;

  const MainFramePage({
    super.key,
    this.initialTabIndex = 0,
    this.sidebar,
    required this.pages,
    this.pageActions,
  });

  @override
  State<MainFramePage> createState() => _MainFramePageState();
}

class _MainFramePageState extends State<MainFramePage> {
  late int _currentTabIndex;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _currentTabIndex = widget.initialTabIndex;
    _pageController = PageController(initialPage: _currentTabIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabChanged(int index) {
    setState(() {
      _currentTabIndex = index;
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
      backgroundColor: theme.colorScheme.surface,
      body: Column(
        children: [
          // 顶部导航栏
          TopNavigationBar(
            currentIndex: _currentTabIndex,
            onTabChanged: _onTabChanged,
            actions: widget.pageActions != null &&
                    _currentTabIndex < widget.pageActions!.length
                ? widget.pageActions![_currentTabIndex]
                : null,
          ),

          // 主内容区
          Expanded(
            child: Row(
              children: [
                // 左侧边栏（如果提供）
                if (widget.sidebar != null) widget.sidebar!,

                // 页面内容
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentTabIndex = index;
                      });
                    },
                    children: widget.pages,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
