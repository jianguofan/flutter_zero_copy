import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

const _channel = MethodChannel('com.snapmaker.zero_copy/texture');

/// A widget that displays a zero-copy GPU texture rendered by an external
/// C++ OpenGL process via IOSurface.
///
/// Supports interactive 3D controls: orbit (drag), zoom (scroll), pan
/// (shift+drag / right-click), and double-tap to reset view.
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
        setState(() {
          _initializing = false;
          _error = e.toString();
        });
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
      stdin.flush(); // CRITICAL: IOSink buffers, must flush or C++ never sees data
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
                left: 10,
                top: 10,
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
