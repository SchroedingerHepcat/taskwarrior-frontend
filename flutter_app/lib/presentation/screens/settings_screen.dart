import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_theme.dart';
import '../../app/shell_controller.dart';
import '../../models/shell_models.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.controller,
  });

  final ShellController controller;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _backendUrlController;
  late final TextEditingController _dashboardImportController;
  String? _selectedDashboardViewId;
  String? _selectedBackendLayoutId;

  @override
  void initState() {
    super.initState();
    _backendUrlController = TextEditingController(
      text: widget.controller.backendUrl ?? '',
    );
    _dashboardImportController = TextEditingController();
  }

  @override
  void dispose() {
    _backendUrlController.dispose();
    _dashboardImportController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('settings-screen'),
      children: <Widget>[
        Text(
          'Appearance',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        const Text('Choose the app color mode. Dark mode is the default.'),
        const SizedBox(height: 12),
        SegmentedButton<AppThemePreference>(
          key: const Key('theme-mode-control'),
          segments: AppThemePreference.values.map((preference) {
            return ButtonSegment<AppThemePreference>(
              value: preference,
              label: Text(preference.label),
            );
          }).toList(),
          selected: <AppThemePreference>{
            widget.controller.themePreference,
          },
          onSelectionChanged: (selection) {
            widget.controller.setThemePreference(selection.single);
          },
        ),
        const SizedBox(height: 28),
        Text(
          'Backend server',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        const Text(
          'Set the product API server used by this client. This is not the '
          'TaskChampion sync server URL; the Rust backend owns sync.',
        ),
        const SizedBox(height: 20),
        TextField(
          key: const Key('backend-url-field'),
          controller: _backendUrlController,
          decoration: const InputDecoration(
            labelText: 'Backend API URL',
            hintText: 'http://127.0.0.1:8080',
          ),
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _save(),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            key: const Key('backend-url-save'),
            onPressed: widget.controller.isSaving ? null : _save,
            icon: const Icon(Icons.cloud_sync_outlined),
            label: const Text('Use backend server'),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          widget.controller.connectionLabel,
          key: const Key('settings-connection-label'),
        ),
        const SizedBox(height: 28),
        _DashboardSettingsPanel(
          controller: widget.controller,
          importController: _dashboardImportController,
          selectedSavedViewId: _selectedDashboardViewId,
          selectedBackendLayoutId: _selectedBackendLayoutId,
          onSelectSavedView: (viewId) {
            setState(() => _selectedDashboardViewId = viewId);
          },
          onSelectBackendLayout: (layoutId) {
            setState(() => _selectedBackendLayoutId = layoutId);
            if (layoutId != null) {
              widget.controller.retrieveBackendDashboardLayout(layoutId);
            }
          },
        ),
      ],
    );
  }

  Future<void> _save() async {
    await widget.controller.configureBackendUrl(
      _backendUrlController.text,
    );
  }
}

class _DashboardSettingsPanel extends StatelessWidget {
  const _DashboardSettingsPanel({
    required this.controller,
    required this.importController,
    required this.selectedSavedViewId,
    required this.selectedBackendLayoutId,
    required this.onSelectSavedView,
    required this.onSelectBackendLayout,
  });

