import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme.dart';

class BackendConfigurationStore {
  static const _backendUrlKey = 'backend_api_url';
  static const _themePreferenceKey = 'theme_preference';

  Future<String?> loadBackendUrl() async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getString(_backendUrlKey)?.trim();

    if (value == null || value.isEmpty) {
      return null;
    }

    return value;
  }

  Future<void> saveBackendUrl(String baseUrl) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_backendUrlKey, baseUrl.trim());
  }

  Future<AppThemePreference> loadThemePreference() async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getString(_themePreferenceKey);

    return AppThemePreference.fromStorage(value);
  }

  Future<void> saveThemePreference(AppThemePreference preference) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_themePreferenceKey, preference.name);
  }
}
