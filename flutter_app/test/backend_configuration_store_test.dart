import 'package:flutter_app/app/backend_configuration_store.dart';
import 'package:flutter_app/app/app_theme.dart';
import 'package:flutter_app/models/shell_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('backend configuration store persists backend API URL', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = BackendConfigurationStore();

    expect(await store.loadBackendUrl(), isNull);

    await store.saveBackendUrl(' http://127.0.0.1:8080 ');

    expect(await store.loadBackendUrl(), 'http://127.0.0.1:8080');
  });

  test('backend configuration store persists theme preference', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = BackendConfigurationStore();

    expect(await store.loadThemePreference(), AppThemePreference.dark);

    await store.saveThemePreference(AppThemePreference.system);

    expect(await store.loadThemePreference(), AppThemePreference.system);
  });

  test('backend configuration store persists dashboard layout', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = BackendConfigurationStore();
    final layout = DashboardLayout.defaultLayout(
      updatedAt: DateTime.utc(2026, 4, 12),
    ).copyWith(
      enabledWidgets: <DashboardWidgetType>{DashboardWidgetType.readyNow},
    );

    expect(await store.loadDashboardLayout(), isNull);

    await store.saveDashboardLayout(layout);

    final loaded = await store.loadDashboardLayout();
    expect(loaded?.id, layout.id);
    expect(loaded?.enabledWidgets, <DashboardWidgetType>{
      DashboardWidgetType.readyNow,
    });
  });
}
