import 'package:dart_frog_shared/app_check/app_check_config.dart';
import 'package:test/test.dart';

void main() {
  group('AppCheckConfig', () {
    test('should create config with required parameters', () {
      const config = AppCheckConfig(
        firebaseProjectId: 'test-project',
        serviceAccountJson: '{"type": "service_account"}',
      );

      expect(config.firebaseProjectId, equals('test-project'));
      expect(config.serviceAccountJson, equals('{"type": "service_account"}'));
      expect(config.enableDevMode, isFalse);
      expect(config.exemptPaths, isEmpty);
      expect(config.cacheMaxSize, equals(1000));
      expect(config.cacheDuration, equals(const Duration(hours: 1)));
    });

    test('should create config with all parameters', () {
      const config = AppCheckConfig(
        firebaseProjectId: 'test-project',
        serviceAccountJson: '{"type": "service_account"}',
        enableDevMode: true,
        exemptPaths: ['/ping', '/health'],
        cacheMaxSize: 500,
        cacheDuration: Duration(minutes: 30),
      );

      expect(config.firebaseProjectId, equals('test-project'));
      expect(config.serviceAccountJson, equals('{"type": "service_account"}'));
      expect(config.enableDevMode, isTrue);
      expect(config.exemptPaths, equals(['/ping', '/health']));
      expect(config.cacheMaxSize, equals(500));
      expect(config.cacheDuration, equals(const Duration(minutes: 30)));
    });
  });
}
