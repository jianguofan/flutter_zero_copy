import 'package:flutter/material.dart';

import 'package:flutter_zero_copy/widgets/zero_copy_widget.dart';

/// Legacy cube renderer demo page.
///
/// Renders a spinning cube using the zero-copy IOSurface texture pipeline,
/// with interactive orbit/zoom controls and a configuration panel.
class CubeDemoPage extends StatefulWidget {
  const CubeDemoPage({super.key});

  @override
  State<CubeDemoPage> createState() => _CubeDemoPageState();
}

class _CubeDemoPageState extends State<CubeDemoPage> {
  double _width = 600;
  double _height = 450;
  double _left = 30;
  double _top = 80;
  bool _showCube = true;
  bool _debugCpp = false;
  bool _autoRotate = false;
  int _key = 0;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
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

            // ── Tab 2: Info ──────────────────────────────────
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

            // ── Tab 3: Color palette ────────────────────────
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

            // ── Tab 4: Config ───────────────────────────────
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
              style: TextStyle(
                  color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => setState(() {
              _showCube = !_showCube;
              if (_showCube) _key++;
            }),
            icon: Icon(_showCube ? Icons.stop : Icons.play_arrow),
            label: Text(_showCube ? 'Stop' : 'Start'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _showCube ? Colors.redAccent : Colors.green,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Debug C++',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
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
              const Text('Auto Rotate',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
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
              onPressed: () => setState(() => _key++),
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

  Widget _slider(
      String label, double value, double min, double max, Function(double) cb) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
              width: 20,
              child: Text(label,
                  style: const TextStyle(color: Colors.white54, fontSize: 11))),
          Expanded(
            child: Slider(
              value: value,
              min: min,
              max: max,
              activeColor: Colors.blueAccent,
              onChanged: (v) => setState(() => cb(v)),
            ),
          ),
          Text('${value.toInt()}',
              style: const TextStyle(color: Colors.white38, fontSize: 10)),
        ],
      ),
    );
  }
}
