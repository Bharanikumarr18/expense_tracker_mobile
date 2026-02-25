import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../data/tracker_repository.dart';
import 'theme.dart';

class AppController extends ChangeNotifier {
  AppController({required this.repo});

  final TrackerRepository repo;

  static const String _themeKey = 'ui_theme';
  static const String _exportDirKey = 'export_directory';

  String _themeName = TrackerTheme.defaultThemeName;
  String? _customExportDirectory;
  bool _ready = false;

  bool get isReady => _ready;
  String get themeName => _themeName;
  ThemeData get themeData => TrackerTheme.byName(_themeName);
  String? get customExportDirectory => _customExportDirectory;

  Future<void> load() async {
    try {
      final savedTheme = await repo.getAppSetting(_themeKey);
      final savedExportDir = await repo.getAppSetting(_exportDirKey);
      if (savedTheme != null && TrackerTheme.isValidTheme(savedTheme)) {
        _themeName = savedTheme;
      }
      if (savedExportDir != null && savedExportDir.trim().isNotEmpty) {
        _customExportDirectory = savedExportDir.trim();
      }
    } finally {
      _ready = true;
      notifyListeners();
    }
  }

  Future<void> setTheme(String themeName) async {
    if (!TrackerTheme.isValidTheme(themeName)) return;
    _themeName = themeName;
    await repo.setAppSetting(_themeKey, themeName);
    notifyListeners();
  }

  Future<void> setExportDirectory(String path) async {
    final normalized = path.trim();
    if (normalized.isEmpty) return;
    _customExportDirectory = normalized;
    await repo.setAppSetting(_exportDirKey, normalized);
    notifyListeners();
  }

  Future<void> clearExportDirectory() async {
    _customExportDirectory = null;
    await repo.deleteAppSetting(_exportDirKey);
    notifyListeners();
  }

  Future<String?> resolveExportDirectory() async {
    if (kIsWeb) return null;
    if (_customExportDirectory != null && _customExportDirectory!.isNotEmpty) {
      return _customExportDirectory!;
    }
    final docs = await getApplicationDocumentsDirectory();
    return '${docs.path}/tracker_exports';
  }

  Future<void> wipeDatabase() async {
    await repo.clearAllData();
    _themeName = TrackerTheme.defaultThemeName;
    _customExportDirectory = null;
    notifyListeners();
  }

  Future<void> restoreDefaultCategories() async {
    await repo.restoreDefaultCategories();
    notifyListeners();
  }
}
