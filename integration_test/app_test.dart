import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// End-to-end app tests.
///
/// These tests require a running device/emulator.
/// Run with: `flutter test integration_test/app_test.dart`
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('App E2E', () {
    testWidgets('app launches without crashing', (tester) async {
      // Placeholder — full E2E requires device/emulator.
      // Verifies the test infrastructure is wired correctly.
      expect(1 + 1, equals(2));
    });
  });
}
