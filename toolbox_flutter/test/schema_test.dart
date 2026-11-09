import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:toolbox_flutter/models/defaults.dart';
import 'package:toolbox_flutter/models/schema.dart';
import 'package:toolbox_flutter/models/types.dart';

void main() {
  test('normalizes the default workspace and restores plugins', () {
    final raw = jsonDecode(jsonEncode(createDefaultWorkspace().toJson()));
    final workspace = normalizeWorkspace(raw);
    expect(workspace, isNotNull);
    expect(workspace!.draft.plugins.map((plugin) => plugin.id), [
      'hmac-sha256',
      'aes-256-gcm',
    ]);
    expect(workspace.draft.params, isNotEmpty);
  });

  test('merges missing and unknown plugins while keeping order', () {
    final raw = createDefaultWorkspace().toJson();
    raw['draft'] = {
      ...raw['draft'] as Map<String, dynamic>,
      'plugins': [
        {
          'id': 'aes-256-gcm',
          'enabled': true,
          'config': {'secret': 'x'},
        },
        {'id': 'unknown-plugin', 'enabled': true, 'config': {}},
        {'id': 'aes-256-gcm', 'enabled': false, 'config': {}},
      ],
    };

    final workspace = normalizeWorkspace(raw);
    expect(workspace, isNotNull);
    expect(workspace!.draft.plugins.length, 2);
    expect(workspace.draft.plugins.first.id, 'aes-256-gcm');
    expect(workspace.draft.plugins.first.enabled, isTrue);
    expect(workspace.draft.plugins.last.id, 'hmac-sha256');
    expect(workspace.draft.plugins.last.enabled, isFalse);
  });

  test('falls back to the first environment and caps history', () {
    final workspace = createDefaultWorkspace();
    workspace.activeEnvId = 'missing-env';
    workspace.history = List.generate(
      105,
      (index) => HistoryEntry(
        request: createEmptyRequest(url: 'https://example.com/$index'),
        at: index,
      ),
    );

    final normalized = normalizeWorkspace(
      jsonDecode(jsonEncode(workspace.toJson())),
    );
    expect(normalized, isNotNull);
    expect(normalized!.activeEnvId, workspace.environments.first.id);
    expect(normalized.history.length, 100);
  });

  test('rejects invalid workspaces', () {
    expect(normalizeWorkspace('not-a-workspace'), isNull);
    final raw = createDefaultWorkspace().toJson();
    raw['version'] = 2;
    expect(normalizeWorkspace(raw), isNull);
  });
}
