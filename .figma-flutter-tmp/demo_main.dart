// Demo 入口 — 直接运行测试 Figma 首页-待机状态 生成的代码
// 运行方式：将此文件复制到 lib/ 下，在 main.dart 中引用 HomeStandbyPage
import 'package:flutter/material.dart';
import 'home_standby_page.dart';

void main() {
  runApp(const FigmaDemoApp());
}

class FigmaDemoApp extends StatelessWidget {
  const FigmaDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Figma → Flutter Demo',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF0C63E2),
      ),
      home: const Scaffold(
        body: HomeStandbyPage(),
      ),
    );
  }
}
