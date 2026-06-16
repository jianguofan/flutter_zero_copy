import 'dart:async';

/// Type-safe application event bus.
///
/// Features publish-subscribe for decoupled communication between
/// features (e.g., device connection events → UI updates).
///
/// Usage:
/// ```dart
/// final bus = EventBus();
/// final sub = bus.on<DeviceConnected>((e) => print(e.deviceId));
/// bus.fire(DeviceConnected('printer-1'));
/// sub.cancel(); // unsubscribe
/// ```
class EventBus {
  final Map<Type, List<_Handler>> _handlers = {};

  /// Listen for events of type [T].
  StreamSubscription<T> on<T>(void Function(T event) callback) {
    final handler = _Handler<T>(callback);
    _handlers.putIfAbsent(T, () => []).add(handler);
    return _Subscription<T>(handler, this);
  }

  /// Fire an event to all listeners of its type.
  void fire<T>(T event) {
    final handlers = _handlers[T];
    if (handlers == null) return;

    for (final handler in handlers) {
      (handler as _Handler<T>).callback(event);
    }
  }

  /// Remove a specific handler.
  void _removeHandler(Type type, _Handler handler) {
    final handlers = _handlers[type];
    if (handlers != null) {
      handlers.remove(handler);
      if (handlers.isEmpty) _handlers.remove(type);
    }
  }

  /// Clear all subscriptions.
  void dispose() {
    _handlers.clear();
  }
}

// ── Internal ──

class _Handler<T> {
  final void Function(T event) callback;
  _Handler(this.callback);
}

class _Subscription<T> implements StreamSubscription<T> {
  final _Handler<T> _handler;
  final EventBus _bus;
  bool _canceled = false;

  _Subscription(this._handler, this._bus);

  @override
  Future<void> cancel() async {
    if (!_canceled) {
      _canceled = true;
      _bus._removeHandler(T, _handler);
    }
  }

  @override
  void onData(void Function(T data)? handleData) {}

  @override
  void onError(Function? handleError) {}

  @override
  void onDone(void Function()? handleDone) {}

  @override
  bool get isPaused => false;

  @override
  void pause([Future<void>? resumeSignal]) {}

  @override
  void resume() {}

  @override
  Future<E> asFuture<E>([E? futureValue]) async => futureValue as E;
}
