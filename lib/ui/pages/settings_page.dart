import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../app_controller.dart';
import '../theme.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.controller});

  final AppController controller;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _exportPathCtrl = TextEditingController();
  final _wipeCtrl = TextEditingController();
  bool _saving = false;
  String? _defaultExportPath;

  @override
  void initState() {
    super.initState();
    _exportPathCtrl.text = widget.controller.customExportDirectory ?? '';
    _loadDefaultDir();
  }

  @override
  void dispose() {
    _exportPathCtrl.dispose();
    _wipeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDefaultDir() async {
    final path = await widget.controller.resolveExportDirectory();
    if (!mounted) return;
    setState(() => _defaultExportPath = path);
  }

  Future<void> _saveExportDir(String path) async {
    setState(() => _saving = true);
    await widget.controller.setExportDirectory(path);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Export folder set to: $path')));
  }

  Future<void> _clearExportDir() async {
    setState(() => _saving = true);
    await widget.controller.clearExportDirectory();
    if (!mounted) return;
    _exportPathCtrl.text = '';
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Export folder reset to default')),
    );
  }

  Future<void> _pickFolder() async {
    if (kIsWeb) return;
    final path = await FilePicker.platform.getDirectoryPath();
    if (!mounted) return;
    if (path != null && path.trim().isNotEmpty) {
      _exportPathCtrl.text = path.trim();
      await _saveExportDir(path.trim());
    }
  }

  Future<void> _confirmWipe() async {
    _wipeCtrl.clear();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Erase ALL data?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'This will permanently delete all categories, entries, assets, and settings.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _wipeCtrl,
              decoration: const InputDecoration(
                labelText: 'Type DELETE to confirm',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(context, _wipeCtrl.text.trim() == 'DELETE'),
            child: const Text('Erase'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await widget.controller.wipeDatabase();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('All data erased.')));
    }
  }

  Future<void> _confirmRestoreDefaults() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore default categories?'),
        content: const Text(
          'This will re-add the default categories and subcategories '
          '(existing ones are kept).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await widget.controller.restoreDefaultCategories();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Default categories restored.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text(
          'Settings',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Theme', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: TrackerTheme.themeNames
                      .map(
                        (name) => ChoiceChip(
                          label: Text(name),
                          selected: widget.controller.themeName == name,
                          onSelected: (sel) {
                            if (sel) {
                              widget.controller.setTheme(name);
                            }
                          },
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Defaults', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 6),
                const Text('Re-add the built-in categories and subcategories.'),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _saving ? null : _confirmRestoreDefaults,
                  icon: const Icon(Icons.restore),
                  label: const Text('Restore Default Categories'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Export Destination',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  _defaultExportPath == null
                      ? 'Default: (not available on web)'
                      : 'Default: $_defaultExportPath',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _exportPathCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Custom export folder',
                    hintText: '/storage/emulated/0/Download/TrackerExports',
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _saving
                          ? null
                          : () async {
                              final value = _exportPathCtrl.text.trim();
                              if (value.isEmpty) return;
                              await _saveExportDir(value);
                            },
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Save Export Folder'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _saving ? null : _clearExportDir,
                      icon: const Icon(Icons.refresh_outlined),
                      label: const Text('Reset to Default'),
                    ),
                    if (!kIsWeb)
                      OutlinedButton.icon(
                        onPressed: _saving ? null : _pickFolder,
                        icon: const Icon(Icons.folder_open),
                        label: const Text('Pick Folder'),
                      ),
                  ],
                ),
                if (kIsWeb)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Picking a folder is not supported in web.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          color: Theme.of(context).colorScheme.errorContainer.withOpacity(0.2),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Danger Zone',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                const Text('Erase the entire database. This cannot be undone.'),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: _saving ? null : _confirmWipe,
                  icon: const Icon(Icons.delete_forever_outlined),
                  label: const Text('Erase All Data'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
