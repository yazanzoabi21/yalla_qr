import 'dart:async';

/// Simple event bus for cross-widget notifications.
/// Use EventBus.emit('orders:updated') to notify listeners.
class EventBus {
  static final StreamController<String> _controller = StreamController<String>.broadcast();

  static Stream<String> get stream => _controller.stream;

  static void emit(String event) {
    try {
      _controller.add(event);
    } catch (_) {}
  }

  static void dispose() {
    _controller.close();
  }
}
