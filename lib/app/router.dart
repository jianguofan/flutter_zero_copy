// App-level route definitions using go_router.
//
// Routes:
//   /                    → DeviceListPage (home)
//   /device/:id          → DeviceDetailPage
//   /device/discover     → DeviceDiscoveryPage

import 'package:go_router/go_router.dart';
import 'package:flutter_zero_copy/features/device/presentation/pages/device_list_page.dart';
import 'package:flutter_zero_copy/features/device/presentation/pages/device_detail_page.dart';
import 'package:flutter_zero_copy/features/device/presentation/pages/device_discovery_page.dart';

/// Top-level router configuration.
final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'deviceList',
      builder: (context, state) => const DeviceListPage(),
      routes: [
        GoRoute(
          path: 'device/:id',
          name: 'deviceDetail',
          builder: (context, state) {
            final deviceId = state.pathParameters['id']!;
            return DeviceDetailPage(deviceId: deviceId);
          },
        ),
        GoRoute(
          path: 'device/discover',
          name: 'deviceDiscovery',
          builder: (context, state) => const DeviceDiscoveryPage(),
        ),
      ],
    ),
  ],
);
