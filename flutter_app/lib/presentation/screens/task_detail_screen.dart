import 'dart:async';

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
  Timer? _autosaveTimer;
  String? _boundTaskId;
  TaskItem? _undoSnapshot;
  bool _isBinding = false;

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController();
    _projectController = TextEditingController();
    _tagsController = TextEditingController();
    _dueController = TextEditingController();
    _waitController = TextEditingController();
    _annotationController = TextEditingController();
    for (final controller in <TextEditingController>[
      _descriptionController,
      _projectController,
      _tagsController,
      _dueController,
      _waitController,
    ]) {
      controller.addListener(_scheduleAutosave);
    }
    _bindTask();
  }

  @override
  void didUpdateWidget(covariant TaskDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _bindTask();
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
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

    _isBinding = true;
    _boundTaskId = task.id;
    _undoSnapshot = null;
    _descriptionController.text = task.title;
    _projectController.text = task.project ?? '';
    _tagsController.text = task.tags.join(', ');
    _dueController.text = _dateField(task.due);
    _waitController.text = _dateField(task.waitUntil);
    _annotationController.clear();
    _isBinding = false;
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
          _TaskDetailActions(
            canUndo: _undoSnapshot != null && !widget.controller.isSaving,
            isSaving: widget.controller.isSaving,
            onUndo: _undoChanges,
          ),
          const SizedBox(height: 12),
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
                    decoration: InputDecoration(
                      labelText: 'Due date',
                      hintText: 'YYYY-M-D',
                      suffixIcon: IconButton(
                        key: const Key('detail-due-picker-button'),
                        onPressed: () => _pickDate(_dueController),
                        icon: const Icon(Icons.calendar_month_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('detail-wait-field'),
                    controller: _waitController,
                    decoration: InputDecoration(
                      labelText: 'Wait until',
                      hintText: 'YYYY-M-D',
                      suffixIcon: IconButton(
                        key: const Key('detail-wait-picker-button'),
                        onPressed: () => _pickDate(_waitController),
                        icon: const Icon(Icons.calendar_month_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('detail-annotation-field'),
                    controller: _annotationController,
                    decoration: const InputDecoration(
                      labelText: 'Add annotation',
                      hintText: 'Press Enter to add note',
                    ),
                    onSubmitted: (_) => _addAnnotation(),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: <Widget>[
                      if (widget.controller.isSaving)
                        const Chip(
                          key: Key('detail-autosave-status'),
                          label: Text('Saving changes'),
                        )
                      else
                        const Chip(
                          key: Key('detail-autosave-status'),
                          label: Text('Changes save automatically'),
                        ),
                      OutlinedButton(
                        key: const Key('detail-add-note-button'),
                        onPressed:
                            widget.controller.isSaving ? null : _addAnnotation,
                        child: const Text('Add note'),
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

  void _scheduleAutosave() {
    if (_isBinding || _boundTaskId == null) {
      return;
    }

    final task = widget.controller.selectedTask;
    if (task == null) {
      return;
    }

    if (_undoSnapshot == null) {
      setState(() {
        _undoSnapshot = task;
      });
    }
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(
      const Duration(milliseconds: 650),
      _autosaveFields,
    );
  }

  Future<void> _autosaveFields() async {
    if (!mounted || _descriptionController.text.trim().isEmpty) {
      return;
    }

    final update = _currentFieldUpdate();
    if (update == null) {
      return;
    }

    await widget.controller.updateSelectedTask(update);
  }

  Future<void> _addAnnotation() async {
    final note = _annotationController.text.trim();
    if (note.isEmpty) {
      return;
    }

    _autosaveTimer?.cancel();
    final update = _currentFieldUpdate(addAnnotation: note);
    if (update == null) {
      return;
    }

    await widget.controller.updateSelectedTask(
      update,
    );
    if (mounted) {
      _annotationController.clear();
    }
  }

  Future<void> _undoChanges() async {
    final snapshot = _undoSnapshot;
    if (snapshot == null) {
      return;
    }

    _autosaveTimer?.cancel();
    await widget.controller.updateSelectedTask(
      UpdateTaskInput(
        description: snapshot.title,
        project: snapshot.project,
        clearProject: snapshot.project == null,
        tags: snapshot.tags,
        due: snapshot.due,
        clearDue: snapshot.due == null,
        waitUntil: snapshot.waitUntil,
        clearWait: snapshot.waitUntil == null,
      ),
    );
    if (mounted) {
      setState(() {
        _boundTaskId = null;
        _undoSnapshot = null;
      });
      _bindTask();
    }
  }

  UpdateTaskInput? _currentFieldUpdate({
    String? addAnnotation,
  }) {
    final due = _dateEdit(_dueController.text);
    final wait = _dateEdit(_waitController.text);
    if (!due.canSave || !wait.canSave) {
      return null;
    }

    return UpdateTaskInput(
      description: _descriptionController.text.trim(),
      project: _projectController.text.trim().isEmpty
          ? null
          : _projectController.text.trim(),
      clearProject: _projectController.text.trim().isEmpty,
      tags: _parseTags(_tagsController.text),
      due: due.value,
      clearDue: due.shouldClear,
      waitUntil: wait.value,
      clearWait: wait.shouldClear,
      addAnnotation: addAnnotation,
    );
  }

  List<String> _parseTags(String raw) {
    return raw
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList();
  }

  _DateEdit _dateEdit(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return const _DateEdit.clear();
    }

    final match = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(trimmed);
    if (match == null) {
      return const _DateEdit.incomplete();
    }

    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final parsed = DateTime.utc(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      return const _DateEdit.incomplete();
    }

    return _DateEdit.value(parsed);
  }

  String _dateField(DateTime? date) {
    if (date == null) {
      return '';
    }

    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final current = _dateEdit(controller.text).value;
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.utc(now.year, now.month, now.day),
      firstDate: DateTime.utc(1970),
      lastDate: DateTime.utc(2100),
    );

    if (picked == null || !mounted) {
      return;
    }

    controller.text = _dateField(picked.toUtc());
  }
}

class _DateEdit {
  const _DateEdit.value(this.value)
      : canSave = true,
        shouldClear = false;

  const _DateEdit.clear()
      : value = null,
        canSave = true,
        shouldClear = true;

  const _DateEdit.incomplete()
      : value = null,
        canSave = false,
        shouldClear = false;

  final DateTime? value;
  final bool canSave;
  final bool shouldClear;
}

class _TaskDetailActions extends StatelessWidget {
  const _TaskDetailActions({
    required this.canUndo,
    required this.isSaving,
    required this.onUndo,
  });

  final bool canUndo;
  final bool isSaving;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        FilledButton.tonalIcon(
          key: const Key('detail-undo-button'),
          onPressed: canUndo ? onUndo : null,
          icon: const Icon(Icons.undo_outlined),
          label: const Text('Undo changes'),
        ),
        const SizedBox(width: 12),
        if (isSaving) const Text('Saving...') else const Text('Auto-save on'),
      ],
    );
  }
}
