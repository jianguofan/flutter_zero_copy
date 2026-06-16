import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_zero_copy/pages/ui_demo_page.dart';
import 'package:flutter_zero_copy/state/user_state.dart';
import 'package:provider/provider.dart';
import 'package:flutter_zero_copy/pages/ui_demo_page.dart';

const _channel = MethodChannel('com.snapmaker.zero_copy/texture');

/// A widget that displays a zero-copy GPU texture rendered by an external
/// C++ OpenGL process via IOSurface.
class ZeroCopyWidget extends StatefulWidget {
  final double width;
  final double height;
  final double left;
  final double top;
  final String? rendererPath;
  final bool debugCpp;

  // Interactive control parameters
  final bool interactive;
  final bool autoRotate;
  final double rotationSpeed;
  final double minZoom;
  final double maxZoom;

  const ZeroCopyWidget({
    super.key,
    required this.width,
    required this.height,
    required this.left,
    required this.top,
    this.rendererPath,
    this.debugCpp = false,
    this.interactive = true,
    this.autoRotate = false,
    this.rotationSpeed = 1.0,
    this.minZoom = 1.5,
    this.maxZoom = 20.0,
  });

  @override
  State<ZeroCopyWidget> createState() => _ZeroCopyWidgetState();
}

class _ZeroCopyWidgetState extends State<ZeroCopyWidget> {
  int? _textureId;
  int? _surfaceID;
  Process? _childProcess;
  bool _disposed = false;
  bool _initializing = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void didUpdateWidget(ZeroCopyWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.autoRotate != widget.autoRotate) {
      _sendCommand({
        'type': 'config',
        'autoRotate': widget.autoRotate,
      });
    }
  }

  Future<void> _initialize() async {
    try {
      final result = await _channel.invokeMethod('createSurface', {
        'width': widget.width.toInt(),
        'height': widget.height.toInt(),
      });

      final surfaceID = result['surfaceID'] as int;
      final textureId = result['textureId'] as int;

      if (_disposed || !mounted) return;
      setState(() {
        _surfaceID = surfaceID;
        _textureId = textureId;
        _initializing = false;
      });

      debugPrint('[ZeroCopy] surfaceID=$surfaceID textureId=$textureId');

      // Launch C++ child process
      await _launchRenderer(surfaceID);
    } catch (e) {
      debugPrint('[ZeroCopy] Error: $e');
      if (!_disposed && mounted) {
        setState(() { _initializing = false; _error = e.toString(); });
      }
    }
  }

  Future<void> _launchRenderer(int surfaceID) async {
    String path;
    if (widget.rendererPath != null) {
      path = widget.rendererPath!;
    } else {
      final exeDir = Directory(Platform.resolvedExecutable).parent;
      final bundlePath = '${exeDir.path}/cube_renderer';
      if (await File(bundlePath).exists()) {
        path = bundlePath;
      } else {
        path = 'cube_renderer/build/cube_renderer';
      }
    }

    debugPrint('[ZeroCopy] Launching: $path $surfaceID');

    final args = <String>[
      surfaceID.toString(),
      widget.width.toInt().toString(),
      widget.height.toInt().toString(),
      if (widget.debugCpp) '--debug',
    ];

    _childProcess = await Process.start(path, args);

    _childProcess!.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((l) => debugPrint('[cube] $l'));

    _childProcess!.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((l) => debugPrint('[cube:err] $l'));

    _childProcess!.exitCode.then((c) => debugPrint('[ZeroCopy] Renderer exit: $c'));

    // Send initial camera config to C++ renderer
    _sendCommand({
      'type': 'config',
      'autoRotate': widget.autoRotate,
    });
  }

  // ── Interactive control ─────────────────────────────────────────────

  /// Write a JSON command to the child process stdin.
  void _sendCommand(Map<String, dynamic> cmd) {
    if (_disposed) {
      debugPrint('[ZeroCopy] _sendCommand SKIP: disposed');
      return;
    }
    final stdin = _childProcess?.stdin;
    if (stdin == null) {
      debugPrint('[ZeroCopy] _sendCommand SKIP: stdin is null');
      return;
    }
    try {
      final jsonStr = '${jsonEncode(cmd)}\n';
      debugPrint('[ZeroCopy] → C++: $jsonStr');
      stdin.write(jsonStr);
      stdin.flush();  // CRITICAL: IOSink buffers, must flush or C++ never sees data
    } catch (e) {
      debugPrint('[ZeroCopy] _sendCommand failed: $e');
    }
  }

  // Accumulated delta between sends
  double _accumulatedDx = 0.0;
  double _accumulatedDy = 0.0;
  int _lastSendTime = 0;

  void _onPointerDown(PointerDownEvent e) {
    debugPrint('[ZeroCopy] 👆 pointer down at (${e.position.dx}, ${e.position.dy})');
    if (!widget.interactive) return;
    _accumulatedDx = 0.0;
    _accumulatedDy = 0.0;
    _lastSendTime = DateTime.now().millisecondsSinceEpoch;
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (!widget.interactive) return;
    _accumulatedDx += e.delta.dx;
    _accumulatedDy += e.delta.dy;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastSendTime < 16) return;
    _lastSendTime = now;
    debugPrint('[ZeroCopy] 🖱️ move: raw(${e.delta.dx}, ${e.delta.dy}) acc(${_accumulatedDx.toStringAsFixed(1)}, ${_accumulatedDy.toStringAsFixed(1)})');
    _sendCommand({
      'type': 'rotate',
      'dx': _accumulatedDx * widget.rotationSpeed,
      'dy': _accumulatedDy * widget.rotationSpeed,
    });
    _accumulatedDx = 0.0;
    _accumulatedDy = 0.0;
  }

  void _onPointerUp(PointerUpEvent e) {
    // Flush any remaining delta
    if (_accumulatedDx != 0.0 || _accumulatedDy != 0.0) {
      _sendCommand({
        'type': 'rotate',
        'dx': _accumulatedDx * widget.rotationSpeed,
        'dy': _accumulatedDy * widget.rotationSpeed,
      });
      _accumulatedDx = 0.0;
      _accumulatedDy = 0.0;
    }
  }

  void _onPointerSignal(PointerSignalEvent e) {
    if (!widget.interactive) return;
    if (e is PointerScrollEvent) {
      _sendCommand({
        'type': 'zoom',
        'scale': e.scrollDelta.dy,
      });
    }
  }

  void _resetView() {
    _sendCommand({'type': 'reset'});
  }

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (_error != null) {
      child = Container(
        color: Colors.red.shade900,
        child: Center(
          child: Text('Error: $_error',
              style: const TextStyle(color: Colors.white, fontSize: 11)),
        ),
      );
    } else if (_initializing || _textureId == null) {
      child = Container(
        color: const Color(0xFF1A1A2E),
        child: const Center(child: CircularProgressIndicator(color: Colors.white54)),
      );
    } else {
      child = Texture(textureId: _textureId!);
    }

    return Positioned(
      left: widget.left,
      top: widget.top,
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: Stack(
          children: [
            child,
            // Transparent touch layer for 3D interaction
            if (widget.interactive && _textureId != null && _error == null)
              Positioned.fill(
                child: GestureDetector(
                  onDoubleTap: _resetView,
                  child: Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: _onPointerDown,
                    onPointerMove: _onPointerMove,
                    onPointerUp: _onPointerUp,
                    onPointerSignal: _onPointerSignal,
                    child: Container(color: Colors.transparent),
                  ),
                ),
              ),
            if (_surfaceID != null)
              Positioned(
                left: 10, top: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Cube | surfaceID=$_surfaceID | ${widget.width.toInt()}x${widget.height.toInt()}',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 11, fontFamily: 'monospace'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _childProcess?.kill(ProcessSignal.sigterm);
    _channel.invokeMethod('dispose');
    super.dispose();
  }
}

// =========================================================================
// Demo App
// =========================================================================

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => UserState(),
      child: MaterialApp(
        title: 'Snapmaker UI Demo',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.light(useMaterial3: true),
        darkTheme: ThemeData.dark(useMaterial3: true),
        home: const UiMigrationDemoPage(),
      ),
    );
  }
}

