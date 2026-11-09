import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/defaults.dart';
import '../models/schema.dart';
import '../models/types.dart';
import '../services/request/pipeline.dart';
import '../services/storage_service.dart';
import '../utils.dart';

class AppState extends ChangeNotifier {
  AppState({StorageService? storage, RequestEngine? engine})
      : _storage = storage ?? StorageService(),
        _engine = engine ?? RequestEngine();

  final StorageService _storage;
  final RequestEngine _engine;

  Workspace workspace = createDefaultWorkspace();
  bool hydrated = false;
  SendResult? response;
  bool sending = false;
  String? activeRequestId;
  bool envManagerOpen = false;
  int draftRevision = 0;

  Timer? _saveTimer;
  bool _disposed = false;

  Future<void> load() async {
    try {
      final raw = await _storage.load();
      workspace = normalizeWorkspace(raw) ?? createDefaultWorkspace();
    } catch (_) {
      workspace = createDefaultWorkspace();
    }
    hydrated = true;
    _notify(save: false);
  }

  void _notify({bool save = true}) {
    if (save) _scheduleSave();
    if (!_disposed) notifyListeners();
  }

  void _scheduleSave() {
    if (!hydrated) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 250), () {
      unawaited(_storage.save(workspace).catchError((_) => false));
    });
  }

  Future<void> flush() async {
    if (!hydrated) return;
    _saveTimer?.cancel();
    try {
      await _storage.save(workspace);
    } catch (_) {
      // Ignore persistence errors while shutting down.
    }
  }

  Future<ExportOutcome> exportWorkspaceTo(String path) =>
      _storage.exportTo(path, workspace);

  Future<ImportOutcome> importWorkspaceFrom(String path) =>
      _storage.importFrom(path);

  String get defaultExportName => _storage.defaultExportName();

  String get defaultDirectoryPath => _storage.defaultDirectoryPath();

  void hydrate(Workspace next) {
    workspace = next;
    hydrated = true;
    _notify(save: false);
  }

  void replaceWorkspace(Workspace next) {
    _engine.abortAll();
    workspace = next;
    response = null;
    sending = false;
    activeRequestId = null;
    draftRevision++;
    _notify();
  }

  void setTheme(ThemeModeOption theme) {
    workspace.theme = theme;
    _notify();
  }

  void toggleTheme() {
    setTheme(workspace.theme == ThemeModeOption.dark
        ? ThemeModeOption.light
        : ThemeModeOption.dark);
  }

  void setActiveEnv(String? environmentId) {
    workspace.activeEnvId = environmentId;
    _notify();
  }

  void setEnvManagerOpen(bool open) {
    envManagerOpen = open;
    _notify(save: false);
  }

  void updateDraft(void Function(RequestConfig request) mutate) {
    mutate(workspace.draft);
    _notify();
  }

  void replaceDraft(RequestConfig request) {
    workspace.draft = cloneRequest(request);
    response = null;
    draftRevision++;
    _notify();
  }

  void resetDraft() {
    workspace.draft = createEmptyRequest();
    response = null;
    draftRevision++;
    _notify();
  }

  String addEnvironment() {
    final environment = Environment(
      name: '新环境 ${workspace.environments.length + 1}',
    );
    workspace.environments.add(environment);
    workspace.activeEnvId ??= environment.id;
    _notify();
    return environment.id;
  }

  void updateEnvironment(
    String id, {
    String? name,
    List<Variable>? variables,
  }) {
    for (final environment in workspace.environments) {
      if (environment.id != id) continue;
      if (name != null) environment.name = name;
      if (variables != null) environment.variables = variables;
      break;
    }
    _notify();
  }

  void deleteEnvironment(String id) {
    workspace.environments.removeWhere((environment) => environment.id == id);
    if (workspace.activeEnvId == id) {
      workspace.activeEnvId = workspace.environments.isEmpty
          ? null
          : workspace.environments.first.id;
    }
    _notify();
  }

  void setGlobalVariables(List<Variable> variables) {
    workspace.globalVariables = variables;
    _notify();
  }

  void addHistory(HistoryEntry entry) {
    workspace.history.insert(0, entry);
    if (workspace.history.length > 100) {
      workspace.history = workspace.history.take(100).toList();
    }
    _notify();
  }

  void removeHistory(String id) {
    workspace.history.removeWhere((entry) => entry.id == id);
    _notify();
  }

  void clearHistory() {
    workspace.history.clear();
    _notify();
  }

  String saveRequest(String name, [String? existingId]) {
    final trimmedName = name.trim();
    final now = DateTime.now().millisecondsSinceEpoch;
    final request = cloneRequest(workspace.draft);

    if (existingId != null) {
      for (final saved in workspace.saved) {
        if (saved.id != existingId) continue;
        saved.name = trimmedName.isEmpty ? saved.name : trimmedName;
        saved.request
          ..method = request.method
          ..url = request.url
          ..params = request.params
          ..headers = request.headers
          ..body = request.body
          ..auth = request.auth
          ..plugins = request.plugins
          ..settings = request.settings;
        saved.updatedAt = now;
        workspace.saved.removeWhere((item) => item.id == existingId);
        workspace.saved.insert(0, saved);
        _notify();
        return existingId;
      }
    }

    final saved = SavedRequest(
      name: trimmedName.isEmpty ? '未命名请求' : trimmedName,
      request: request,
      updatedAt: now,
    );
    workspace.saved.insert(0, saved);
    _notify();
    return saved.id;
  }

  void removeSaved(String id) {
    workspace.saved.removeWhere((item) => item.id == id);
    _notify();
  }

  void beginRequest(String requestId) {
    activeRequestId = requestId;
    sending = true;
    response = null;
    _notify(save: false);
  }

  bool finishRequest(String requestId, SendResult result) {
    if (activeRequestId != requestId) return false;
    activeRequestId = null;
    sending = false;
    response = result;
    _notify(save: false);
    return true;
  }

  Future<SendResult?> sendDraft() async {
    if (sending) return null;
    final request = cloneRequest(workspace.draft);
    final variables = resolveVariables(workspace);
    final requestId = makeId('req');
    beginRequest(requestId);

    final result = await _engine.send(
      requestId: requestId,
      request: request,
      variables: variables,
    );
    final accepted = finishRequest(requestId, result);
    if (!accepted) return null;

    addHistory(
      HistoryEntry(
        request: request,
        status: result.status == 0 ? null : result.status,
        duration: result.duration,
        error: result.error,
      ),
    );
    return result;
  }

  Future<void> cancelActiveRequest() async {
    final requestId = activeRequestId;
    if (requestId == null) return;
    await _engine.cancel(requestId);
    activeRequestId = null;
    sending = false;
    response = null;
    _notify(save: false);
  }

  void clearResponse() {
    response = null;
    _notify(save: false);
  }

  @override
  void dispose() {
    _disposed = true;
    _saveTimer?.cancel();
    _engine.abortAll();
    super.dispose();
  }
}
