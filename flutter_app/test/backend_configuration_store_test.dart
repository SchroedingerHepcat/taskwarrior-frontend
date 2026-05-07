import 'package:flutter_app/app/backend_configuration_store.dart';
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
}
