import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/main.dart';

void main() {
  testWidgets('renders scaffold placeholder', (tester) async {
    await tester.pumpWidget(const TaskwarriorFrontendApp());

    expect(find.text('Taskwarrior Frontend'), findsOneWidget);
    expect(find.text('Compatibility spike scaffold'), findsOneWidget);
  });
}
