import 'package:lava_device_sdk/src/adapter/adapter.dart';
import 'package:lava_device_sdk/src/adapter/moonraker/moonraker_adapter.dart';
import 'package:lava_device_sdk/src/adapter/moonraker/moonraker_config.dart';
import 'package:lava_device_sdk/src/core/schema.dart';
import 'package:lava_device_sdk/src/core/state_tree.dart';
import 'package:lava_device_sdk/src/models/connection_state.dart';
import 'package:lava_device_sdk/src/models/types.dart';
import 'package:lava_device_sdk/src/mqtt/mqtt_transport.dart';
import 'package:lava_device_sdk/src/transport/transport.dart';

class DeviceClient {
  final DeviceSchema _schema;
  final StateTree _state;
  final DeviceTransport _transport;
  final DeviceAdapter _adapter;

  DeviceClient({
    required DeviceSchema schema,
    required DeviceAdapter adapter,
    required DeviceTransport transport,
  })  : _schema = schema,
        _state = StateTree(schema: schema),
        _transport = transport,
        _adapter = adapter;

  /// Create a client for Moonraker + MQTT (convenience factory).
  factory DeviceClient.moonraker({
    required DeviceSchema schema,
    required MqttConfig mqttConfig,
  }) {
    final moonrakerConfig = MoonrakerConfig.fromDataSource(schema.dataSource);

    // Ensure the notification topic (if configured) is in the MQTT subscribe list
    final subscribeTopics = List<String>.from(mqttConfig.subscribeTopics);
    final notifTopic = moonrakerConfig.notificationTopic;
    if (notifTopic != null && !subscribeTopics.contains(notifTopic)) {
      subscribeTopics.add(notifTopic);
    }

    return DeviceClient(
      schema: schema,
      adapter: MoonrakerAdapter(config: moonrakerConfig),
      transport: MqttTransport(config: MqttConfig(
        host: mqttConfig.host,
        port: mqttConfig.port,
        clientId: mqttConfig.clientId,
        username: mqttConfig.username,
        password: mqttConfig.password,
        subscribeTopics: subscribeTopics,
      )),
    );
  }

  DeviceSchema get schema => _schema;
  StateTree get state => _state;
  DeviceTransport get transport => _transport;

  bool get isConnected => _transport.isConnected;

  /// Stream of connection state changes.
  /// Delegates to the underlying transport.
  Stream<ConnectionState> get connectionState => _transport.connectionState;

  Future<void> connect() async {
    // Listen for outgoing adapter messages → transport send
    _adapter.outgoing.listen((msg) {
      _transport.send(msg.$1, msg.$2);
    });

    // Listen for incoming transport messages → adapter
    _transport.messageStream.listen((msg) {
      _adapter.onMessage(msg.topic, msg.payload);
    });

    // Connect transport
    await _transport.connect();

    // Notify adapter
    final schemaRef = DeviceSchemaRef(
      lookup: (key) {
        final field = _schema.lookup(key);
        if (field == null) return null;
        return {
          'type': field.type.name,
          'default': field.defaultValue,
          'readonly': field.readonly,
          'strategy': field.strategy.name,
          'min': field.min,
          'max': field.max,
          'enumValues': field.enumValues,
        };
      },
      keysByPrefix: _schema.keysByPrefix,
      dataSource: _schema.dataSource,
    );
    await _adapter.onConnected(_state, schemaRef);
  }

  Future<void> disconnect() async {
    await _adapter.dispose();
    await _transport.disconnect();
    _state.reset(_schema);
  }

  Future<Map<String, dynamic>?> send(String method, [Map<String, dynamic>? params]) {
    return _adapter.send(method, params);
  }

  Future<void> dispose() async {
    await _adapter.dispose();
    await _transport.dispose();
    _state.dispose();
  }
}
