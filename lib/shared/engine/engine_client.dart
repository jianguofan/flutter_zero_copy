/// UDS-based RPC client for communicating with the C++ render engine process.
///
/// Adapted from spacecli/orca_engine (protocol v1).
///
/// Frame format (5-byte header + payload):
///   - 1 byte: type (0=JSON, 1=binary)
///   - 4 bytes: big-endian payload length
///   - N bytes: payload (max 32MB)
///
/// Usage:
/// ```dart
/// final client = EngineClient(socketPath);
/// await client.connect();
/// client.events.listen((e) => print('event: $e'));
/// final resp = await client.request('some_op', {'key': 'value'});
/// client.sendInput('input_orbit', {'dx': 2.0, 'dy': -1.0}, merge: InputMerge.accumulate);
/// await client.close();
/// ```
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class EngineClient {
  final String _path;
  Socket? _control;
  final _rx = BytesBuilder();
  final _pending = <String, _PendingRequest>{};
  final _eventCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _responseCtrl = StreamController<Map<String, dynamic>>.broadcast();

  // Input flow control — one in-flight + one pending slot per stream
  _InputSlot? _orbitSlot;
  _InputSlot? _panSlot;
  _InputSlot? _zoomSlot;
  bool _shuttingDown = false;

  EngineClient(String socketPath) : _path = socketPath;

  /// Broadcast stream of unsolicited server events (e.g. render_stats, disconnects).
  Stream<Map<String, dynamic>> get events => _eventCtrl.stream;

  /// Connect to the engine process via Unix Domain Socket.
  ///
  /// Retries up to 200 times (20ms intervals, ~4s total) then throws.
  Future<void> connect() async {
    for (var i = 0; i < 200; i++) {
      try {
        _control = await Socket.connect(
          InternetAddress(_path, type: InternetAddressType.unix),
          0,
        );
        break;
      } catch (_) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    }
    if (_control == null) {
      throw Exception('EngineClient: connect $_path failed');
    }
    _control!.listen(
      _onData,
      onDone: () => _eventCtrl.add({'event': 'engine_disconnected'}),
    );

    // Protocol v1 handshake
    final ack = await _sendAndWait({
      'op': 'hello',
      'channel': 'control',
      'protocol_version': 1,
    });
    if (ack['ok'] == false) {
      throw Exception('EngineClient: hello rejected: $ack');
    }
  }

  /// Send a request and wait for a single response (id-matched). Timeout 30s.
  Future<Map<String, dynamic>> request(
    String op, [
    Map<String, dynamic>? payload,
  ]) async {
    if (_control == null) throw StateError('not connected');
    final msg = <String, dynamic>{'op': op};
    if (payload != null) msg.addAll(payload);
    return _sendAndWait(msg);
  }

  /// Send an input event with merge semantics.
  ///
  /// - [InputMerge.accumulate]: dx/dy summed, factor multiplied, anchor uses latest
  /// - [InputMerge.overwrite]: replaces pending
  /// - [InputMerge.barrier]: sent immediately, no merging
  void sendInput(
    String op,
    Map<String, dynamic> payload, {
    required InputMerge merge,
  }) {
    if (merge == InputMerge.barrier) {
      _sendJson({'op': op, ...payload});
      return;
    }
    final slot = _slotFor(op);
    if (slot == null) return;
    slot.merge(op, payload, merge);
    _flushSlot(slot);
  }

  /// Send a binary frame (e.g., mesh vertex/index data).
  void sendBinaryFrame(
    String op,
    int handleId,
    Float32List vertices,
    Uint32List indices,
  ) {
    _sendJson({
      'op': op,
      'handle': 'obj_$handleId',
      'vertex_count': vertices.length,
      'index_count': indices.length,
    });
    final vbytes = vertices.buffer.asUint8List(
      vertices.offsetInBytes,
      vertices.lengthInBytes,
    );
    final ibytes = indices.buffer.asUint8List(
      indices.offsetInBytes,
      indices.lengthInBytes,
    );
    final total = vbytes.length + ibytes.length;
    final hdr = ByteData(5)
      ..setUint8(0, 1) // binary frame type
      ..setUint32(1, total);
    _control?.add(hdr.buffer.asUint8List());
    _control?.add(vbytes);
    _control?.add(ibytes);
  }

  /// Subscribe to a named event stream on the engine.
  void subscribe(String event) {
    _sendJson({'op': 'subscribe', 'event': event});
  }

  /// Clean shutdown: send shutdown request, destroy socket, close streams.
  Future<void> close() async {
    _shuttingDown = true;
    try {
      await request('shutdown');
    } catch (_) {}
    _control?.destroy();
    _control = null;
    await _eventCtrl.close();
    await _responseCtrl.close();
  }

  // ── Internals ──

  _InputSlot? _slotFor(String op) {
    if (op == 'input_orbit') return _orbitSlot ??= _InputSlot(this, op);
    if (op == 'input_pan') return _panSlot ??= _InputSlot(this, op);
    if (op == 'input_zoom') return _zoomSlot ??= _InputSlot(this, op);
    return null;
  }

  void _flushSlot(_InputSlot slot) {
    if (slot.inFlight) {
      // ignore: avoid_print
      print('[EngineClient] ${slot.op} slot BLOCKED (inFlight)');
      return;
    }
    final p = slot.takePending();
    if (p == null) return;
    slot.inFlight = true;
    // ignore: avoid_print
    print('[EngineClient] → SEND ${slot.op}: $p');
    _sendJson(p);
  }

  void _onSlotResponse(_InputSlot slot) {
    slot.inFlight = false;
    _flushSlot(slot);
  }

  Future<Map<String, dynamic>> _sendAndWait(Map<String, dynamic> msg) {
    final id = _uuid4();
    msg['id'] = id;
    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = _PendingRequest(
      completer,
      Timer(const Duration(seconds: 30), () {
        if (!completer.isCompleted) {
          completer.completeError(TimeoutException('request $id'));
        }
        _pending.remove(id);
      }),
    );
    _sendJson(msg);
    return completer.future;
  }

  void _sendJson(Map<String, dynamic> msg) {
    final body = utf8.encode(jsonEncode(msg));
    final hdr = ByteData(5)
      ..setUint8(0, 0) // JSON frame type
      ..setUint32(1, body.length);
    _control?.add(hdr.buffer.asUint8List());
    _control?.add(body);
  }

  void _onData(Uint8List data) {
    _rx.add(data);
    var buf = _rx.toBytes();
    var off = 0;
    while (buf.length - off >= 5) {
      final len =
          ByteData.sublistView(buf, off + 1, off + 5).getUint32(0);
      if (buf.length - off < 5 + len) break;
      final body = utf8.decode(buf.sublist(off + 5, off + 5 + len));
      off += 5 + len;
      Map<String, dynamic> m;
      try {
        m = jsonDecode(body) as Map<String, dynamic>;
      } catch (_) {
        continue; // skip malformed frame
      }
      _dispatch(m);
    }
    _rx.clear();
    if (off < buf.length) _rx.add(buf.sublist(off));
  }

  void _dispatch(Map<String, dynamic> m) {
    if (m.containsKey('event')) {
      _eventCtrl.add(m);
      return;
    }
    final id = m['id'] as String?;
    if (id != null) {
      final pending = _pending.remove(id);
      if (pending != null) {
        pending.timer.cancel();
        if (m['ok'] == true || m['ok'] == null) {
          pending.completer.complete(m);
        } else {
          pending.completer.completeError(
            EngineError(
              (m['error'] as Map?)?.cast<String, dynamic>()['code'] as int? ?? 1,
              (m['error'] as Map?)?.cast<String, dynamic>()['message'] as String? ?? '',
            ),
          );
        }
        return;
      }
    }
    // Input slot response (no id, matched by op_replied)
    final replied = m['op_replied'] as String?;
    if (replied == null && (m['op'] == 'render_stats' || m.containsKey('render_us'))) {
      // Backward-compat: engine replies with render_stats instead of explicit
      // input acks.  Free ALL input slots — not just orbit — so pan and zoom
      // don't deadlock after the first frame.
      for (final slot in [_orbitSlot, _panSlot, _zoomSlot]) {
        if (slot != null) _onSlotResponse(slot);
      }
      return;
    }
    if (replied != null) {
      final slot = _slotFor(replied);
      if (slot != null) {
        // ignore: avoid_print
        print('[EngineClient] ← ${replied} ack render_us=${m['render_us']} drops=${m['drops']}');
        _onSlotResponse(slot);
      }
      // Notify engine that the frame was consumed, freeing the IOSurface slot
      // for the next render. Without this, the engine's triple-buffer slots
      // fill up after 3 renders and all subsequent render_one() calls return
      // render_us=0 (no-op).
      _sendJson({'op': 'frame_consumed', 'idx': 0});
      return;
    }
    // Catch-all: log any message we don't explicitly handle
    // ignore: avoid_print
    print('[EngineClient] ← unhandled: ${m['op'] ?? m.toString()}');
  }

  static String _uuid4() {
    final r = List<int>.generate(16, (i) {
      return (DateTime.now().microsecondsSinceEpoch * 1103515245 +
              12345 +
              i.hashCode * 31)
          .abs() & 0xFF;
    });
    r[6] = (r[6] & 0x0f) | 0x40;
    r[8] = (r[8] & 0x3f) | 0x80;
    return r.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}

// ── Supporting types ──

class _PendingRequest {
  final Completer<Map<String, dynamic>> completer;
  final Timer timer;
  _PendingRequest(this.completer, this.timer);
}

enum InputMerge { accumulate, overwrite, barrier }

class _InputSlot {
  final EngineClient client;
  final String op;
  bool inFlight = false;
  Map<String, dynamic>? _pending;

  _InputSlot(this.client, this.op);

  void merge(String op, Map<String, dynamic> p, InputMerge m) {
    if (_pending == null) {
      _pending = {'op': op, ...p};
      return;
    }
    switch (m) {
      case InputMerge.accumulate:
        if (p.containsKey('dx')) {
          _pending!['dx'] = (_pending!['dx'] as double? ?? 0.0) + (p['dx'] as double);
        }
        if (p.containsKey('dy')) {
          _pending!['dy'] = (_pending!['dy'] as double? ?? 0.0) + (p['dy'] as double);
        }
        if (p.containsKey('factor')) {
          _pending!['factor'] = (_pending!['factor'] as double? ?? 1.0) * (p['factor'] as double);
        }
        if (p.containsKey('anchor_x')) _pending!['anchor_x'] = p['anchor_x'];
        if (p.containsKey('anchor_y')) _pending!['anchor_y'] = p['anchor_y'];
        _pending!['t'] = p['t'];
      case InputMerge.overwrite:
        _pending = {'op': op, ...p};
      case InputMerge.barrier:
        break;
    }
  }

  Map<String, dynamic>? takePending() {
    final p = _pending;
    _pending = null;
    return p;
  }
}

class EngineError implements Exception {
  final int code;
  final String message;
  EngineError(this.code, this.message);

  @override
  String toString() => 'EngineError($code): $message';
}
