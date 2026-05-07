import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/shell_controller.dart';
import '../../models/shell_models.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({
    super.key,
    required this.controller,
    required this.onOpenTask,
  });

  final ShellController controller;
  final ValueChanged<String> onOpenTask;

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  late final TextEditingController _createController;
  late final TextEditingController _dueAfterController;
  late final TextEditingController _dueBeforeController;
  late final TextEditingController _scheduledAfterController;
  late final TextEditingController _scheduledBeforeController;
  late final TextEditingController _waitAfterController;
  late final TextEditingController _waitBeforeController;
  late final TextEditingController _savedViewNameController;
  late final TextEditingController _savedViewImportController;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _createController = TextEditingController();
    _dueAfterController = TextEditingController();
    _dueBeforeController = TextEditingController();
    _scheduledAfterController = TextEditingController();
    _scheduledBeforeController = TextEditingController();
    _waitAfterController = TextEditingController();
    _waitBeforeController = TextEditingController();
    _savedViewNameController = TextEditingController();
    _savedViewImportController = TextEditingController();
  }

  @override
  void dispose() {
    _createController.dispose();
    _dueAfterController.dispose();
    _dueBeforeController.dispose();
    _scheduledAfterController.dispose();
    _scheduledBeforeController.dispose();
    _waitAfterController.dispose();
    _waitBeforeController.dispose();
    _savedViewNameController.dispose();
    _savedViewImportController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tasks = widget.controller.listTasks;
    final activeTasks =
        tasks.where((task) => task.status != TaskStatus.completed).toList();
    final completedTasks =
        tasks.where((task) => task.status == TaskStatus.completed).toList();

    return ListView(
      key: const Key('task-list-screen'),
      children: <Widget>[
        Text(
          'Server-authoritative task list',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Quick create',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Focus(
                        onKeyEvent: _handleCreateKey,
                        child: TextField(
                          key: const Key('create-task-field'),
                          controller: _createController,
                          decoration: const InputDecoration(
                            hintText: 'Describe a task',
                          ),
                          textInputAction: TextInputAction.done,
                          onEditingComplete: _createTask,
                          onSubmitted: (_) => _createTask(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed:
                          widget.controller.isSaving ? null : _createTask,
                      child: const Text('Create'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: TaskListMode.values.map((mode) {
            return ChoiceChip(
              key: Key('task-list-mode-${mode.name}'),
              label: Text(mode.label),
              selected: widget.controller.listMode == mode,
              onSelected: (_) => widget.controller.setListMode(mode),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        _AdvancedFilterPanel(
          controller: widget.controller,
          dueAfterController: _dueAfterController,
          dueBeforeController: _dueBeforeController,
          scheduledAfterController: _scheduledAfterController,
          scheduledBeforeController: _scheduledBeforeController,
          waitAfterController: _waitAfterController,
          waitBeforeController: _waitBeforeController,
          onClear: _clearAdvancedFilter,
        ),
        const SizedBox(height: 12),
        _SavedViewsPanel(
          controller: widget.controller,
          nameController: _savedViewNameController,
          importController: _savedViewImportController,
        ),
        const SizedBox(height: 16),
        if (tasks.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: Text('No tasks for the current server filter.'),
            ),
          )
        else ...<Widget>[
          if (activeTasks.isNotEmpty)
            _TaskListSection(
              title: 'To do',
              tasks: activeTasks,
              controller: widget.controller,
              onOpenTask: widget.onOpenTask,
            ),
          if (activeTasks.isNotEmpty && completedTasks.isNotEmpty)
            const SizedBox(height: 20),
          if (completedTasks.isNotEmpty)
            _TaskListSection(
              title: 'Completed',
              tasks: completedTasks,
              controller: widget.controller,
              onOpenTask: widget.onOpenTask,
            ),
        ],
      ],
    );
  }

  Future<void> _clearAdvancedFilter() async {
    _dueAfterController.clear();
    _dueBeforeController.clear();
    _scheduledAfterController.clear();
    _scheduledBeforeController.clear();
    _waitAfterController.clear();
    _waitBeforeController.clear();
    await widget.controller.clearListFilter();
  }

  Future<void> _createTask() async {
    if (_isCreating || widget.controller.isSaving) {
      return;
    }

    final text = _createController.text.trim();
    if (text.isEmpty) {
      return;
    }

    _isCreating = true;
    try {
      await widget.controller.createTask(text);
      if (mounted) {
        _createController.clear();
      }
    } finally {
      _isCreating = false;
    }
  }

  KeyEventResult _handleCreateKey(
    FocusNode node,
    KeyEvent event,
  ) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;
    if (key != LogicalKeyboardKey.enter &&
        key != LogicalKeyboardKey.numpadEnter) {
      return KeyEventResult.ignored;
    }

    _createTask();
    return KeyEventResult.handled;
  }
}

class _SavedViewsPanel extends StatelessWidget {
  const _SavedViewsPanel({
    required this.controller,
    required this.nameController,
    required this.importController,
  });

  final ShellController controller;
  final TextEditingController nameController;
  final TextEditingController importController;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      key: const Key('saved-views-panel'),
      tilePadding: EdgeInsets.zero,
      title: const Text('Saved views'),
      subtitle: Text(
        controller.savedViews.isEmpty
            ? 'Create reusable task list filters.'
            : '${controller.savedViews.length} local view(s).',
      ),
      children: <Widget>[
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            _SavedViewDropdown(
              key: const Key('saved-view-select-field'),
              value: controller.selectedSavedViewId,
              views: controller.savedViews,
              emptyLabel: 'No local views',
              onChanged: (viewId) {
                if (viewId != null) {
                  final view = controller.savedViews.firstWhere(
                    (view) => view.id == viewId,
                  );
                  nameController.text = view.name;
                  controller.selectSavedView(viewId);
                }
              },
            ),
            SizedBox(
              width: 240,
              child: TextField(
                key: const Key('saved-view-name-field'),
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'View name',
                ),
              ),
            ),
            FilledButton(
              key: const Key('saved-view-create-button'),
              onPressed: () => _saveCurrentView(),
              child: const Text('Save current'),
            ),
            FilledButton.tonal(
              key: const Key('saved-view-update-button'),
              onPressed: controller.selectedSavedViewId == null
                  ? null
                  : () => _saveCurrentView(
                        viewId: controller.selectedSavedViewId,
                      ),
              child: const Text('Update selected'),
            ),
            TextButton(
              key: const Key('saved-view-delete-button'),
              onPressed: controller.selectedSavedViewId == null
                  ? null
                  : () => controller.deleteSavedView(
                        controller.selectedSavedViewId!,
                      ),
              child: const Text('Delete local'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            FilledButton.tonal(
              key: const Key('saved-view-export-button'),
              onPressed: () => _exportViews(context),
              child: const Text('Export'),
            ),
            SizedBox(
              width: 320,
              child: TextField(
                key: const Key('saved-view-import-field'),
                controller: importController,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Import JSON',
                ),
              ),
            ),
            FilledButton.tonal(
              key: const Key('saved-view-import-button'),
              onPressed: () async {
                await controller.importSavedViewsJson(importController.text);
                importController.clear();
              },
              child: const Text('Import'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            _SavedViewDropdown(
              key: const Key('backend-view-select-field'),
              value: null,
              views: controller.backendSavedViews,
              emptyLabel: 'No backend views',
              onChanged: (viewId) {
                if (viewId != null) {
                  controller.retrieveBackendSavedView(viewId);
                }
              },
            ),
            FilledButton.tonal(
              key: const Key('saved-view-refresh-backend-button'),
              onPressed: controller.refreshBackendSavedViews,
              child: const Text('Refresh backend'),
            ),
            FilledButton.tonal(
              key: const Key('saved-view-save-backend-button'),
              onPressed: controller.selectedSavedViewId == null
                  ? null
                  : () => controller.saveViewToBackend(
                        controller.selectedSavedViewId!,
                      ),
              child: const Text('Save selected to backend'),
            ),
            TextButton(
              key: const Key('saved-view-delete-backend-button'),
              onPressed: controller.selectedSavedViewId == null
                  ? null
                  : () => controller.deleteBackendSavedView(
                        controller.selectedSavedViewId!,
                      ),
              child: const Text('Delete selected from backend'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _saveCurrentView({
    String? viewId,
  }) async {
    await controller.saveCurrentView(
      nameController.text,
      viewId: viewId,
    );
  }

  Future<void> _exportViews(BuildContext context) async {
    final selected = controller.selectedSavedViewId;
    final exported = controller.exportSavedViewsJson(
      viewIds: selected == null ? null : <String>[selected],
    );
    await Clipboard.setData(ClipboardData(text: exported));
    if (!context.mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Exported saved views'),
          content: SizedBox(
            width: 520,
            child: SelectableText(exported),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}

class _SavedViewDropdown extends StatelessWidget {
  const _SavedViewDropdown({
    super.key,
    required this.value,
    required this.views,
    required this.emptyLabel,
    required this.onChanged,
  });

  final String? value;
  final List<SavedTaskView> views;
  final String emptyLabel;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = views.any((view) => view.id == value) ? value : null;

    return SizedBox(
      width: 260,
      child: DropdownButtonFormField<String>(
        initialValue: selected,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'View'),
        hint: Text(emptyLabel),
        items: views.map((view) {
          return DropdownMenuItem<String>(
            value: view.id,
            child: Text(view.name),
          );
        }).toList(),
        onChanged: views.isEmpty ? null : onChanged,
      ),
    );
  }
}

class _AdvancedFilterPanel extends StatefulWidget {
  const _AdvancedFilterPanel({
    required this.controller,
    required this.dueAfterController,
    required this.dueBeforeController,
    required this.scheduledAfterController,
    required this.scheduledBeforeController,
    required this.waitAfterController,
    required this.waitBeforeController,
    required this.onClear,
  });

  final ShellController controller;
  final TextEditingController dueAfterController;
  final TextEditingController dueBeforeController;
  final TextEditingController scheduledAfterController;
  final TextEditingController scheduledBeforeController;
  final TextEditingController waitAfterController;
  final TextEditingController waitBeforeController;
  final VoidCallback onClear;

  @override
  State<_AdvancedFilterPanel> createState() => _AdvancedFilterPanelState();
}

class _AdvancedFilterPanelState extends State<_AdvancedFilterPanel> {
  late TaskQueryPreset _preset;
  late TaskStatus? _status;
  late String? _project;
  late String? _tag;
  late bool _noProject;
  late bool _noTags;
  late bool _includeWaiting;
  late bool _includeScheduled;
  late bool _includeBlocked;
  late TaskSort _sort;
  Timer? _dateDebounce;
  bool _isBinding = false;

  @override
  void initState() {
    super.initState();
    _bindFilter();
    for (final controller in _dateControllers) {
      controller.addListener(_scheduleDateApply);
    }
  }

  @override
  void didUpdateWidget(covariant _AdvancedFilterPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _bindFilter();
  }

  @override
  void dispose() {
    _dateDebounce?.cancel();
    for (final controller in _dateControllers) {
      controller.removeListener(_scheduleDateApply);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      key: const Key('advanced-filter-panel'),
      tilePadding: EdgeInsets.zero,
      title: const Text('Advanced filters'),
      subtitle: Text(
        widget.controller.listFilter.isDefault
            ? 'Using the selected workflow preset.'
            : 'Using a custom backend query.',
      ),
      children: <Widget>[
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            _FilterDropdown<TaskQueryPreset>(
              key: const Key('filter-preset-field'),
              label: 'Workflow',
              value: _preset,
              values: TaskQueryPreset.values,
              labelFor: (preset) => preset.apiValue,
              onChanged: (preset) {
                setState(() => _preset = preset);
                _applyNow();
              },
            ),
            _FilterDropdown<String>(
              key: const Key('filter-status-field'),
              label: 'Status',
              value: _status?.apiValue ?? 'any',
              values: <String>[
                'any',
                ...TaskStatus.values.map((status) => status.apiValue),
              ],
              labelFor: (value) {
                if (value == 'any') {
                  return 'Any status';
                }

                return TaskStatus.fromApi(value).label;
              },
              onChanged: (value) {
                setState(() {
                  _status = value == 'any' ? null : TaskStatus.fromApi(value);
                });
                _applyNow();
              },
            ),
            _OptionalFilterDropdown(
              key: const Key('filter-project-field'),
              label: 'Project',
              value: _projectValue,
              values: _availableProjects,
              anyLabel: 'Any project',
              noneLabel: 'No project',
              onChanged: (value) {
                setState(() {
                  _noProject = value == _OptionalFilterDropdown.noneValue;
                  _project = value == _OptionalFilterDropdown.anyValue ||
                          value == _OptionalFilterDropdown.noneValue
                      ? null
                      : value;
                });
                _applyNow();
              },
            ),
            _OptionalFilterDropdown(
              key: const Key('filter-tag-field'),
              label: 'Required tag',
              value: _tagValue,
              values: _availableTags,
              anyLabel: 'Any tag',
              noneLabel: 'No tags',
              onChanged: (value) {
                setState(() {
                  _noTags = value == _OptionalFilterDropdown.noneValue;
                  _tag = value == _OptionalFilterDropdown.anyValue ||
                          value == _OptionalFilterDropdown.noneValue
                      ? null
                      : value;
                });
                _applyNow();
              },
            ),
            _FilterDropdown<TaskSort>(
              key: const Key('filter-sort-field'),
              label: 'Sort',
              value: _sort,
              values: TaskSort.values,
              labelFor: (sort) => sort.apiValue,
              onChanged: (sort) {
                setState(() => _sort = sort);
                _applyNow();
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            FilterChip(
              key: const Key('filter-include-waiting'),
              label: const Text('Waiting'),
              selected: _includeWaiting,
              onSelected: (selected) {
                setState(() => _includeWaiting = selected);
                _applyNow();
              },
            ),
            FilterChip(
              key: const Key('filter-include-scheduled'),
              label: const Text('Scheduled'),
              selected: _includeScheduled,
              onSelected: (selected) {
                setState(() => _includeScheduled = selected);
                _applyNow();
              },
            ),
            FilterChip(
              key: const Key('filter-include-blocked'),
              label: const Text('Blocked'),
              selected: _includeBlocked,
              onSelected: (selected) {
                setState(() => _includeBlocked = selected);
                _applyNow();
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: <Widget>[
            _DateFilterField(
              key: const Key('filter-due-after-field'),
              label: 'Due from',
              controller: widget.dueAfterController,
              onPickDate: () => _pickDate(widget.dueAfterController),
              onPickTime: () => _pickTime(widget.dueAfterController),
              hasError: !_dateIsValid(widget.dueAfterController),
              buttonPrefix: 'filter-due-after',
            ),
            _DateFilterField(
              key: const Key('filter-due-before-field'),
              label: 'Due to',
              controller: widget.dueBeforeController,
              onPickDate: () => _pickDate(widget.dueBeforeController),
              onPickTime: () => _pickTime(widget.dueBeforeController),
              hasError: !_dateIsValid(widget.dueBeforeController),
              buttonPrefix: 'filter-due-before',
            ),
            _DateFilterField(
              key: const Key('filter-scheduled-after-field'),
              label: 'Scheduled from',
              controller: widget.scheduledAfterController,
              onPickDate: () => _pickDate(widget.scheduledAfterController),
              onPickTime: () => _pickTime(widget.scheduledAfterController),
              hasError: !_dateIsValid(widget.scheduledAfterController),
              buttonPrefix: 'filter-scheduled-after',
            ),
            _DateFilterField(
              key: const Key('filter-scheduled-before-field'),
              label: 'Scheduled to',
              controller: widget.scheduledBeforeController,
              onPickDate: () => _pickDate(widget.scheduledBeforeController),
              onPickTime: () => _pickTime(widget.scheduledBeforeController),
              hasError: !_dateIsValid(widget.scheduledBeforeController),
              buttonPrefix: 'filter-scheduled-before',
            ),
            _DateFilterField(
              key: const Key('filter-wait-after-field'),
              label: 'Waiting from',
              controller: widget.waitAfterController,
              onPickDate: () => _pickDate(widget.waitAfterController),
              onPickTime: () => _pickTime(widget.waitAfterController),
              hasError: !_dateIsValid(widget.waitAfterController),
              buttonPrefix: 'filter-wait-after',
            ),
            _DateFilterField(
              key: const Key('filter-wait-before-field'),
              label: 'Waiting to',
              controller: widget.waitBeforeController,
              onPickDate: () => _pickDate(widget.waitBeforeController),
              onPickTime: () => _pickTime(widget.waitBeforeController),
              hasError: !_dateIsValid(widget.waitBeforeController),
              buttonPrefix: 'filter-wait-before',
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: <Widget>[
            TextButton(
              key: const Key('filter-clear-button'),
              onPressed: widget.onClear,
              child: const Text('Clear filters'),
            ),
          ],
        ),
      ],
    );
  }

  List<TextEditingController> get _dateControllers {
    return <TextEditingController>[
      widget.dueAfterController,
      widget.dueBeforeController,
      widget.scheduledAfterController,
      widget.scheduledBeforeController,
      widget.waitAfterController,
      widget.waitBeforeController,
    ];
  }

  List<String> get _availableProjects {
    final values = widget.controller.allTasks
        .map((task) => task.project)
        .whereType<String>()
        .map((project) => project.trim())
        .where((project) => project.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    final project = _project;
    if (project != null && project.isNotEmpty && !values.contains(project)) {
      values.add(project);
      values.sort();
    }

    return values;
  }

  List<String> get _availableTags {
    final values = widget.controller.allTasks
        .expand((task) => task.tags)
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    final tag = _tag;
    if (tag != null && tag.isNotEmpty && !values.contains(tag)) {
      values.add(tag);
      values.sort();
    }

    return values;
  }

  String get _projectValue {
    if (_noProject) {
      return _OptionalFilterDropdown.noneValue;
    }

    return _project ?? _OptionalFilterDropdown.anyValue;
  }

  String get _tagValue {
    if (_noTags) {
      return _OptionalFilterDropdown.noneValue;
    }

    return _tag ?? _OptionalFilterDropdown.anyValue;
  }

  void _bindFilter() {
    final filter = widget.controller.listFilter;
    _isBinding = true;
    _preset = filter.preset;
    _status = filter.statuses.length == 1 ? filter.statuses.single : null;
    _project = filter.project;
    _tag = filter.requiredTag;
    _noProject = filter.noProject;
    _noTags = filter.noTags;
    _includeWaiting = filter.includeWaiting;
    _includeScheduled = filter.includeScheduled;
    _includeBlocked = filter.includeBlocked;
    _sort = filter.sort;
    _setDateText(widget.dueAfterController, filter.dueAfter);
    _setDateText(widget.dueBeforeController, filter.dueBefore);
    _setDateText(widget.scheduledAfterController, filter.scheduledAfter);
    _setDateText(widget.scheduledBeforeController, filter.scheduledBefore);
    _setDateText(widget.waitAfterController, filter.waitAfter);
    _setDateText(widget.waitBeforeController, filter.waitBefore);
    _isBinding = false;
  }

  void _scheduleDateApply() {
    if (_isBinding) {
      return;
    }

    _dateDebounce?.cancel();
    _dateDebounce = Timer(const Duration(milliseconds: 350), _applyNow);
    setState(() {});
  }

  void _applyNow() {
    if (!_datesAreValid) {
      return;
    }

    final status = _status;
    unawaited(
      widget.controller.setListFilter(
        TaskListFilter(
          preset: _preset,
          statuses:
              status == null ? const <TaskStatus>[] : <TaskStatus>[status],
          project: _noProject ? null : _project,
          noProject: _noProject,
          requiredTag: _noTags ? null : _tag,
          noTags: _noTags,
          dueAfter: _dateOrNull(widget.dueAfterController),
          dueBefore: _dateOrNull(widget.dueBeforeController),
          scheduledAfter: _dateOrNull(widget.scheduledAfterController),
          scheduledBefore: _dateOrNull(widget.scheduledBeforeController),
          waitAfter: _dateOrNull(widget.waitAfterController),
          waitBefore: _dateOrNull(widget.waitBeforeController),
          includeWaiting: _includeWaiting,
          includeScheduled: _includeScheduled,
          includeBlocked: _includeBlocked,
          sort: _sort,
        ),
      ),
    );
  }

  bool get _datesAreValid {
    return _dateControllers.every(_dateIsValid);
  }

  bool _dateIsValid(TextEditingController controller) {
    return controller.text.trim().isEmpty ||
        _parseFlexibleDateTime(controller.text) != null;
  }

  DateTime? _dateOrNull(TextEditingController controller) {
    final text = controller.text.trim();
    if (text.isEmpty) {
      return null;
    }

    return _parseFlexibleDateTime(text);
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final current = _dateOrNull(controller) ?? DateTime.now().toUtc();
    final selected = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.utc(1970),
      lastDate: DateTime.utc(2100),
    );

    if (selected == null) {
      return;
    }

    final next = DateTime.utc(
      selected.year,
      selected.month,
      selected.day,
      current.hour,
      current.minute,
    );
    controller.text = _formatDateTime(next);
    _applyNow();
  }

  Future<void> _pickTime(TextEditingController controller) async {
    final current = _dateOrNull(controller) ?? DateTime.now().toUtc();
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );

    if (selected == null) {
      return;
    }

    final next = DateTime.utc(
      current.year,
      current.month,
      current.day,
      selected.hour,
      selected.minute,
    );
    controller.text = _formatDateTime(next);
    _applyNow();
  }

  void _setDateText(
    TextEditingController controller,
    DateTime? value,
  ) {
    final next = value == null ? '' : _formatDateTime(value.toUtc());
    if (controller.text != next) {
      controller.text = next;
    }
  }
}

class _FilterDropdown<T> extends StatelessWidget {
  const _FilterDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.values,
    required this.labelFor,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> values;
  final String Function(T value) labelFor;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: DropdownButtonFormField<T>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: values.map((item) {
          return DropdownMenuItem<T>(
            value: item,
            child: Text(labelFor(item)),
          );
        }).toList(),
        onChanged: (selected) {
          if (selected == null) {
            return;
          }

          onChanged(selected);
        },
      ),
    );
  }
}

class _OptionalFilterDropdown extends StatelessWidget {
  const _OptionalFilterDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.values,
    required this.anyLabel,
    required this.noneLabel,
    required this.onChanged,
  });

  static const String anyValue = '__any__';
  static const String noneValue = '__none__';

  final String label;
  final String value;
  final List<String> values;
  final String anyLabel;
  final String noneLabel;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: <DropdownMenuItem<String>>[
          DropdownMenuItem<String>(
            value: anyValue,
            child: Text(anyLabel),
          ),
          DropdownMenuItem<String>(
            value: noneValue,
            child: Text(noneLabel),
          ),
          for (final item in values)
            DropdownMenuItem<String>(
              value: item,
              child: Text(item),
            ),
        ],
        onChanged: (selected) {
          if (selected == null) {
            return;
          }

          onChanged(selected);
        },
      ),
    );
  }
}

class _DateFilterField extends StatelessWidget {
  const _DateFilterField({
    super.key,
    required this.label,
    required this.controller,
    required this.onPickDate,
    required this.onPickTime,
    required this.hasError,
    required this.buttonPrefix,
  });

  final String label;
  final TextEditingController controller;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;
  final bool hasError;
  final String buttonPrefix;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 250,
      child: TextField(
        key: Key('$buttonPrefix-text-field'),
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: '2026-5-8 or 2026-5-8 14:30',
          errorText: hasError ? 'Use YYYY-M-D or YYYY-M-D HH:mm' : null,
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              IconButton(
                key: Key('$buttonPrefix-date-button'),
                tooltip: 'Pick date',
                icon: const Icon(Icons.calendar_month_outlined),
                onPressed: onPickDate,
              ),
              IconButton(
                key: Key('$buttonPrefix-time-button'),
                tooltip: 'Pick time',
                icon: const Icon(Icons.schedule_outlined),
                onPressed: onPickTime,
              ),
            ],
          ),
          suffixIconConstraints: const BoxConstraints(
            minWidth: 96,
          ),
        ),
      ),
    );
  }
}

DateTime? _parseFlexibleDateTime(String raw) {
  final match = RegExp(
    r'^(\d{4})-(\d{1,2})-(\d{1,2})(?:[ T](\d{1,2}):(\d{2}))?$',
  ).firstMatch(raw.trim());
  if (match == null) {
    return null;
  }

  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final hour = int.tryParse(match.group(4) ?? '0');
  final minute = int.tryParse(match.group(5) ?? '0');

  if (hour == null || minute == null || hour > 23 || minute > 59) {
    return null;
  }

  final parsed = DateTime.utc(year, month, day, hour, minute);
  if (parsed.year != year || parsed.month != month || parsed.day != day) {
    return null;
  }

  return parsed;
}

String _formatDateTime(DateTime value) {
  final utc = value.toUtc();
  final year = utc.year.toString().padLeft(4, '0');
  final month = utc.month.toString().padLeft(2, '0');
  final day = utc.day.toString().padLeft(2, '0');
  final hour = utc.hour.toString().padLeft(2, '0');
  final minute = utc.minute.toString().padLeft(2, '0');

  if (utc.hour == 0 && utc.minute == 0) {
    return '$year-$month-$day';
  }

  return '$year-$month-$day $hour:$minute';
}

class _TaskListSection extends StatelessWidget {
  const _TaskListSection({
    required this.title,
    required this.tasks,
    required this.controller,
    required this.onOpenTask,
  });

  final String title;
  final List<TaskItem> tasks;
  final ShellController controller;
  final ValueChanged<String> onOpenTask;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          key: Key('task-list-section-$title'),
          title,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        const Divider(height: 1),
        for (final task in tasks)
          _TaskListCard(
            task: task,
            controller: controller,
            onOpenTask: onOpenTask,
          ),
      ],
    );
  }
}

