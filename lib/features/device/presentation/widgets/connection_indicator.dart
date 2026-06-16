import 'package:flutter/material.dart';
import 'package:flutter_zero_copy/features/device/domain/interfaces/i_device_facade.dart';

/// Visual indicator for the 8-state [DeviceConnectionState] machine.
///
/// Each state maps to an icon + color + label for clear user feedback.
class ConnectionIndicator extends StatelessWidget {
  final DeviceConnectionState state;
  final double size;
  final bool showLabel;

  const ConnectionIndicator({
    super.key,
    required this.state,
    this.size = 16,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final (:icon, :color, :label) = _stateData(state);

    final indicator = Icon(icon, size: size, color: color);

    if (!showLabel) return indicator;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        indicator,
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: size * 0.75,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  ({IconData icon, Color color, String label}) _stateData(
      DeviceConnectionState state) {
    return switch (state) {
      DeviceConnectionState.idle => (
          icon: Icons.circle_outlined,
          color: Colors.grey,
          label: 'Idle',
        ),
      DeviceConnectionState.connecting => (
          icon: Icons.sync,
          color: Colors.orange,
          label: 'Connecting',
        ),
      DeviceConnectionState.handshaking => (
          icon: Icons.handshake,
          color: Colors.amber,
          label: 'Handshaking',
        ),
      DeviceConnectionState.connected => (
          icon: Icons.check_circle,
          color: const Color(0xFF00D4AA), // Snapmaker cyan
          label: 'Connected',
        ),
      DeviceConnectionState.degraded => (
          icon: Icons.warning_amber,
          color: Colors.orange,
          label: 'Degraded',
        ),
      DeviceConnectionState.reconnecting => (
          icon: Icons.refresh,
          color: Colors.lightBlue,
          label: 'Reconnecting',
        ),
      DeviceConnectionState.disconnected => (
          icon: Icons.cancel,
          color: Colors.red.shade300,
          label: 'Disconnected',
        ),
      DeviceConnectionState.failed => (
          icon: Icons.error,
          color: Colors.red,
          label: 'Failed',
        ),
    };
  }
}

/// Animated variant that reacts to connection state changes.
class AnimatedConnectionIndicator extends StatefulWidget {
  final DeviceConnectionState state;
  final double size;

  const AnimatedConnectionIndicator({
    super.key,
    required this.state,
    this.size = 20,
  });

  @override
  State<AnimatedConnectionIndicator> createState() =>
      _AnimatedConnectionIndicatorState();
}

class _AnimatedConnectionIndicatorState
    extends State<AnimatedConnectionIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animateIfActive(widget.state);
  }

  @override
  void didUpdateWidget(AnimatedConnectionIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _animateIfActive(widget.state);
    }
  }

  void _animateIfActive(DeviceConnectionState state) {
    if (state == DeviceConnectionState.connecting ||
        state == DeviceConnectionState.reconnecting) {
      _controller.repeat();
    } else {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: ConnectionIndicator(
        state: widget.state,
        size: widget.size,
        showLabel: false,
      ),
    );
  }
}
