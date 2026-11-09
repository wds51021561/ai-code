import 'package:flutter_test/flutter_test.dart';
import 'package:toolbox_flutter/models/defaults.dart';
import 'package:toolbox_flutter/models/types.dart';
import 'package:toolbox_flutter/utils.dart';

void main() {
  group('extractUrlQuery', () {
    test('splits query parameters and preserves hash', () {
      final result =
          extractUrlQuery('https://x.dev/users?a=1&b=hello%20world#top');
      expect(result, isNotNull);
      expect(result!.url, 'https://x.dev/users#top');
      expect(result.params.map((item) => item.key), ['a', 'b']);
      expect(result.params.map((item) => item.value), ['1', 'hello world']);
    });

    test('returns null when there is no query', () {
      expect(extractUrlQuery('https://x.dev/users'), isNull);
      expect(extractUrlQuery('https://x.dev/users?'), isNull);
    });
  });

  group('suggestedRequestName', () {
    test('uses the last path segments', () {
      expect(
        suggestedRequestName(createEmptyRequest(url: '{{baseUrl}}/todos/1')),
        'todos/1',
      );
      expect(
        suggestedRequestName(
            createEmptyRequest(url: 'https://x.dev/users/42?x=1')),
        'users/42',
      );
      expect(
        suggestedRequestName(createEmptyRequest(url: 'https://x.dev/')),
        'x.dev',
      );
    });
  });

  group('prettyJson', () {
    test('formats valid json and keeps invalid text', () {
      final formatted = prettyJson('{"a":1}');
      expect(formatted.isJson, isTrue);
      expect(formatted.text, '{\n  "a": 1\n}');

      final raw = prettyJson('not json');
      expect(raw.isJson, isFalse);
      expect(raw.text, 'not json');
    });
  });

  group('resolveVariables', () {
    test('environment variables override globals', () {
      final workspace = createDefaultWorkspace();
      workspace.globalVariables = [
        Variable(key: 'baseUrl', value: 'https://global.example.com'),
        Variable(key: 'globalOnly', value: 'yes'),
      ];
      final variables = resolveVariables(workspace);
      expect(variables['baseUrl'], 'https://jsonplaceholder.typicode.com');
      expect(variables['globalOnly'], 'yes');
    });
  });

  test('format helpers use human readable units', () {
    expect(formatBytes(0), '0 B');
    expect(formatBytes(1024), '1.0 KB');
    expect(formatDuration(24.6), '25 ms');
    expect(formatDuration(1500), '1.50 s');
  });
}
