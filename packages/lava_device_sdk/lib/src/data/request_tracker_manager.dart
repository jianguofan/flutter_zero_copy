import 'dart:async';

/// State of a tracked request.
enum RequestState { pending, success, timeout, failed }

/// A single tracked request.
class RequestTracker {
  final String id;
  final Completer<Map<String, dynamic>> completer;
  DateTime expiresAt;
  RequestState state;

  RequestTracker({
    required this.id,
    required this.completer,
    required this.expiresAt,
    this.state = RequestState.pending,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// Manages async request tracking with a single global cleanup timer.
///
/// Replaces the per-request Timer pattern (N requests = N timers) with
/// a single periodic scan that cleans up expired requests. For device
/// control scenarios where timeouts are typically 10+ seconds, the 1-second
/// scan granularity is perfectly acceptable.
///
/// Performance:
/// - 1000 concurrent requests → 1 Timer (vs 1000 in the old model)
/// - Memory: ~100 bytes per tracker (DateTime + Completer ref)
class RequestTrackerManager {
  final Map<String, RequestTracker> _trackers = {};
  Timer? _cleanupTimer;

  /// Start the cleanup timer. Call once after creating the manager.
  void start() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _cleanupExpiredRequests();
    });
  }

  /// Register a new request and return its future.
  ///
  /// [id] should be a unique request identifier (e.g., JSON-RPC seqId).
  /// [timeout] is the maximum time to wait before the request is
  /// considered timed out.
  Future<Map<String, dynamic>> track({
    required String id,
    required Duration timeout,
  }) {
    final tracker = RequestTracker(
      id: id,
      completer: Completer<Map<String, dynamic>>(),
      expiresAt: DateTime.now().add(timeout),
    );
    _trackers[id] = tracker;
    return tracker.completer.future;
  }

  /// Complete a tracked request with a successful response.
  ///
  /// No-ops silently if the request is not found, already completed,
  /// or already timed out.
  void complete(String id, Map<String, dynamic> response) {
    final tracker = _trackers[id];
    if (tracker == null) return;
    if (tracker.state != RequestState.pending) return;

    tracker.state = RequestState.success;
    if (!tracker.completer.isCompleted) {
      tracker.completer.complete(response);
    }
    _trackers.remove(id);
  }

  /// Fail a tracked request with an error.
  void completeError(String id, Object error) {
    final tracker = _trackers[id];
    if (tracker == null) return;
    if (tracker.state != RequestState.pending) return;

    tracker.state = RequestState.failed;
    if (!tracker.completer.isCompleted) {
      tracker.completer.completeError(error);
    }
    _trackers.remove(id);
  }

  /// Return the number of currently pending requests.
  int get pendingCount =>
      _trackers.values.where((t) => t.state == RequestState.pending).length;

  /// Return total number of tracked requests (pending + inflight cleanup).
  int get totalCount => _trackers.length;

  /// Stop the cleanup timer and complete all pending requests with an error.
  void stop() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;

    for (final tracker in _trackers.values) {
      if (tracker.state == RequestState.pending &&
          !tracker.completer.isCompleted) {
        tracker.state = RequestState.timeout;
        tracker.completer.completeError(
          TimeoutException('RequestTrackerManager stopped'),
        );
      }
    }
    _trackers.clear();
  }

  /// Extend the timeout of all currently pending requests by [extension].
  ///
  /// Used when link quality degrades to avoid prematurely timing out
  /// commands that are still in flight (delayed by packet loss / retransmission).
  ///
  /// Already-expired trackers are given a grace period from now.
  void extendAllPending(Duration extension) {
    final now = DateTime.now();
    for (final tracker in _trackers.values) {
      if (tracker.state != RequestState.pending) continue;
      if (now.isBefore(tracker.expiresAt)) {
        tracker.expiresAt = tracker.expiresAt.add(extension);
      } else {
        // Already past the original deadline — grant a grace period
        tracker.expiresAt = now.add(extension);
      }
    }
  }

  void dispose() => stop();

  // ── internal ──

  void _cleanupExpiredRequests() {
    final now = DateTime.now();
    _trackers.removeWhere((id, tracker) {
      // Remove already-completed trackers
      if (tracker.state != RequestState.pending) return true;

      // Time out expired pending trackers
      if (now.isAfter(tracker.expiresAt)) {
        tracker.state = RequestState.timeout;
        if (!tracker.completer.isCompleted) {
          tracker.completer.completeError(
            TimeoutException('Request $id timed out'),
          );
        }
        return true;
      }

      return false; // Keep pending, non-expired trackers
    });
  }
}
