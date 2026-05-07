import 'package:shared_preferences/shared_preferences.dart';

class BackendConfigurationStore {
  static const _backendUrlKey = 'backend_api_url';

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
}
