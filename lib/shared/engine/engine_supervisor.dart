/// Process lifecycle manager for the C++ render engine.
///
/// Adapted from spacecli/orca_engine (M13.1 → M13.4).
///
/// Responsibilities:
/// - Binary resolution (dart-define → env → exeDir → Helpers → search)
/// - Process spawn + stdio drain (prevents pipe buffer deadlock)
/// - Unix Domain Socket path generation
/// - Heartbeat (1s × 3 misses = dead, ≤3s detection)
/// - Exponential backoff restart (5 attempts, 200ms → 5s)
/// - Journal replay on recovery
/// - Orphan detection (engine side: kqueue NOTE_EXIT)
/// - Clean shutdown (socket cleanup)
///
/// Usage:
/// ```dart
/// final sup = EngineSupervisor(
///   binaryName: 'zero_copy_renderer',
///   onRecover: (client) async { /* re-send state to engine */ },
/// );
/// final client = await sup.spawn();
/// sup.startHeartbeat();
/// // ... use client ...
/// await sup.shutdown();
/// ```
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_zero_copy/shared/engine/engine_client.dart';

typedef RecoverCallback = Future<void> Function(EngineClient newClient);

class EngineSupervisor {
  final String _binaryName;
  final List<Map<String, dynamic>>? _journal;
  final RecoverCallback? _onRecover;

  EngineClient? _client;
  Process? _process;
  String? _socketPath;
  Timer? _heartbeat;
  int _missedBeats = 0;
  int _retryDelayMs = 200;
  bool _shuttingDown = false;

  EngineClient? get client => _client;
  String? get socketPath => _socketPath;
  Process? get process => _process;

  EngineSupervisor({
    String binaryName = 'zero_copy_renderer',
    List<Map<String, dynamic>>? journal,
    RecoverCallback? onRecover,
  })  : _binaryName = binaryName,
        _journal = journal,
        _onRecover = onRecover;

  /// Spawn the engine process and return a handshaked [EngineClient].
  Future<EngineClient> spawn() async {
    final binary = _resolveBinary();
    final sock = _makeSocketPath();
    _socketPath = sock;
    await _spawnProcess(binary, sock);
    _client = EngineClient(sock);
    await _client!.connect();

    // Replay journal on non-first spawn
    if (_journal != null && _journal!.isNotEmpty) {
      await _replayJournal(_client!);
    }
    return _client!;
  }

