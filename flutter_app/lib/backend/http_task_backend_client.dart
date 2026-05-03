import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/shell_models.dart';
import 'task_backend_client.dart';

class HttpTaskBackendClient implements TaskBackendClient {
  HttpTaskBackendClient({
    required String baseUrl,
    http.Client? client,
  })  : _baseUrl = baseUrl,
        _client = client ?? http.Client();

  final String _baseUrl;
  final http.Client _client;

  Uri _uri(String path) => Uri.parse('$_baseUrl$path');

  @override
  Future<BackendHealth> healthcheck() async {
    final response = await _client.get(_uri('/health'));
    _ensureSuccess(response);
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;

    return BackendHealth(
      label: 'HTTP backend ready',
      environment: decoded['status'] as String? ?? 'ok',
    );
  }

  @override
  Future<TaskItem> createTask(CreateTaskInput input) async {
    final response = await _client.post(
      _uri('/tasks'),
      headers: _jsonHeaders,
      body: jsonEncode(<String, dynamic>{
        'description': input.description,
      }),
    );
    _ensureSuccess(response);

    return _decodeTaskResponse(response.body);
  }

  @override
  Future<TaskItem> getTask(String taskId) async {
    final response = await _client.get(_uri('/tasks/$taskId'));
    _ensureSuccess(response);

    return _decodeTaskResponse(response.body);
  }

  @override
  Future<List<TaskItem>> queryTasks(TaskQuery query) async {
    final response = await _client.post(
      _uri('/tasks/query'),
      headers: _jsonHeaders,
      body: jsonEncode(<String, dynamic>{
        'statuses': query.statuses.map((status) => status.apiValue).toList(),
        'required_tag': query.requiredTag,
        'due_before': query.dueBefore?.toUtc().toIso8601String(),
        'include_waiting': query.includeWaiting,
        'reference_time': query.referenceTime.toUtc().toIso8601String(),
        'sort': query.sort.apiValue,
      }),
    );
    _ensureSuccess(response);
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;

    return (decoded['tasks'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(_decodeTask)
        .toList();
  }

  @override
  Future<TaskItem> transitionTask(
    String taskId,
    TaskTransitionInput input,
  ) async {
    final response = await _client.post(
      _uri('/tasks/$taskId/transition'),
      headers: _jsonHeaders,
      body: jsonEncode(<String, dynamic>{
        'status': input.status.apiValue,
      }),
    );
    _ensureSuccess(response);

    return _decodeTaskResponse(response.body);
  }

  @override
  Future<TaskItem> updateTask(
    String taskId,
    UpdateTaskInput input,
  ) async {
    final response = await _client.patch(
      _uri('/tasks/$taskId'),
      headers: _jsonHeaders,
      body: jsonEncode(<String, dynamic>{
        'description': input.description,
        'project': input.project,
        'clear_project': input.clearProject,
        'tags': input.tags,
        'due': input.due?.toUtc().toIso8601String(),
        'clear_due': input.clearDue,
        'wait': input.waitUntil?.toUtc().toIso8601String(),
        'clear_wait': input.clearWait,
        'add_annotation': input.addAnnotation,
      }),
    );
    _ensureSuccess(response);

    return _decodeTaskResponse(response.body);
  }

  Map<String, String> get _jsonHeaders => <String, String>{
        'content-type': 'application/json',
      };

  TaskItem _decodeTaskResponse(String body) {
    final decoded = jsonDecode(body) as Map<String, dynamic>;
    final task = decoded['task'] as Map<String, dynamic>;

    return _decodeTask(task);
  }

  TaskItem _decodeTask(Map<String, dynamic> json) {
    return TaskItem(
      id: json['id'] as String,
      title: json['description'] as String,
      project: json['project'] as String?,
      status: TaskStatus.fromApi(json['status'] as String),
      tags: (json['tags'] as List<dynamic>).cast<String>(),
      annotations: (json['annotations'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(
            (annotation) => TaskAnnotation(
              entry: DateTime.parse(annotation['entry'] as String).toUtc(),
              description: annotation['description'] as String,
            ),
          )
          .toList(),
      entry: _dateTimeOrNull(json['entry']),
      modified: _dateTimeOrNull(json['modified']),
      due: _dateTimeOrNull(json['due']),
      waitUntil: _dateTimeOrNull(json['wait']),
      end: _dateTimeOrNull(json['end']),
    );
  }

  DateTime? _dateTimeOrNull(Object? raw) {
    if (raw == null) {
      return null;
    }

    return DateTime.parse(raw as String).toUtc();
  }

  void _ensureSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    throw StateError(
      'HTTP ${response.statusCode}: ${response.body}',
    );
  }
}
