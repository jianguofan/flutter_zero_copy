import 'dart:async';
import 'dart:math';
import 'package:flutter_zero_copy/shared/logger/logger.dart';

/// Configurable retry policy with exponential backoff and jitter.
class RetryPolicy {
  final Duration initialDelay;
  final Duration maxDelay;
  final double multiplier;
  final int maxRetries;
  final IAppLogger? logger;
  final Random _random = Random();

  RetryPolicy({
    this.initialDelay = const Duration(milliseconds: 500),
    this.maxDelay = const Duration(seconds: 10),
    this.multiplier = 1.5,
    this.maxRetries = 5,
    this.logger,
  });

  /// Execute [operation] with retry logic.
  ///
  /// Returns the result on success, or throws the last error after exhausting
  /// all retries. Supports cancellation via the returned [Future].
  Future<T> execute<T>(Future<T> Function() operation) async {
    var attempt = 0;
    var delay = initialDelay;

    while (true) {
      try {
        return await operation();
      } catch (e) {
        attempt++;
        if (attempt > maxRetries) {
          logger?.error('RetryPolicy: exhausted $maxRetries attempts', e);
          rethrow;
        }

        logger?.warn(
            'RetryPolicy: attempt $attempt/$maxRetries failed, '
            'retrying in ${delay.inMilliseconds}ms: $e');

        await Future<void>.delayed(delay);

        // Exponential backoff with jitter (±15%)
        final jitterFactor = 1.0 + (_random.nextDouble() - 0.5) * 0.3;
        delay = Duration(
          milliseconds: min(
            (delay.inMilliseconds * multiplier * jitterFactor).round(),
            maxDelay.inMilliseconds,
          ),
        );
      }
    }
  }

  /// Execute with retry, returning null on failure instead of throwing.
  Future<T?> tryExecute<T>(Future<T> Function() operation) async {
    try {
      return await execute(operation);
    } catch (_) {
      return null;
    }
  }
}
