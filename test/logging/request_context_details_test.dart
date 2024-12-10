import 'package:dart_frog_shared/logging/request_context_details.dart';
import 'package:test/test.dart';

void main() {
  group('RequestContextDetails', () {
    group('obfuscateUserData', () {
      test('obfuscates password field', () {
        final input = {'username': 'john', 'password': 'secret123'};
        final result = RequestContextDetails.obfuscateUserData(input);
        expect(result, {'username': 'john', 'password': '***(9)'});
      });

      test('obfuscates authorization field with Bearer token', () {
        final input = {'authorization': 'Bearer abcdefghijklmnopqrstuvwxyz123456'};
        final result = RequestContextDetails.obfuscateUserData(input);
        expect(result, {'authorization': 'Bearer ***yz123456(39)'});
      });

      test('obfuscates authorization field without Bearer prefix', () {
        final input = {'authorization': 'abcdefghijklmnopqrstuvwxyz123456'};
        final result = RequestContextDetails.obfuscateUserData(input);
        expect(result, {'authorization': '***yz123456(32)'});
      });

      test('obfuscates id_token field', () {
        final input = {
          'id_token':
              'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dozjgNryP4J3jVmNHl0w5N_XgL0n3I9PlFUP0THsR8U'
        };
        final result = RequestContextDetails.obfuscateUserData(input);
        expect(result, {'id_token': '***P0THsR8U(108)'});
      });

      test('handles mixed case keys', () {
        final input = {'Username': 'john', 'PASSWORD': 'secret123', 'Authorization': 'Bearer token123'};
        final result = RequestContextDetails.obfuscateUserData(input);
        expect(result, {'Username': 'john', 'PASSWORD': '***(9)', 'Authorization': 'Bearer ***token123(15)'});
      });

      test('handles empty input', () {
        final input = <String, dynamic>{};
        final result = RequestContextDetails.obfuscateUserData(input);
        expect(result, {});
      });

      test('handles null input', () {
        final result = RequestContextDetails.obfuscateUserData(null);
        expect(result, null);
      });

      test('handles non-map input', () {
        const input = 'not a map';
        final result = RequestContextDetails.obfuscateUserData(input);
        expect(result, 'not a map');
      });

      test('handles short authorization tokens', () {
        final input = {'authorization': 'short'};
        final result = RequestContextDetails.obfuscateUserData(input);
        expect(result, {'authorization': '***short(5)'});
      });

      test('handles short id_tokens', () {
        final input = {'id_token': 'short'};
        final result = RequestContextDetails.obfuscateUserData(input);
        expect(result, {'id_token': '***short(5)'});
      });

      test('preserves other fields', () {
        final input = {
          'username': 'john',
          'password': 'secret123',
          'email': 'john@example.com',
          'age': 30,
          'is_admin': false,
        };
        final result = RequestContextDetails.obfuscateUserData(input);
        expect(result, {
          'username': 'john',
          'password': '***(9)',
          'email': 'john@example.com',
          'age': 30,
          'is_admin': false,
        });
      });

      test('handles nested maps', () {
        final input = {
          'user': {
            'username': 'john',
            'password': 'secret123',
          },
          'token': {
            'authorization': 'Bearer abcdefghijklmnopqrstuvwxyz123456',
          },
        };
        final result = RequestContextDetails.obfuscateUserData(input);
        expect(result, {
          'user': {
            'username': 'john',
            'password': 'secret123',
          },
          'token': {
            'authorization': 'Bearer abcdefghijklmnopqrstuvwxyz123456',
          },
        });
      });
    });
  });
}
