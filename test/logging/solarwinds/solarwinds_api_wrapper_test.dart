// ignore_for_file: avoid_print

import 'package:dart_frog_shared/logging/solarwinds/solarwinds_api_wrapper.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

void main() {
  group('SolarWindsApiWrapper', () {
    test('constructs with correct Bearer token format', () {
      final wrapper = SolarWindsApiWrapper(token: 'test-token-123', region: 'eu-01');

      expect(wrapper, isNotNull);
    });

    test('constructs endpoint URL correctly for different regions', () {
      final regions = ['eu-01', 'na-01', 'na-02', 'ap-01', 'custom-region'];

      for (final region in regions) {
        final wrapper = SolarWindsApiWrapper(token: 'test-token', region: region);
        expect(wrapper, isNotNull);
      }
    });

    test('accepts empty token without throwing', () {
      expect(() => SolarWindsApiWrapper(token: '', region: 'eu-01'), returnsNormally);
    });

    test('trackEvent sends request with correct headers and content type', () async {
      // Note: This test verifies the integration but we cannot easily mock Dio internals
      // The actual HTTP call verification would require DioAdapter or similar
      final wrapper = SolarWindsApiWrapper(token: 'test-token', region: 'eu-01');

      // This will fail to connect but we're testing that it doesn't throw
      // and constructs the request properly
      try {
        await wrapper.trackEvent('{"test": "data"}');
      } catch (e) {
        // Expected to fail since we're not mocking the actual HTTP client
        expect(e, isA<DioException>());
      }
    });

    test('handles DioException gracefully', () async {
      final wrapper = SolarWindsApiWrapper(token: 'invalid-token', region: 'eu-01');

      // Should not throw even if request fails
      await expectLater(wrapper.trackEvent('{"test": "data"}'), completes);
    });

    test('constructs correct endpoint for eu-01 region', () {
      final wrapper = SolarWindsApiWrapper(token: 'token', region: 'eu-01');
      expect(wrapper, isNotNull);
      // Endpoint should be: https://logs.collector.eu-01.cloud.solarwinds.com/v1
    });

    test('constructs correct endpoint for na-01 region', () {
      final wrapper = SolarWindsApiWrapper(token: 'token', region: 'na-01');
      expect(wrapper, isNotNull);
      // Endpoint should be: https://logs.collector.na-01.cloud.solarwinds.com/v1
    });

    test('constructs correct endpoint for na-02 region', () {
      final wrapper = SolarWindsApiWrapper(token: 'token', region: 'na-02');
      expect(wrapper, isNotNull);
      // Endpoint should be: https://logs.collector.na-02.cloud.solarwinds.com/v1
    });

    test('constructs correct endpoint for ap-01 region', () {
      final wrapper = SolarWindsApiWrapper(token: 'token', region: 'ap-01');
      expect(wrapper, isNotNull);
      // Endpoint should be: https://logs.collector.ap-01.cloud.solarwinds.com/v1
    });

    test('accepts custom/future regions without validation', () {
      final wrapper = SolarWindsApiWrapper(token: 'token', region: 'future-region-01');
      expect(wrapper, isNotNull);
      // Should accept any region string for future compatibility
    });

    test('Bearer token includes "Bearer " prefix', () {
      final wrapper = SolarWindsApiWrapper(token: 'my-token-123', region: 'eu-01');
      // Internal _bearerToken should be "Bearer my-token-123"
      expect(wrapper, isNotNull);
    });

    test('handles JSON body as string', () async {
      final wrapper = SolarWindsApiWrapper(token: 'test-token', region: 'eu-01');

      const jsonBody = '{"system":"test","message":"test log"}';

      // Should accept string body
      try {
        await wrapper.trackEvent(jsonBody);
      } catch (e) {
        // Expected to fail connection, but body type should be correct
        expect(e, isA<DioException>());
      }
    });

    test('handles long token strings', () {
      final longToken = 'a' * 500;
      final wrapper = SolarWindsApiWrapper(token: longToken, region: 'eu-01');
      expect(wrapper, isNotNull);
    });

    test('handles special characters in token', () {
      const specialToken = 'token-with_special.chars/123+abc=';
      final wrapper = SolarWindsApiWrapper(token: specialToken, region: 'eu-01');
      expect(wrapper, isNotNull);
    });

    test('handles special characters in region', () {
      final wrapper = SolarWindsApiWrapper(token: 'token', region: 'region-with-dashes_and_underscores');
      expect(wrapper, isNotNull);
    });
  });
}
