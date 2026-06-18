import 'dart:async';

import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_zero_copy/shared/engine/engine_client.dart';
import 'package:flutter_zero_copy/shared/engine/engine_supervisor.dart';

/// 独立的 3D 渲染页面 — 使用 orca_engine 渲染 3MF 文件
///
/// 架构：
///   Flutter (Texture widget) ← IOSurface 零拷贝 ← orca_engine (C++ OpenGL)
///                                    ↕ UDS RPC (EngineClient)
///   交互：拖拽旋转、滚轮缩放、双击重置 | 支持打开 .3mf 文件
class RendererPage extends StatefulWidget {
  final String? rendererPath;

  const RendererPage({super.key, this.rendererPath});

  @override
  State<RendererPage> createState() => _RendererPageState();
}

class _RendererPageState extends State<RendererPage> {
  static const _channel = MethodChannel('com.snapmaker.zero_copy/texture');

  // Surface
  int? _textureId;
  int? _surfaceID;

  // Engine
  EngineSupervisor? _supervisor;
  EngineClient? _engine;
  bool _engineReady = false;
  String? _currentFile;

  // UI state
  bool _initializing = true;
  String? _error;
  bool _showStats = true;

  @override
  void initState() {
    super.initState();
    // Delay initialization until after the first frame so that
    // MediaQuery (and other inherited widgets) are available.
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    _supervisor?.shutdown();
    _channel.invokeMethod('dispose');
    super.dispose();
  }

