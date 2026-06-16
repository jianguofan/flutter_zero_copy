library lava_device_sdk;

// Core (protocol-agnostic)
export 'src/core/schema.dart' show DeviceSchema;
export 'src/core/state_tree.dart' show StateTree;
export 'src/core/state_patch.dart' show StatePatch;
export 'src/core/field_definition.dart' show FieldDefinition, FieldType, UpdateStrategy;
export 'src/core/validator.dart' show Validator, ValidationError;

// Transport (swap MQTT ↔ WebSocket)
export 'src/transport/transport.dart' show DeviceTransport, TransportMessage;
export 'src/transport/websocket_transport.dart' show WebSocketTransport, WebSocketConfig;

// Adapter (swap protocol)
export 'src/adapter/adapter.dart' show DeviceAdapter, DeviceSchemaRef, DeviceEvent, DeviceEventType;
export 'src/adapter/moonraker/moonraker_adapter.dart' show MoonrakerAdapter;
export 'src/adapter/moonraker/moonraker_config.dart' show MoonrakerConfig;
export 'src/adapter/moonraker/json_rpc.dart' show JsonRpcRequest, JsonRpcResponse;

// Client
export 'src/client/device_client.dart' show DeviceClient;

// MQTT (convenience)
export 'src/mqtt/mqtt_transport.dart' show MqttTransport;

// Models
export 'src/models/types.dart' show MqttConfig;

// Data Layer — metadata-driven state management + request tracking
export 'src/data/state_update_event.dart' show StateUpdateEvent;
export 'src/data/metadata_state_manager.dart' show MetadataStateManager;
export 'src/data/request_tracker_manager.dart'
    show RequestTracker, RequestTrackerManager, RequestState;

// Connection Layer — heartbeat + connection orchestration
export 'src/connection/smart_heartbeat_manager.dart' show SmartHeartbeatManager;
export 'src/connection/device_connection_manager.dart' show DeviceConnectionManager;
export 'src/connection/device_health_monitor.dart'
    show DeviceHealth, DeviceHealthMonitor, HealthChangeEvent, HealthChangeReason;
export 'src/connection/connection_strategy.dart'
    show ConnectionStrategy, ConnectionProgress;
export 'src/connection/lan_strategy.dart' show LanStrategy;
export 'src/connection/wan_strategy.dart' show WanStrategy, CloudApiClient, DeviceCertConfig;

// DeviceHub — unified connection entry point
export 'src/device_hub.dart' show DeviceHub;

// MqttCredentials
export 'src/models/mqtt_credentials.dart' show MqttCredentials;
