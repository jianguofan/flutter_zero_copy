import 'package:flutter/material.dart';

import 'package:flutter_zero_copy/app/router.dart';
import 'package:flutter_zero_copy/app/theme.dart';

/// Root application widget.
///
/// Configures the MaterialApp with go_router navigation, light/dark themes,
/// and Snapmaker brand styling.
class SnapmakerApp extends StatelessWidget {
  const SnapmakerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Snapmaker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      routerConfig: appRouter,
    );
  }
}