class ZeroCopyDemoApp extends StatefulWidget {
  const ZeroCopyDemoApp({super.key});

  @override
  State<ZeroCopyDemoApp> createState() => _ZeroCopyDemoAppState();
}

class _ZeroCopyDemoAppState extends State<ZeroCopyDemoApp> {
  double _width = 600;
  double _height = 450;
  double _left = 30;
  double _top = 80;
  bool _showCube = true;
  bool _debugCpp = false; // 需要调试 C++ 时打开
  bool _autoRotate = false;
  int _key = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zero-Copy GPU Texture Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: const Color(0xFF1A1A2E)),
      home: DefaultTabController(
        length: 4,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Zero-Copy GPU Texture Demo'),
            backgroundColor: const Color(0xFF0F3460),
            bottom: const TabBar(
              indicatorColor: Colors.blueAccent,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              tabs: [
                Tab(icon: Icon(Icons.view_in_ar), text: 'Cube'),
                Tab(icon: Icon(Icons.article), text: 'Info'),
                Tab(icon: Icon(Icons.palette), text: 'Colors'),
                Tab(icon: Icon(Icons.settings), text: 'Config'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              // ── Tab 1: Cube Renderer + Control Panel ──────────
              Stack(
                children: [
                  if (_showCube)
                    ZeroCopyWidget(
                      key: ValueKey(_key),
                      width: _width,
                      height: _height,
                      left: _left,
                      top: _top,
                      debugCpp: _debugCpp,
                      autoRotate: _autoRotate,
                    ),
                  Positioned(right: 20, top: 20, child: _controlPanel()),
                ],
              ),

              // ── Tab 2: Info placeholder ───────────────────────
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info_outline, size: 64, color: Colors.white24),
                    const SizedBox(height: 16),
                    Text('Information',
                        style: TextStyle(fontSize: 24, color: Colors.white54)),
                    const SizedBox(height: 8),
                    Text('Surface ID: ${_showCube ? "active" : "none"}',
                        style: TextStyle(fontSize: 14, color: Colors.white38)),
                  ],
                ),
              ),

              // ── Tab 3: Color palette placeholder ──────────────
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0F3460), Color(0xFF16213E), Color(0xFF1A1A2E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Center(
                  child: Text('🎨 Color Space',
                      style: TextStyle(fontSize: 20, color: Colors.white54)),
                ),
              ),

              // ── Tab 4: Config placeholder ─────────────────────
              const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.tune, size: 64, color: Colors.white24),
                    SizedBox(height: 16),
                    Text('Configuration',
                        style: TextStyle(fontSize: 24, color: Colors.white54)),
                    SizedBox(height: 8),
                    Text('More settings coming soon',
                        style: TextStyle(fontSize: 14, color: Colors.white38)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _controlPanel() {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Controls',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => setState(() { _showCube = !_showCube; if (_showCube) _key++; }),
            icon: Icon(_showCube ? Icons.stop : Icons.play_arrow),
            label: Text(_showCube ? 'Stop' : 'Start'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _showCube ? Colors.redAccent : Colors.green,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Debug C++', style: TextStyle(color: Colors.white70, fontSize: 12)),
              const Spacer(),
              Switch(
                value: _debugCpp,
                activeColor: Colors.orangeAccent,
                onChanged: (v) => setState(() => _debugCpp = v),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Auto Rotate', style: TextStyle(color: Colors.white70, fontSize: 12)),
              const Spacer(),
              Switch(
                value: _autoRotate,
                activeColor: Colors.lightBlueAccent,
                onChanged: (v) => setState(() => _autoRotate = v),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () {
                // Re-create widget to trigger full init with new key
                setState(() { _key++; });
              },
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Reset View', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white70,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _slider('W', _width, 200, 1200, (v) => _width = v),
          _slider('H', _height, 150, 900, (v) => _height = v),
          _slider('L', _left, 0, 600, (v) => _left = v),
          _slider('T', _top, 0, 400, (v) => _top = v),
        ],
      ),
    );
  }

  Widget _slider(String label, double value, double min, double max, Function(double) cb) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(width: 20, child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11))),
          Expanded(
            child: Slider(
              value: value, min: min, max: max,
              activeColor: Colors.blueAccent,
              onChanged: (v) => setState(() => cb(v)),
            ),
          ),
          Text('${value.toInt()}', style: const TextStyle(color: Colors.white38, fontSize: 10)),
        ],
      ),
    );
  }
}
