import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flutter_app/main.dart';
import 'package:flutter_app/models/shell_models.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shell drives create update and complete over HTTP',
      (tester) async {
    final server = await _RustServer.start();
    addTearDown(server.stop);

    await tester.pumpWidget(
      TaskwarriorFrontendApp(
        backend: HttpTaskBackendClient(baseUrl: server.baseUrl),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(ShellSection.tasks.icon));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('create-task-field')),
      'Milestone 4 integration task',
    );
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(find.text('Milestone 4 integration task'), findsWidgets);

    await tester.tap(find.text('Milestone 4 integration task').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open details').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('detail-project-field')),
      'frontend',
    );
    await tester.enterText(
      find.byKey(const Key('detail-tags-field')),
      'demo, integration',
    );
    await tester.enterText(
      find.byKey(const Key('detail-annotation-field')),
      'ready to complete',
    );
    await tester.tap(find.byKey(const Key('detail-add-note-button')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const Key('task-detail-screen')),
        matching: find.text('ready to complete'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('detail-toggle-status-button')));
    await tester.pumpAndSettle();

    expect(find.text('Reopen'), findsOneWidget);

    await tester.tap(find.byIcon(ShellSection.tasks.icon));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('task-list-mode-completed')));
    await tester.pumpAndSettle();

    expect(find.text('Milestone 4 integration task'), findsWidgets);
  });
}

class _RustServer {
  _RustServer({
    required this.baseUrl,
    required Process process,
  }) : _process = process;

  final String baseUrl;
  final Process _process;

  static Future<_RustServer> start() async {
    final port = 38080;
    final process = await Process.start(
      'cargo',
      <String>['run', '-p', 'server', '--', '--port', '$port'],
      workingDirectory: '../rust',
      runInShell: true,
    );

    final server = _RustServer(
      baseUrl: 'http://127.0.0.1:$port',
      process: process,
    );
    await server._waitUntilHealthy();
    return server;
  }

  Future<void> stop() async {
    _process.kill();
    try {
      await _process.exitCode.timeout(const Duration(seconds: 5));
    } on TimeoutException {
      _process.kill(ProcessSignal.sigkill);
    }
  }

  Future<void> _waitUntilHealthy() async {
    final client = HttpClient();

    for (var attempt = 0; attempt < 40; attempt += 1) {
      try {
        final request = await client.getUrl(Uri.parse('$baseUrl/health'));
        final response = await request.close();
        if (response.statusCode == 200) {
          client.close(force: true);
          return;
        }
      } catch (_) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    }

    client.close(force: true);
    throw StateError('Rust server did not become healthy');
  }
}
