/// Unified state update event emitted by MetadataStateManager.
class StateUpdateEvent {
  final String key;
  final dynamic value;
  final DateTime timestamp;

  const StateUpdateEvent({
    required this.key,
    required this.value,
    required this.timestamp,
  });

  @override
  String toString() => 'StateUpdateEvent($key: $value)';
}
