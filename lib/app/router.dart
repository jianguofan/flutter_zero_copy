/// App-level route definitions using go_router.
///
/// Shell:  MainFramePage (top tabs: 首页 / 预览 / 设备控制)
///   /                → redirects to /home
///   /home            → HomePage (sidebar: 模型库 / 我的设备 / 近期文件)
///   /preview         → RendererPage (3D 渲染预览)
///   /device-control  → HomeStandbyPage (Figma 首页-待机状态)
///
/// Outside shell:
///   /component-demo → ComponentDemoPage
///   /device          → DeviceListPage
///   /device/:id      → DeviceDetailPage
///   /device/discover → DeviceDiscoveryPage
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_zero_copy/pages/main_frame_page.dart';
import 'package:flutter_zero_copy/pages/home/home_page.dart';
import 'package:flutter_zero_copy/pages/renderer/renderer_page.dart';
import 'package:flutter_zero_copy/pages/home_standby_page.dart';
import 'package:flutter_zero_copy/features/device/presentation/pages/device_list_page.dart';
import 'package:flutter_zero_copy/features/device/presentation/pages/device_detail_page.dart';
import 'package:flutter_zero_copy/features/device/presentation/pages/device_discovery_page.dart';
import 'package:flutter_zero_copy/pages/component_demo_page.dart';

/// Top-level router configuration.
final appRouter = GoRouter(
  initialLocation: '/home',
  routes: [
    // ── Main shell with persistent top tab bar ─────────────────────
    ShellRoute(
      builder: (context, state, child) => MainFramePage(
        child: child,
        currentLocation: state.uri.path,
      ),
      routes: [
        // Redirect root to home
        GoRoute(
          path: '/',
          redirect: (_, __) => '/home',
        ),

        // 首页 (sidebar: 模型库 / 我的设备 / 近期文件)
        GoRoute(
          path: '/home',
          name: 'home',
          builder: (context, state) => const HomePage(),
        ),

        // 预览 (3D 渲染)
        GoRoute(
          path: '/preview',
          name: 'preview',
          builder: (context, state) => const RendererPage(),
        ),

        // 设备控制 (Figma 首页-待机状态 redesign, frame 10977:31300)
        GoRoute(
          path: '/device-control',
          name: 'deviceControl',
          builder: (context, state) => const HomeStandbyPage(),
        ),
      ],
    ),

    // ── Component demo (outside shell) ─────────────────────────────
    GoRoute(
      path: '/component-demo',
      name: 'componentDemo',
      builder: (context, state) => const ComponentDemoPage(),
    ),

    // ── Device management (feature layer, outside shell) ────────────
    GoRoute(
      path: '/device',
      name: 'deviceList',
      builder: (context, state) => const DeviceListPage(),
      routes: [
        GoRoute(
          path: ':id',
          name: 'deviceDetail',
          builder: (context, state) {
            final deviceId = state.pathParameters['id']!;
            return DeviceDetailPage(deviceId: deviceId);
          },
        ),
        GoRoute(
          path: 'discover',
          name: 'deviceDiscovery',
          builder: (context, state) => const DeviceDiscoveryPage(),
        ),
      ],
    ),
  ],
);

/// Wrap a body widget in a [Scaffold] with an optional [AppBar].
Widget _withScaffold(
  BuildContext context, {
  String? title,
  List<Widget>? actions,
  required Widget body,
}) {
  final theme = Theme.of(context);
  return Scaffold(
    backgroundColor: theme.colorScheme.surface,
    appBar: title != null
        ? AppBar(
            title: Text(title),
            actions: actions,
          )
        : null,
    body: body,
  );
}
