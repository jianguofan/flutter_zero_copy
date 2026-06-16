import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// 项目卡片模型
class ProjectCardData {
  final String id;
  final String title;
  final String? imageUrl;
  final String authorName;
  final String? authorAvatar;

  const ProjectCardData({
    required this.id,
    required this.title,
    this.imageUrl,
    required this.authorName,
    this.authorAvatar,
  });
}

/// 项目卡片组件
///
/// 展示项目预览图、标题、作者信息
class ProjectCard extends StatefulWidget {
  final ProjectCardData project;
  final VoidCallback? onTap;

  const ProjectCard({
    super.key,
    required this.project,
    this.onTap,
  });

  @override
  State<ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends State<ProjectCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 预览图
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(8),
                ),
                child: AspectRatio(
                  aspectRatio: 1.2,
                  child: widget.project.imageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: widget.project.imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: theme.colorScheme.surfaceContainer,
                            child: Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: theme.colorScheme.surfaceContainer,
                            child: Icon(
                              Icons.image_not_supported,
                              color: theme.colorScheme.onSurfaceVariant,
                              size: 48,
                            ),
                          ),
                        )
                      : Container(
                          color: theme.colorScheme.surfaceContainer,
                          child: Icon(
                            Icons.view_in_ar,
                            color: theme.colorScheme.onSurfaceVariant,
                            size: 48,
                          ),
                        ),
                ),
              ),

              // 项目信息
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 标题
                    Text(
                      widget.project.title,
                      style: theme.textTheme.titleSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),

                    // 作者信息
                    Row(
                      children: [
                        // 作者头像
                        CircleAvatar(
                          radius: 10,
                          backgroundColor: theme.colorScheme.surfaceContainer,
                          backgroundImage: widget.project.authorAvatar != null
                              ? CachedNetworkImageProvider(
                                  widget.project.authorAvatar!)
                              : null,
                          child: widget.project.authorAvatar == null
                              ? Icon(
                                  Icons.person,
                                  size: 12,
                                  color: theme.colorScheme.onSurfaceVariant,
                                )
                              : null,
                        ),
                        const SizedBox(width: 6),

                        // 作者名
                        Expanded(
                          child: Text(
                            widget.project.authorName,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