  /// Start 1s heartbeat. 3 consecutive misses = engine declared dead.
  void startHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (_client == null || _shuttingDown) return;
      try {
        await _client!
            .request('ping')
            .timeout(const Duration(milliseconds: 500));
        _missedBeats = 0;
      } catch (_) {
        _missedBeats++;
        if (_missedBeats >= 3) _onCrash();
      }
    });
  }

  /// Clean shutdown: send shutdown RPC, kill process, delete socket.
  Future<void> shutdown() async {
    _shuttingDown = true;
    _heartbeat?.cancel();
    if (_client != null) {
      try {
        await _client!.close();
      } catch (_) {}
      _client = null;
    }
    _process?.kill();
    _process = null;
    if (_socketPath != null) {
      try {
        File(_socketPath!).deleteSync();
      } catch (_) {}
      _socketPath = null;
    }
  }

  // ── Internals ──

  Future<void> _spawnProcess(String binary, String sock) async {
    // Build environment for the engine process.
    // - ORCA_APP_FRAMEWORKS_DIR: path to .app/Contents/Frameworks for dylib loading.
    // - ORCA_RESOURCES_DIR: resources (profiles, printers, …) needed to parse 3MF.
    //   Priority: env var override → installed Snapmaker Orca.app → compile-time default.
    final appContents = File(binary).parent.parent.path; // …/MacOS → …/Contents
    final frameworksDir = '$appContents/Frameworks';
    final env = <String, String>{
      if (Directory(frameworksDir).existsSync())
        'ORCA_APP_FRAMEWORKS_DIR': frameworksDir,
    };

    // Resolve resources directory
    final envRes = Platform.environment['ORCA_RESOURCES_DIR'];
    if (envRes != null && envRes.isNotEmpty) {
      env['ORCA_RESOURCES_DIR'] = envRes;
    } else {
      // Check installed Snapmaker Orca.app
      const installedRes = '/Applications/Snapmaker Orca.app/Contents/Resources';
      if (Directory(installedRes).existsSync()) {
        env['ORCA_RESOURCES_DIR'] = installedRes;
      }
    }

    _process = await Process.start(
      binary,
      [sock],
      environment: env,
      includeParentEnvironment: true,
    );

    // Drain stdout/stderr to prevent pipe buffer deadlock
    _process!.stdout.transform(utf8.decoder).listen(
          (s) => debugPrintW('[engine] $s'),
        );
    _process!.stderr.transform(utf8.decoder).listen(
          (s) => debugPrintW('[engine!] $s'),
        );

    unawaited(_process!.exitCode.then((code) {
      debugPrintW('[supervisor] engine exit=$code');
      if (!_shuttingDown) _onCrash();
    }));
  }

  Future<void> _onCrash() async {
    _heartbeat?.cancel();
    _client = null;
    _process = null;
    if (_shuttingDown) return;

    for (var attempt = 0; attempt < 5; attempt++) {
      try {
        debugPrintW('[supervisor] recovering (attempt ${attempt + 1}/5)...');
        await spawn();
        if (_onRecover != null) await _onRecover!(_client!);
        _retryDelayMs = 200; // reset backoff on success
        startHeartbeat();
        debugPrintW('[supervisor] recovered');
        return;
      } catch (e) {
        debugPrintW(
            '[supervisor] recovery attempt ${attempt + 1} failed: $e');
        await Future<void>.delayed(Duration(milliseconds: _retryDelayMs));
        _retryDelayMs = (_retryDelayMs * 2).clamp(200, 5000);
      }
    }
    debugPrintW('[supervisor] FATAL: engine unrecoverable after 5 attempts');
  }

  Future<void> _replayJournal(EngineClient client) async {
    for (final cmd in _journal!) {
      await client.request('apply_command', cmd);
    }
  }

  /// Binary resolution chain:
  /// 0. If _binaryName is an existing path → return directly
  /// 1. Compile-time constant ZERO_COPY_RENDERER_PATH
  /// 2. Environment variable ZERO_COPY_RENDERER_PATH
  /// 3. Same directory as Flutter executable
  /// 4. ../Helpers/ (inside .app bundle)
  /// 5. Script-relative search (up to 8 levels, for `flutter run`)
  /// 6. CWD-relative search (up to 8 levels)
  String _resolveBinary() {
    // 0. Direct path (absolute or relative that exists)
    if (File(_binaryName).existsSync()) return _binaryName;

    // 1. Compile-time constant
    const def = String.fromEnvironment('ZERO_COPY_RENDERER_PATH');
    if (def.isNotEmpty) return def;

    // 2. Environment variable
    final env = Platform.environment['ZERO_COPY_RENDERER_PATH'];
    if (env != null && env.isNotEmpty) return env;

    // 3. Executable directory
    if (Platform.isMacOS) {
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      final bundled = '$exeDir/$_binaryName';
      if (File(bundled).existsSync()) return bundled;
      final helpers = '$exeDir/../Helpers/$_binaryName';
      if (File(helpers).existsSync()) return helpers;
    }

    // 4. Script-relative search (flutter run)
    final scriptUri = Platform.script;
    if (scriptUri.scheme == 'file') {
      var dir = File.fromUri(scriptUri).parent;
      for (var i = 0; i < 8; i++) {
        final candidate = File('${dir.path}/$_binaryName');
        if (candidate.existsSync()) return candidate.path;
        final parent = dir.parent;
        if (parent.path == dir.path) break;
        dir = parent;
      }
    }

    // 5. CWD-relative search
    var cwd = Directory.current;
    for (var i = 0; i < 8; i++) {
      final candidate = File('${cwd.path}/$_binaryName');
      if (candidate.existsSync()) return candidate.path;
      final parent = cwd.parent;
      if (parent.path == cwd.path) break;
      cwd = parent;
    }

    throw StateError(
      '$_binaryName not found. Set ZERO_COPY_RENDERER_PATH env var '
      'or place binary next to the executable.',
    );
  }

  /// Generate a UDS socket path under TMPDIR.
  /// Must be < 104 bytes (sun_path limit on macOS).
  ///
  /// Uses a short name ("zr_<pid>.sock") because sandboxed macOS apps have
  /// a long TMPDIR (e.g. ~/Library/Containers/<bundle-id>/Data/tmp/…).
  /// If even the short name exceeds 104 bytes we fall back to a random
  /// short directory under /tmp (which is always writable on macOS outside
  /// the sandbox — sandboxed apps reach the shared /tmp via the container).
  static String _makeSocketPath() {
    final tmp = Platform.environment['TMPDIR'] ?? '/tmp';
    final path =
        '${tmp.endsWith('/') ? tmp : '$tmp/'}zr_${pid}.sock';
    if (path.length < 104) return path;

    // Sandbox container path is too long — create a short-named temp dir.
    final shortDir =
        Directory.systemTemp.createTempSync('zr').path;
    return '$shortDir/zr_${pid}.sock';
  }
}

/// debugPrint wrapper — avoids import issues in pure dart context.
void debugPrintW(String message) {
  try {
    // ignore: avoid_print
    print(message);
  } catch (_) {}
}
