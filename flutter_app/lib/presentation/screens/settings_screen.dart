import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../app/shell_controller.dart';

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

  @override
  void initState() {
    super.initState();
    _backendUrlController = TextEditingController(
      text: widget.controller.backendUrl ?? '',
    );
  }

  @override
  void dispose() {
    _backendUrlController.dispose();
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
      ],
    );
  }

  Future<void> _save() async {
    await widget.controller.configureBackendUrl(
      _backendUrlController.text,
    );
  }
}
