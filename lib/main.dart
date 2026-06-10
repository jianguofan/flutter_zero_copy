import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _channel = MethodChannel('com.snapmaker.zero_copy/texture');

/// A widget that displays a zero-copy GPU texture rendered by an external
/// C++ OpenGL process via IOSurface.
class ZeroCopyWidget extends StatefulWidget {
  final double width;
  final double height;
  final double left;
  final double top;
  final String? rendererPath;
  final bool debugCpp;  // pass --debug to cube_renderer, waits for lldb attach

  const ZeroCopyWidget({
    super.key,
    required this.width,
    required this.height,
    required this.left,
    required this.top,
    this.rendererPath,
    this.debugCpp = false,
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

void main() => runApp(const ZeroCopyDemoApp());

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
  bool _showCube = true; // Auto-start
  int _key = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zero-Copy GPU Texture Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: const Color(0xFF1A1A2E)),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Zero-Copy GPU Texture Demo'),
          backgroundColor: const Color(0xFF0F3460),
        ),
        body: Stack(
          children: [
            if (_showCube)
              ZeroCopyWidget(
                key: ValueKey(_key),
                width: _width,
                height: _height,
                left: _left,
                top: _top,
              ),
            Positioned(right: 20, top: 20, child: _controlPanel()),
          ],
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