  final ShellController controller;
  final TextEditingController importController;
  final String? selectedSavedViewId;
  final String? selectedBackendLayoutId;
  final ValueChanged<String?> onSelectSavedView;
  final ValueChanged<String?> onSelectBackendLayout;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      key: const Key('dashboard-settings-panel'),
      tilePadding: EdgeInsets.zero,
      title: const Text('Dashboard layout'),
      subtitle: Text(
        '${controller.dashboardLayout.savedViewWidgets.length} saved '
        'view panel(s).',
      ),
      children: <Widget>[
        const SizedBox(height: 8),
        TextFormField(
          key: const Key('dashboard-layout-name-field'),
          initialValue: controller.dashboardLayout.name,
          decoration: const InputDecoration(
            labelText: 'Dashboard layout name',
          ),
          textInputAction: TextInputAction.done,
          onFieldSubmitted: controller.renameDashboardLayout,
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: DashboardWidgetType.values.map((widget) {
              return FilterChip(
                label: Text(widget.title),
                selected: controller.enabledWidgets.contains(widget),
                onSelected: (_) => controller.toggleWidget(widget),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            _SavedViewDropdown(
              key: const Key('dashboard-saved-view-select-field'),
              value: selectedSavedViewId,
              views: controller.savedViews,
              emptyLabel: 'Create saved views from Tasks',
              onChanged: onSelectSavedView,
            ),
            FilledButton.tonal(
              key: const Key('dashboard-add-saved-view-button'),
              onPressed: selectedSavedViewId == null
                  ? null
                  : () => controller.addSavedViewToDashboard(
                        selectedSavedViewId!,
                      ),
              child: const Text('Add saved view panel'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final entry in controller.dashboardLayout.savedViewWidgets.indexed)
          _DashboardSavedViewPanelEditor(
            key: Key('dashboard-layout-widget-${entry.$2.id}'),
            widget: entry.$2,
            index: entry.$1,
            count: controller.dashboardLayout.savedViewWidgets.length,
            onRename: (title) {
              controller.renameDashboardSavedViewWidget(
                widgetId: entry.$2.id,
                title: title,
              );
            },
            onMoveUp: () {
              controller.moveDashboardSavedViewWidget(
                widgetId: entry.$2.id,
                direction: -1,
              );
            },
            onMoveDown: () {
              controller.moveDashboardSavedViewWidget(
                widgetId: entry.$2.id,
                direction: 1,
              );
            },
            onRemove: () {
              controller.removeSavedViewFromDashboard(entry.$2.id);
            },
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            FilledButton.tonal(
              key: const Key('dashboard-export-button'),
              onPressed: () => _exportLayout(context),
              child: const Text('Export layout'),
            ),
            SizedBox(
              width: 320,
              child: TextField(
                key: const Key('dashboard-import-field'),
                controller: importController,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Import layout JSON',
                ),
              ),
            ),
            FilledButton.tonal(
              key: const Key('dashboard-import-button'),
              onPressed: () async {
                await controller.importDashboardLayoutJson(
                  importController.text,
                );
                importController.clear();
              },
              child: const Text('Import layout'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            _DashboardLayoutDropdown(
              key: const Key('backend-dashboard-layout-select-field'),
              value: selectedBackendLayoutId,
              layouts: controller.backendDashboardLayouts,
              onChanged: onSelectBackendLayout,
            ),
            FilledButton.tonal(
              key: const Key('dashboard-refresh-backend-button'),
              onPressed: controller.refreshBackendDashboardLayouts,
              child: const Text('Refresh backend layouts'),
            ),
            FilledButton.tonal(
              key: const Key('dashboard-save-backend-button'),
              onPressed: controller.saveDashboardLayoutToBackend,
              child: const Text('Save layout to backend'),
            ),
            TextButton(
              key: const Key('dashboard-delete-backend-button'),
              onPressed: selectedBackendLayoutId == null
                  ? null
                  : () => controller.deleteBackendDashboardLayout(
                        selectedBackendLayoutId!,
                      ),
              child: const Text('Delete backend layout'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _exportLayout(BuildContext context) async {
    final exported = controller.exportDashboardLayoutJson();
    await Clipboard.setData(ClipboardData(text: exported));
    if (!context.mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Exported dashboard layout'),
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
        decoration: const InputDecoration(labelText: 'Saved view'),
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

class _DashboardSavedViewPanelEditor extends StatelessWidget {
  const _DashboardSavedViewPanelEditor({
    super.key,
    required this.widget,
    required this.index,
    required this.count,
    required this.onRename,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onRemove,
  });

  final DashboardSavedViewWidget widget;
  final int index;
  final int count;
  final ValueChanged<String> onRename;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 720;

    final titleField = SizedBox(
      width: compact ? double.infinity : 280,
      child: TextFormField(
        key: Key('dashboard-panel-title-field-${widget.id}'),
        initialValue: widget.title,
        decoration: const InputDecoration(labelText: 'Panel title'),
        textInputAction: TextInputAction.done,
        onFieldSubmitted: onRename,
      ),
    );
    final actions = Wrap(
      spacing: 4,
      children: <Widget>[
        IconButton(
          key: Key('dashboard-panel-up-${widget.id}'),
          tooltip: 'Move panel up',
          onPressed: index == 0 ? null : onMoveUp,
          icon: const Icon(Icons.arrow_upward_outlined),
        ),
        IconButton(
          key: Key('dashboard-panel-down-${widget.id}'),
          tooltip: 'Move panel down',
          onPressed: index == count - 1 ? null : onMoveDown,
          icon: const Icon(Icons.arrow_downward_outlined),
        ),
        IconButton(
          key: Key('dashboard-panel-remove-${widget.id}'),
          tooltip: 'Remove panel',
          onPressed: onRemove,
          icon: const Icon(Icons.remove_circle_outline),
        ),
      ],
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  titleField,
                  const SizedBox(height: 8),
                  Text('Saved view: ${widget.viewId}'),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: actions,
                  ),
                ],
              )
            : Row(
                children: <Widget>[
                  Expanded(child: titleField),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Saved view: ${widget.viewId}')),
                  actions,
                ],
              ),
      ),
    );
  }
}

class _DashboardLayoutDropdown extends StatelessWidget {
  const _DashboardLayoutDropdown({
    super.key,
    required this.value,
    required this.layouts,
    required this.onChanged,
  });

  final String? value;
  final List<DashboardLayout> layouts;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = layouts.any((layout) => layout.id == value) ? value : null;

    return SizedBox(
      width: 260,
      child: DropdownButtonFormField<String>(
        initialValue: selected,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Backend layout'),
        hint: const Text('No backend layouts'),
        items: layouts.map((layout) {
          return DropdownMenuItem<String>(
            value: layout.id,
            child: Text(layout.name),
          );
        }).toList(),
        onChanged: layouts.isEmpty ? null : onChanged,
      ),
    );
  }
}
