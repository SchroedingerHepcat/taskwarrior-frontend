import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flutter_app/main.dart';
import 'package:flutter_app/models/shell_models.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shell loads and exposes all primary sections', (tester) async {
    await tester.pumpWidget(
      TaskwarriorFrontendApp(
        backend: LocalDevelopmentBackendClient(
          latency: Duration.zero,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Configurable dashboard placeholder'), findsOneWidget);

    await tester.tap(find.byIcon(ShellSection.tasks.icon));
    await tester.pumpAndSettle();
    expect(find.text('Server-authoritative task list'), findsOneWidget);

    await tester.tap(find.byIcon(ShellSection.board.icon));
    await tester.pumpAndSettle();
    expect(find.text('Kanban-style board placeholder'), findsOneWidget);

    await tester.tap(find.byIcon(ShellSection.detail.icon));
    await tester.pumpAndSettle();
    expect(find.text('Backend integration points'), findsOneWidget);
  });
}
