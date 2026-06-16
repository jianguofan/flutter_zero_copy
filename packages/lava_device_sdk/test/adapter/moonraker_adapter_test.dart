import 'dart:convert';
import 'dart:typed_data';
import 'package:lava_device_sdk/src/adapter/adapter.dart';
import 'package:lava_device_sdk/src/adapter/moonraker/moonraker_adapter.dart';
import 'package:lava_device_sdk/src/adapter/moonraker/moonraker_config.dart';
import 'package:lava_device_sdk/src/core/schema.dart';
import 'package:lava_device_sdk/src/core/state_tree.dart';
import 'package:test/test.dart';

DeviceSchema _testSchema() {
  return DeviceSchema.fromJson(jsonDecode(_testJson) as Map<String, dynamic>);
}

void main() {
  group('MoonrakerAdapter status handling', () {
    late MoonrakerAdapter adapter;
    late StateTree state;
    late DeviceSchema schema;

    setUp(() {
      schema = _testSchema();
      adapter = MoonrakerAdapter(config: MoonrakerConfig.fromDataSource(schema.dataSource));
      state = StateTree(schema: schema);

      // Simulate onConnected
      final schemaRef = DeviceSchemaRef(
        lookup: (key) {
          final field = schema.lookup(key);
          return field != null ? <String, dynamic>{} : null;
        },
        keysByPrefix: schema.keysByPrefix,
        dataSource: schema.dataSource,
      );
      // Don't await in setUp, just start process
      adapter.onConnected(state, schemaRef);
    });

    tearDown(() {
      adapter.dispose();
      state.dispose();
    });

    test('parses /status payload and patches state tree', () {
      final statusPayload = jsonEncode({
        'jsonrpc': '2.0',
        'method': 'notify_status_update',
        'params': [
          {
            'eventtime': 1234.5,
            'status': {
              'extruder': {'temperature': 210.5, 'target': 200.0},
            },
          }
        ],
      });

      adapter.onMessage('/status', Uint8List.fromList(utf8.encode(statusPayload)));

      expect(state.get<num>('extruder.temperature'), 210.5);
      expect(state.get<num>('extruder.target'), 200.0);
    });

    test('parses nested object tree in /status', () {
      final statusPayload = jsonEncode({
        'jsonrpc': '2.0',
        'method': 'notify_status_update',
        'params': [
          {
            'eventtime': 1234.5,
            'status': {
              'toolhead': {'position': [100, 150, 25, 0.5]},
              'print_stats': {'state': 'printing'},
            },
          }
        ],
      });

      adapter.onMessage('/status', Uint8List.fromList(utf8.encode(statusPayload)));

      expect(state.get<List>('toolhead.position'), [100, 150, 25, 0.5]);
      expect(state.get<String>('print_stats.state'), 'printing');
    });

    test('ignores unknown topics', () {
      final payload = Uint8List.fromList(utf8.encode('{"foo": "bar"}'));
      // Should not throw
      adapter.onMessage('/unknown', payload);
    });
  });

  group('MoonrakerAdapter JSON-RPC send/response', () {
    late MoonrakerAdapter adapter;
    late StateTree state;
    late DeviceSchema schema;

    setUp(() {
      schema = _testSchema();
      adapter = MoonrakerAdapter(config: MoonrakerConfig.fromDataSource(schema.dataSource));
      state = StateTree(schema: schema);
    });

    tearDown(() {
      adapter.dispose();
      state.dispose();
    });

    test('send produces JSON-RPC formatted outgoing message', () async {
      final outgoingFut = adapter.outgoing.first;

      adapter.send('printer.gcode.script', {'script': 'G28'});

      final outgoing = await outgoingFut;
      final payloadStr = utf8.decode(outgoing.$2);

      expect(outgoing.$1, '/request');
      final json = jsonDecode(payloadStr) as Map<String, dynamic>;
      expect(json['jsonrpc'], '2.0');
      expect(json['method'], 'printer.gcode.script');
      expect(json['params'], {'script': 'G28'});
      expect(json['id'], isA<int>());

      // Complete the pending request so dispose doesn't error
      final responsePayload = jsonEncode({
        'jsonrpc': '2.0',
        'id': json['id'],
        'result': {'status': 'ok'},
      });
      adapter.onMessage(
        '/response',
        Uint8List.fromList(utf8.encode(responsePayload)),
      );
    });

    test('/response completes pending send()', () async {
      // Listen for outgoing to capture the request id
      final outgoingFut = adapter.outgoing.first;

      final responseFut = adapter.send('printer.print.pause');

      // Wait for the outgoing message
      final outgoing = await outgoingFut;
      final payloadStr = utf8.decode(outgoing.$2);
      final requestJson = jsonDecode(payloadStr) as Map<String, dynamic>;
      final requestId = requestJson['id'] as int;

      // Simulate receiving the response
      final responsePayload = jsonEncode({
        'jsonrpc': '2.0',
        'id': requestId,
        'result': {'status': 'ok'},
      });
      adapter.onMessage('/response', Uint8List.fromList(utf8.encode(responsePayload)));

      final result = await responseFut;
      expect(result, {'status': 'ok'});
    });

    test('/response with error completes with error payload', () async {
      final outgoingFut = adapter.outgoing.first;

      final responseFut = adapter.send('printer.gcode.script', {'script': 'INVALID'});

      final outgoing = await outgoingFut;
      final payloadStr = utf8.decode(outgoing.$2);
      final requestJson = jsonDecode(payloadStr) as Map<String, dynamic>;
      final requestId = requestJson['id'] as int;

      // Simulate receiving an error response
      final responsePayload = jsonEncode({
        'jsonrpc': '2.0',
        'id': requestId,
        'error': {'code': -1, 'message': 'Unknown command'},
      });
      adapter.onMessage('/response', Uint8List.fromList(utf8.encode(responsePayload)));

      final result = await responseFut;
      expect(result, {'code': -1, 'message': 'Unknown command'});
    });
  });
}

const _testJson = '''
{
  "version": "1.0",
  "deviceType": "test",
  "fields": {
    "extruder.temperature": {
      "type": "number",
      "default": 0,
      "validate": {"min": 0, "max": 500},
      "strategy": "replace"
    },
    "extruder.target": {
      "type": "number",
      "default": 0,
      "validate": {"min": 0, "max": 500},
      "strategy": "replace"
    },
    "toolhead.position": {
      "type": "array",
      "default": [0, 0, 0, 0]
    },
    "print_stats.state": {
      "type": "string",
      "default": "idle"
    }
  },
  "dataSource": {
    "type": "moonraker",
    "subscribe": {
      "extruder": ["temperature", "target"],
      "toolhead": null,
      "print_stats": null
    },
    "responseTopic": "/response",
    "statusTopic": "/status"
  }
}
''';
