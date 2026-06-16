import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:lava_device_sdk/src/transport/transport.dart';

class WebSocketConfig {
  final String url;

  const WebSocketConfig({required this.url});
}

class WebSocketTransport implements DeviceTransport {
  final WebSocketConfig _config;
  WebSocketChannel? _channel;
  final StreamController<TransportMessage> _messageController = StreamController.broadcast();

  WebSocketTransport({required WebSocketConfig config}) : _config = config;

  @override
  Stream<TransportMessage> get messageStream => _messageController.stream;

  @override
  bool get isConnected => _channel != null;

  @override
  Future<void> connect() async {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(_config.url));
    } catch (e, stack) {
      stderr.writeln('[WebSocketTransport] connect failed: $e\n$stack');
      _messageController.addError(e, stack);
      rethrow;
    }

    _channel!.stream.listen(
      (data) {
        _messageController.add(TransportMessage(
          topic: '',
          payload: data is Uint8List ? data : Uint8List.fromList(data),
        ));
      },
      onError: (Object error, StackTrace stack) {
        stderr.writeln('[WebSocketTransport] stream error: $error\n$stack');
        _channel = null;
        _messageController.addError(error, stack);
      },
      onDone: () {
        stderr.writeln('[WebSocketTransport] stream closed');
        _channel = null;
      },
    );
  }

  @override
  void send(String topic, Uint8List payload) {
    if (_channel == null) {
      stderr.writeln('[WebSocketTransport] send failed: not connected');
      return;
    }
    _channel!.sink.add(payload);
  }

  @override
  Future<void> disconnect() async {
    try {
      await _channel?.sink.close();
    } catch (e, stack) {
      stderr.writeln('[WebSocketTransport] disconnect error: $e\n$stack');
    }
    _channel = null;
  }

  Future<void> dispose() async {
    await disconnect();
    await _messageController.close();
  }
}