  Future<void> _init() async {
    try {
      // 1. Create IOSurface (MethodChannel → Swift)
      //    MediaQuery is safe here because _init() is called via
      //    addPostFrameCallback, after the first build completes.
      final size = MediaQuery.of(context).size;
      final result = await _channel.invokeMethod('createSurface', {
        'width': size.width.toInt(),
        'height': size.height.toInt(),
      });
      final surfaceID = (result['surfaceID'] as int);
      _textureId = result['textureId'] as int;
      _surfaceID = surfaceID;

      if (!mounted) return;
      setState(() => _initializing = false);

      // 2. Launch orca_engine (UDS socket); pass screen size to avoid
      //    re-reading MediaQuery inside the async gap.
      await _launchEngine(surfaceID, size);
    } catch (e) {
      debugPrint('[RendererPage] Init error: $e');
      if (mounted) {
        setState(() {
          _initializing = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _launchEngine(int surfaceID, Size screenSize) async {
    // Prefer: external path → env var → auto-detect
    String binary;
    if (widget.rendererPath != null) {
      binary = widget.rendererPath!;
    } else {
      binary = Platform.environment['ZERO_COPY_RENDERER_PATH'] ?? '';
      if (binary.isEmpty) {
        final candidates = _binarySearchPaths();
        binary = candidates.firstWhere(
          (p) => File(p).existsSync(),
          orElse: () => candidates.first,
        );
      }
    }
    debugPrint('[RendererPage] Using binary: $binary');

    _supervisor = EngineSupervisor(binaryName: binary);
    _engine = await _supervisor!.spawn();
    _supervisor!.startHeartbeat();

    // Subscribe to engine events
    _engine!.events.listen((e) {
      debugPrint('[engine event] $e');
    });

    // 3. Send surface_create (current single surface repeated 3× as triple-buffer)
    await _engine!.request('surface_create', {
      'pixel_w': screenSize.width.toInt(),
      'pixel_h': screenSize.height.toInt(),
      'id0': surfaceID,
      'id1': surfaceID,
      'id2': surfaceID,
    });

    _engineReady = true;
    debugPrint('[RendererPage] Engine ready, surface=$surfaceID');

    // 如果有自动加载的文件
    if (_currentFile != null) {
      await _openProject(_currentFile!);
    }
  }

  /// 打开 3MF 项目文件
  Future<void> _openProject(String path) async {
    _currentFile = path;
    if (_engine == null || !_engineReady) return;

    try {
      final resp = await _engine!.request('project_open', {'path': path});
      debugPrint('[RendererPage] project_open: $resp');
      if (mounted) {
        setState(() {}); // 刷新 UI 显示文件名
      }
    } catch (e) {
      debugPrint('[RendererPage] project_open failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('打开文件失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Binary search paths.
  ///
  /// The App bundle path takes priority because sandboxed macOS apps
  /// cannot spawn binaries outside their own bundle ("Operation not permitted").
  /// The project source directory is a fallback for non-sandboxed runs.
  List<String> _binarySearchPaths() {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final srcRoot = _findProjectRoot();
    return [
      // 1. Env var (handled by caller)
      // 2. App bundle — must be first for sandboxed apps
      '$exeDir/orca_engine',
      // 3. Helpers dir inside .app bundle (production layout)
      '$exeDir/../Helpers/orca_engine',
      // 4. Project source dir (non-sandboxed dev fallback)
      if (srcRoot != null) '$srcRoot/slicer-render-engine/orca_engine',
      // 5. CWD fallback
      '${Directory.current.path}/slicer-render-engine/orca_engine',
    ];
  }

  /// 从可执行文件位置向上查找项目根（包含 pubspec.yaml 的目录）
  String? _findProjectRoot() {
    var dir = File(Platform.resolvedExecutable).parent;
    for (var i = 0; i < 10; i++) {
      if (File('${dir.path}/pubspec.yaml').existsSync()) {
        return dir.path;
      }
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
    return null;
  }

  /// Open a native macOS file picker and load the selected 3MF file.
  Future<void> _pickAndOpenFile() async {
    const typeGroup = XTypeGroup(
      label: '3MF 文件',
      extensions: ['3mf'],
    );

    try {
      final file = await openFile(acceptedTypeGroups: const [typeGroup]);
      if (file == null || file.path.isEmpty) return; // user cancelled

      final path = file.path;
      debugPrint('[RendererPage] Selected: $path');

      // If engine isn't ready yet, save the path and open later
      if (_engine == null || !_engineReady) {
        _currentFile = path;
        if (mounted) setState(() {});
        return;
      }

      await _openProject(path);
    } catch (e) {
      debugPrint('[RendererPage] File picker error: $e');
    }
  }

  // ── Engine RPC commands ──

  void _orbit(double dx, double dy) {
    if (_engine == null || !_engineReady) return;
    _engine!.sendInput('input_orbit', {
      'dx': dx,
      'dy': dy,
      't': DateTime.now().microsecondsSinceEpoch,
    }, merge: InputMerge.accumulate);
  }

  void _zoom(double factor, double anchorX, double anchorY) {
    if (_engine == null || !_engineReady) return;
    _engine!.sendInput('input_zoom', {
      'factor': factor,
      'anchor_x': anchorX,
      'anchor_y': anchorY,
      't': DateTime.now().microsecondsSinceEpoch,
    }, merge: InputMerge.accumulate);
  }

  void _pan(double dx, double dy) {
    if (_engine == null || !_engineReady) return;
    _engine!.sendInput('input_pan', {
      'dx': dx,
      'dy': dy,
      't': DateTime.now().microsecondsSinceEpoch,
    }, merge: InputMerge.accumulate);
  }

  Future<void> _sceneFit() async {
    if (_engine == null || !_engineReady) return;
    await _engine!.request('scene_fit');
  }

  // ── Pointer events ──

  int _navigationButtons = 0;

  bool _isPanButton(int buttons) {
    return (buttons & kSecondaryMouseButton) != 0 ||
        (buttons & kMiddleMouseButton) != 0 ||
        HardwareKeyboard.instance.logicalKeysPressed
            .contains(LogicalKeyboardKey.shiftLeft) ||
        HardwareKeyboard.instance.logicalKeysPressed
            .contains(LogicalKeyboardKey.shiftRight);
  }

  void _onPointerDown(PointerDownEvent e) {
    _navigationButtons = e.buttons;
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (e.buttons == 0 || _inScaleGesture) return;
    _navigationButtons = e.buttons;
    _draggedDuringPointer = true;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final nativeDelta = e.delta * dpr;
    if (_isPanButton(e.buttons)) {
      _pan(nativeDelta.dx, nativeDelta.dy);
    } else {
      _orbit(nativeDelta.dx, nativeDelta.dy);
    }
  }

  void _onPointerUp(PointerUpEvent e) {
    _navigationButtons = 0;
  }

  void _onPointerCancel(PointerCancelEvent e) {
    _navigationButtons = 0;
  }

  void _onScroll(PointerSignalEvent e) {
    if (e is PointerScrollEvent) {
      final factor = e.scrollDelta.dy < 0 ? 1.1 : 0.9;
      _zoom(factor, e.localPosition.dx, e.localPosition.dy);
    }
  }

  // ── GestureDetector callbacks (trackpad pinch-to-zoom, pan) ──

  double _scaleStart = 1.0;
  bool _inScaleGesture = false;

  void _onScaleStart(ScaleStartDetails details) {
    _scaleStart = 1.0;
    _inScaleGesture = true;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final dpr = MediaQuery.devicePixelRatioOf(context);

    // Pinch-to-zoom via scale factor
    if (details.scale != 1.0) {
      final factor = details.scale / _scaleStart;
      _scaleStart = details.scale;
      final anchor = details.localFocalPoint;
      _zoom(factor, anchor.dx, anchor.dy);
    }

    // Two-finger pan (orbit if not shift, pan if shift)
    final nativeDelta = details.focalPointDelta * dpr;
    if (nativeDelta.dx.abs() > 0 || nativeDelta.dy.abs() > 0) {
      if (_isPanButton(_navigationButtons)) {
        _pan(nativeDelta.dx, nativeDelta.dy);
      } else {
        _orbit(nativeDelta.dx, nativeDelta.dy);
      }
    }
  }

  void _onScaleEnd(ScaleEndDetails details) {
    _scaleStart = 1.0;
    _inScaleGesture = false;
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F3460),
        title: Text(_currentFile != null
            ? '3D 渲染 — ${_currentFile!.split('/').last}'
            : '3D 渲染'),
        actions: [
          // 打开文件
          TextButton.icon(
            onPressed: _pickAndOpenFile,
            icon: const Icon(Icons.folder_open, size: 18),
            label: const Text('打开 3MF', style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(foregroundColor: Colors.white),
          ),
          // 重置视角
          IconButton(
            icon: const Icon(Icons.center_focus_strong),
            tooltip: '重置视角',
            onPressed: _sceneFit,
          ),
          // 调试信息
          IconButton(
            icon: Icon(
              Icons.info_outline,
              color: _showStats ? Colors.greenAccent : Colors.white54,
            ),
            tooltip: '显示信息',
            onPressed: () => setState(() => _showStats = !_showStats),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() { _error = null; _initializing = true; });
                _init();
              },
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_initializing || _textureId == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white54),
            SizedBox(height: 16),
            Text('正在启动渲染引擎...',
                style: TextStyle(color: Colors.white54)),
          ],
        ),
      );
    }

    return Stack(
      children: [
        // 3D 纹理 — 全屏
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: _onPointerDown,
                onPointerMove: _onPointerMove,
                onPointerUp: _onPointerUp,
                onPointerCancel: _onPointerCancel,
                onPointerSignal: _onScroll,
                child: GestureDetector(
                  onDoubleTap: _sceneFit,
                  onScaleStart: _onScaleStart,
                  onScaleUpdate: _onScaleUpdate,
                  onScaleEnd: _onScaleEnd,
                  child: Texture(textureId: _textureId!),
                ),
              );
            },
          ),
        ),

        // 空状态提示
        if (_currentFile == null && _engineReady)
          Positioned(
            left: 0,
            right: 0,
            top: MediaQuery.of(context).size.height * 0.35,
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.insert_drive_file_outlined,
                        size: 48, color: Colors.white38),
                    const SizedBox(height: 12),
                    const Text('打开 3MF 文件以开始渲染',
                        style: TextStyle(color: Colors.white54, fontSize: 16)),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _pickAndOpenFile,
                      icon: const Icon(Icons.folder_open, size: 18),
                      label: const Text('选择 3MF 文件'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F3460),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // 左下角信息面板
        if (_showStats)
          Positioned(
            left: 16,
            bottom: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: DefaultTextStyle(
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Engine: ${_engineReady ? "connected" : "starting..."}'),
                    Text('Surface ID: ${_surfaceID ?? "—"}'),
                    Text('Texture ID: ${_textureId ?? "—"}'),
                    if (_currentFile != null)
                      Text('File: ${_currentFile!.split('/').last}'),
                  ],
                ),
              ),
            ),
          ),

        // 底部操作提示
        Positioned(
          left: 0, right: 0, bottom: 16,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                '拖拽旋转 · Shift/右键平移 · 滚轮/捏合缩放 · 双击重置',
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
