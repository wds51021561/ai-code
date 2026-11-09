import 'defaults.dart';
import 'types.dart';

/// Parses and normalizes a workspace exported by either the Electron or Flutter
/// version. Returns null when the payload is clearly not a Toolbox workspace.
Workspace? normalizeWorkspace(dynamic raw) {
  if (raw is! Map) return null;
  if (raw['version'] != 1) return null;
  try {
    final workspace = Workspace.fromJson(raw);
    if (workspace.version != 1) return null;

    normalizeRequest(workspace.draft);
    for (final saved in workspace.saved) {
      normalizeRequest(saved.request);
    }
    for (final entry in workspace.history) {
      normalizeRequest(entry.request);
    }

    if (workspace.activeEnvId != null &&
        !workspace.environments.any(
          (environment) => environment.id == workspace.activeEnvId,
        )) {
      workspace.activeEnvId = workspace.environments.isEmpty
          ? null
          : workspace.environments.first.id;
    }

    if (workspace.history.length > 100) {
      workspace.history = workspace.history.take(100).toList();
    }

    return workspace;
  } catch (_) {
    return null;
  }
}
