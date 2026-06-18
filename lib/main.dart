import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:flutter_zero_copy/app/app.dart';

/// Application entry point.
///
/// Initializes platform bindings, local storage (Hive), and the Riverpod
/// dependency injection container before launching the app.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  runApp(const ProviderScope(child: SnapmakerApp()));
}
