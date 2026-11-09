import 'package:flutter_test/flutter_test.dart';
import 'package:toolbox_flutter/services/request/interpolate.dart';

void main() {
  const variables = {
    'baseUrl': 'https://api.example.com',
    'token': 'secret-token',
    'user.id': '42',
  };

  group('interpolateString', () {
    test('replaces variables including dotted names and whitespace', () {
      expect(
        interpolateString('{{baseUrl}}/users/{{ user.id }}', variables),
        'https://api.example.com/users/42',
      );
    });

    test('leaves unknown variables untouched', () {
      expect(
        interpolateString('{{baseUrl}}/{{missing}}', variables),
        'https://api.example.com/{{missing}}',
      );
    });

    test('interpolates nested values', () {
      final result = interpolateUnknown(
        {
          'url': '{{baseUrl}}/login',
          'headers': ['Bearer {{token}}'],
          'retry': 2,
        },
        variables,
      );
      expect(result, {
        'url': 'https://api.example.com/login',
        'headers': ['Bearer secret-token'],
        'retry': 2,
      });
    });
  });

  group('hasUnresolvedVariables', () {
    test('detects remaining placeholders', () {
      expect(hasUnresolvedVariables('{{baseUrl}}/users'), isTrue);
      expect(hasUnresolvedVariables('https://api.example.com/users'), isFalse);
    });
  });
}
