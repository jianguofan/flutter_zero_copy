import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_zero_copy/shared/errors/app_error.dart';
import 'package:flutter_zero_copy/shared/logger/logger.dart';

/// Global error handler — catches unhandled exceptions and surfaces them
/// in a user-friendly way.
class GlobalErrorHandler {
  final IAppLogger _logger;

  GlobalErrorHandler({required IAppLogger logger}) : _logger = logger {
    _setupFlutterErrorHandler();
    _setupZoneErrorHandler();
  }

  /// Install Flutter framework error handler.
  void _setupFlutterErrorHandler() {
    FlutterError.onError = (FlutterErrorDetails details) {
      // Log to our logger
      _logger.error(
        'Flutter error: ${details.exception}',
        details.exception,
        details.stack,
      );

      // Still call the default handler in debug mode for visibility
      FlutterError.presentError(details);
    };
  }

  /// Install zone-level handler for async errors.
  void _setupZoneErrorHandler() {
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      final appError = AppError.fromException(error, stack);
      _logger.error('Unhandled zone error: ${appError.message}',
          appError.originalError, appError.stackTrace);
      return true; // Handled
    };
  }

  /// Show a user-friendly error dialog.
  static Future<void> showErrorDialog(
    BuildContext context,
    AppError error, {
    VoidCallback? onRetry,
  }) {
    final isRecoverable = error.severity == ErrorSeverity.recoverable;

    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              error.severity == ErrorSeverity.fatal
                  ? Icons.error
                  : Icons.warning_amber,
              color: error.severity == ErrorSeverity.fatal
                  ? Colors.red
                  : Colors.orange,
            ),
            const SizedBox(width: 8),
            Text(error.severity == ErrorSeverity.fatal
                ? 'Error'
                : 'Something went wrong'),
          ],
        ),
        content: Text(error.message),
        actions: [
          if (isRecoverable && onRetry != null)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                onRetry();
              },
              child: const Text('Retry'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Show a lightweight error via SnackBar.
  static void showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade800,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }
}