class _TaskListCard extends StatelessWidget {
  const _TaskListCard({
    required this.task,
    required this.controller,
    required this.onOpenTask,
  });

  final TaskItem task;
  final ShellController controller;
  final ValueChanged<String> onOpenTask;

  @override
  Widget build(BuildContext context) {
    final completed = task.status == TaskStatus.completed;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
          ),
        ),
      ),
      child: ExpansionTile(
        key: Key('task-expand-${task.id}'),
        dense: true,
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 4),
        childrenPadding: const EdgeInsets.fromLTRB(56, 0, 16, 12),
        leading: Checkbox(
          key: Key('task-complete-${task.id}'),
          value: completed,
          onChanged:
              controller.isSaving ? null : (_) => _setCompleted(!completed),
        ),
        title: _TaskListRowTitle(task: task),
        children: <Widget>[
          _ExpandedTaskDetails(
            task: task,
            onOpenTask: onOpenTask,
          ),
        ],
      ),
    );
  }

  Future<void> _setCompleted(bool completed) async {
    await controller.transitionTask(
      task,
      completed ? TaskStatus.completed : TaskStatus.pending,
    );
  }
}

class _ExpandedTaskDetails extends StatelessWidget {
  const _ExpandedTaskDetails({
    required this.task,
    required this.onOpenTask,
  });

