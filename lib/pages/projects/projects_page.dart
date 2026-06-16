import 'package:flutter/material.dart';
import 'package:flutter_zero_copy/pages/projects/widgets/project_card.dart';
import 'package:flutter_zero_copy/pages/projects/widgets/project_grid.dart';
import 'package:flutter_zero_copy/pages/projects/widgets/project_header.dart';

/// 项目页面
///
/// 展示3D打印项目库，包含官方推荐项目的网格布局
class ProjectsPage extends StatefulWidget {
  const ProjectsPage({super.key});

  @override
  State<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends State<ProjectsPage> {
  List<ProjectCardData> _projects = [];
  bool _isLoading = false;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  /// 加载项目列表
  Future<void> _loadProjects() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // TODO: 从实际数据源加载项目
      // 这里使用模拟数据
      await Future.delayed(const Duration(seconds: 1));

      final mockProjects = List.generate(
        12,
        (index) => ProjectCardData(
          id: 'project_$index',
          title: 'IKEA SKÅDIS 料盒和胶带盒 $index',
          imageUrl: null, // TODO: 添加实际图片URL
          authorName: index % 3 == 0
              ? 'MOSS 3D'
              : index % 3 == 1
                  ? '3D Paint Lab'
                  : 'Inplace',
        ),
      );

      if (mounted) {
        setState(() {
          _projects = mockProjects;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Failed to load projects: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 刷新项目列表
  Future<void> _refreshProjects() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      await Future.delayed(const Duration(seconds: 1));
      await _loadProjects();
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  /// 加载更多项目
  Future<void> _loadMoreProjects() async {
    // TODO: 实现分页加载
    debugPrint('Load more projects');
  }

  /// 处理项目点击
  void _onProjectTap(ProjectCardData project) {
    // TODO: 打开项目详情页
    debugPrint('Open project: ${project.title}');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 标题栏："官方推荐" + 刷新按钮
        ProjectHeader(
          title: '官方推荐',
          onRefresh: _refreshProjects,
          isRefreshing: _isRefreshing,
        ),

        // 项目网格
        Expanded(
          child: _isLoading && _projects.isEmpty
              ? Center(
                  child: CircularProgressIndicator(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                )
              : ProjectGrid(
                  projects: _projects,
                  onProjectTap: _onProjectTap,
                  onLoadMore: _loadMoreProjects,
                  isLoading: false,
                ),
        ),
      ],
    );
  }
}
