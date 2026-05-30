import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flutter_app/main.dart';
import 'package:flutter_app/models/shell_models.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shell renders core workflows across platforms', (tester) async {
    await tester.pumpWidget(
      TaskwarriorFrontendApp(
        backend: LocalDevelopmentBackendClient(
          latency: Duration.zero,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dashboard-screen')), findsOneWidget);
    expect(find.text('Dashboard'), findsWidgets);
    expect(find.byKey(const Key('sync-status-button')), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(ShellSection.tasks.icon));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('task-list-screen')), findsOneWidget);
    expect(find.byKey(const Key('create-task-field')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('create-task-field')),
      'Cross-platform parity task',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('Cross-platform parity task'), findsWidgets);

    await tester.tap(find.byIcon(ShellSection.board.icon));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('board-screen')), findsOneWidget);

    await tester.tap(find.byIcon(ShellSection.settings.icon));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('settings-screen')), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide shell columns remain visually separated', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      TaskwarriorFrontendApp(
        backend: LocalDevelopmentBackendClient(
          latency: Duration.zero,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final rail = tester.getRect(
      find.byKey(const Key('desktop-rail-column')),
    );
    final navigation = tester.getRect(
      find.byKey(const Key('desktop-navigation')),
    );
    final main = tester.getRect(
      find.byKey(const Key('desktop-main-column')),
    );
    final context = tester.getRect(
      find.byKey(const Key('desktop-context-column')),
    );

    expect(navigation.left, greaterThanOrEqualTo(rail.left));
    expect(navigation.right, lessThanOrEqualTo(rail.right));
    expect(rail.right, lessThanOrEqualTo(main.left));
    expect(main.right, lessThanOrEqualTo(context.left));
    expect(context.right, tester.view.physicalSize.width);
    expect(tester.takeException(), isNull);
  });
}