  final TaskItem task;
  final ValueChanged<String> onOpenTask;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          Text(task.summary),
          Chip(label: Text(task.status.label)),
          Chip(label: Text(task.dueLabel)),
          Chip(label: Text(task.project ?? 'No project')),
          for (final tag in task.tags) Chip(label: Text(tag)),
          TextButton(
            key: Key('task-open-${task.id}'),
            onPressed: () => onOpenTask(task.id),
            child: const Text('Open details'),
          ),
        ],
      ),
    );
  }
}

class _TaskListRowTitle extends StatelessWidget {
  const _TaskListRowTitle({
    required this.task,
  });

  final TaskItem task;

  @override
  Widget build(BuildContext context) {
    final completed = task.status == TaskStatus.completed;
    final titleStyle = Theme.of(context).textTheme.bodyLarge;
    final fadedStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );

    return LayoutBuilder(
      builder: (context, constraints) {
        final showDue = constraints.maxWidth >= 360;
        final showProject = constraints.maxWidth >= 540;
        final showTags = constraints.maxWidth >= 760;

        return Row(
          children: <Widget>[
            Expanded(
              child: Text(
                task.title,
                overflow: TextOverflow.ellipsis,
                style: completed
                    ? titleStyle?.copyWith(
                        decoration: TextDecoration.lineThrough,
                      )
                    : titleStyle,
              ),
            ),
            if (showDue)
              _TaskListMetaColumn(
                key: Key('task-row-due-${task.id}'),
                width: 112,
                child: Text(
                  task.dueLabel,
                  overflow: TextOverflow.ellipsis,
                  style: fadedStyle,
                  textAlign: TextAlign.right,
                ),
              ),
            if (showProject)
              _TaskListMetaColumn(
                key: Key('task-row-project-${task.id}'),
                width: 140,
                child: task.project == null
                    ? const SizedBox.shrink()
                    : _ProjectBadge(
                        key: Key('task-project-badge-${task.id}'),
                        label: task.project!,
                      ),
              ),
            if (showTags)
              _TaskListMetaColumn(
                key: Key('task-row-tags-${task.id}'),
                width: 180,
                child: task.tags.isEmpty
                    ? const SizedBox.shrink()
                    : _TagBadges(
                        taskId: task.id,
                        tags: task.tags,
                      ),
              ),
          ],
        );
      },
    );
  }
}

