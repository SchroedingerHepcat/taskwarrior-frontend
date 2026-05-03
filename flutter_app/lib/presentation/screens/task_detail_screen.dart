import 'package:flutter/material.dart';

import '../../app/shell_controller.dart';
import '../../models/shell_models.dart';

class TaskDetailScreen extends StatefulWidget {
  const TaskDetailScreen({
    super.key,
    required this.controller,
    required this.showContextHeader,
  });

  final ShellController controller;
  final bool showContextHeader;

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  late final TextEditingController _descriptionController;
  late final TextEditingController _projectController;
  late final TextEditingController _tagsController;
  late final TextEditingController _dueController;
  late final TextEditingController _waitController;
  late final TextEditingController _annotationController;
  String? _boundTaskId;

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController();
    _projectController = TextEditingController();
    _tagsController = TextEditingController();
    _dueController = TextEditingController();
    _waitController = TextEditingController();
    _annotationController = TextEditingController();
    _bindTask();
  }

  @override
  void didUpdateWidget(covariant TaskDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _bindTask();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _projectController.dispose();
    _tagsController.dispose();
    _dueController.dispose();
    _waitController.dispose();
    _annotationController.dispose();
    super.dispose();
  }

  void _bindTask() {
    final task = widget.controller.selectedTask;
    if (task == null || task.id == _boundTaskId) {
      return;
    }

    _boundTaskId = task.id;
    _descriptionController.text = task.title;
    _projectController.text = task.project ?? '';
    _tagsController.text = task.tags.join(', ');
    _dueController.text = _dateField(task.due);
    _waitController.text = _dateField(task.waitUntil);
    _annotationController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.controller.selectedTask;

    return ListView(
      key: const Key('task-detail-screen'),
      children: <Widget>[
        if (widget.showContextHeader) ...<Widget>[
          Text(
            'Task detail',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
        ],
        if (task == null)
          const Text('Select a task from the dashboard or list.')
        else ...<Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  TextField(
                    key: const Key('detail-description-field'),
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('detail-project-field'),
                    controller: _projectController,
                    decoration: const InputDecoration(
                      labelText: 'Project',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('detail-tags-field'),
                    controller: _tagsController,
                    decoration: const InputDecoration(
                      labelText: 'Tags',
                      hintText: 'comma,separated',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('detail-due-field'),
                    controller: _dueController,
                    decoration: const InputDecoration(
                      labelText: 'Due date',
                      hintText: 'YYYY-MM-DD',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('detail-wait-field'),
                    controller: _waitController,
                    decoration: const InputDecoration(
                      labelText: 'Wait until',
                      hintText: 'YYYY-MM-DD',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('detail-annotation-field'),
                    controller: _annotationController,
                    decoration: const InputDecoration(
                      labelText: 'Add annotation',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: <Widget>[
                      FilledButton(
                        key: const Key('detail-save-button'),
                        onPressed: widget.controller.isSaving
                            ? null
                            : () async {
                                final note = _annotationController.text.trim();
                                await widget.controller.updateSelectedTask(
                                  UpdateTaskInput(
                                    description:
                                        _descriptionController.text.trim(),
                                    project:
                                        _projectController.text.trim().isEmpty
                                            ? null
                                            : _projectController.text.trim(),
                                    clearProject:
                                        _projectController.text.trim().isEmpty,
                                    tags: _parseTags(_tagsController.text),
                                    due: _parseDate(_dueController.text),
                                    clearDue:
                                        _dueController.text.trim().isEmpty,
                                    waitUntil: _parseDate(_waitController.text),
                                    clearWait:
                                        _waitController.text.trim().isEmpty,
                                    addAnnotation: note.isEmpty ? null : note,
                                  ),
                                );
                                if (mounted) {
                                  _annotationController.clear();
                                }
                              },
                        child: const Text('Save'),
                      ),
                      OutlinedButton(
                        key: const Key('detail-toggle-status-button'),
                        onPressed: widget.controller.isSaving
                            ? null
                            : () async {
                                final next = task.status == TaskStatus.completed
                                    ? TaskStatus.pending
                                    : TaskStatus.completed;
                                await widget.controller.transitionSelectedTask(
                                  next,
                                );
                              },
                        child: Text(
                          task.status == TaskStatus.completed
                              ? 'Reopen'
                              : 'Complete',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Annotations',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  if (task.annotations.isEmpty)
                    const Text('No annotations yet.')
                  else
                    for (final annotation in task.annotations.reversed)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(annotation.description),
                        subtitle: Text(annotation.entry.toIso8601String()),
                      ),
                  if (widget.controller.boardIntent != null) ...<Widget>[
                    const SizedBox(height: 16),
                    Text(widget.controller.boardIntent!),
                  ],
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  List<String> _parseTags(String raw) {
    return raw
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList();
  }

  DateTime? _parseDate(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    return DateTime.parse('${trimmed}T00:00:00Z').toUtc();
  }

  String _dateField(DateTime? date) {
    if (date == null) {
      return '';
    }

    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
