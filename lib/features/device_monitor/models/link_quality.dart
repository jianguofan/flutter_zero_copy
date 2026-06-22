/// 链路质量等级
enum LinkQuality { good, degraded, poor }

/// 链路质量变化事件
class LinkQualityEvent {
  final LinkQuality current;
  final LinkQuality previous;
  final int consecutiveCount;
  final Map<String, double> scores;
  final DateTime timestamp;

  LinkQualityEvent({
    required this.current,
    required this.previous,
    required this.consecutiveCount,
    Map<String, double>? scores,
    DateTime? timestamp,
  })  : scores = scores ?? {},
        timestamp = timestamp ?? DateTime.now();

  @override
  String toString() =>
      'LinkQualityEvent($previous → $current, count=$consecutiveCount)';
}