class _TaskListMetaColumn extends StatelessWidget {
  const _TaskListMetaColumn({
    super.key,
    required this.width,
    required this.child,
  });

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Align(
        alignment: Alignment.centerRight,
        child: child,
      ),
    );
  }
}

class _ProjectBadge extends StatelessWidget {
  const _ProjectBadge({
    super.key,
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = _BadgeColors.forLabel(label);

    return Container(
      constraints: const BoxConstraints(maxWidth: 128),
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colors.foreground,
            ),
      ),
    );
  }
}

class _TagBadges extends StatelessWidget {
  const _TagBadges({
    required this.taskId,
    required this.tags,
  });

  final String taskId;
  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    final visibleTags = tags.take(2).toList();

    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 4,
      runSpacing: 4,
      children: <Widget>[
        for (final tag in visibleTags) _TagBadge(taskId: taskId, tag: tag),
      ],
    );
  }
}

class _TagBadge extends StatelessWidget {
  const _TagBadge({
    required this.taskId,
    required this.tag,
  });

  final String taskId;
  final String tag;

  @override
  Widget build(BuildContext context) {
    final colors = _BadgeColors.forLabel(tag);

    return Container(
      key: Key('task-tag-badge-$taskId-$tag'),
      constraints: const BoxConstraints(maxWidth: 78),
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        tag,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colors.foreground,
            ),
      ),
    );
  }
}

class _BadgeColors {
  const _BadgeColors({
    required this.background,
    required this.foreground,
  });

  final Color background;
  final Color foreground;

  static const List<Color> _palette = <Color>[
    Color(0xFFB7E4C7),
    Color(0xFFFFD6A5),
    Color(0xFFA0C4FF),
    Color(0xFFFFADAD),
    Color(0xFFCAFFBF),
    Color(0xFFBDB2FF),
    Color(0xFFFDFFB6),
    Color(0xFF9BF6FF),
  ];

  static _BadgeColors forLabel(String label) {
    final background = _palette[_hash(label) % _palette.length];
    final foreground = background.computeLuminance() > 0.55
        ? const Color(0xFF1F2933)
        : const Color(0xFFFFFFFF);

    return _BadgeColors(
      background: background,
      foreground: foreground,
    );
  }

  static int _hash(String value) {
    var hash = 0;
    for (final codeUnit in value.codeUnits) {
      hash = (hash * 31 + codeUnit) & 0x7fffffff;
    }

    return hash;
  }
}
