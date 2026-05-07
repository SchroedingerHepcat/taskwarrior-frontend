import 'dart:convert';

import 'package:flutter_app/backend/http_task_backend_client.dart';
import 'package:flutter_app/models/shell_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('updateTask submits recurrence properties to backend', () async {
    Map<String, dynamic>? requestBody;
    final client = HttpTaskBackendClient(
      baseUrl: 'http://127.0.0.1:8080',
      client: MockClient((request) async {
        expect(request.method, 'PATCH');
        expect(request.url.path, '/tasks/task-1');
        requestBody = jsonDecode(request.body) as Map<String, dynamic>;

        return http.Response(
          jsonEncode(<String, dynamic>{
            'task': <String, dynamic>{
              'id': 'task-1',
              'description': 'Review schedule',
              'project': null,
              'status': 'pending',
              'tags': <String>[],
              'annotations': <Map<String, dynamic>>[],
              'entry': null,
              'modified': null,
              'due': null,
              'scheduled': null,
              'wait': null,
              'end': null,
              'recurrence': <String, dynamic>{
                'recur': '2weeks',
                'rtype': 'periodic',
                'until': '2026-05-08T00:00:00.000Z',
                'parent': '11111111-1111-1111-1111-111111111111',
                'mask': '+',
                'imask': '-',
              },
            },
          }),
          200,
        );
      }),
    );

    final task = await client.updateTask(
      'task-1',
      UpdateTaskInput(
        recurrence: TaskRecurrence(
          recur: '2weeks',
          rtype: 'periodic',
          until: DateTime.utc(2026, 5, 8),
          parent: '11111111-1111-1111-1111-111111111111',
          mask: '+',
          imask: '-',
        ),
      ),
    );

    expect(requestBody?['clear_recurrence'], isFalse);
    expect(requestBody?['recurrence'], <String, dynamic>{
      'recur': '2weeks',
      'rtype': 'periodic',
      'until': '2026-05-08T00:00:00.000Z',
      'parent': '11111111-1111-1111-1111-111111111111',
      'mask': '+',
      'imask': '-',
    });
    expect(task.recurrence?.recur, '2weeks');
    expect(task.recurrence?.rtype, 'periodic');
    expect(task.recurrence?.until, DateTime.utc(2026, 5, 8));
  });
}
