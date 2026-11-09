import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/types.dart';

class ExportOutcome {
  const ExportOutcome(
      {required this.ok, this.canceled = false, this.path, this.error});
  final bool ok;
  final bool canceled;
  final String? path;
  final String? error;
}

class ImportOutcome {
  const ImportOutcome({
    required this.ok,
    this.canceled = false,
    this.path,
    this.data,
    this.error,
  });
  final bool ok;
  final bool canceled;
  final String? path;
  final dynamic data;
  final String? error;
}

class StorageService {
  Future<Directory> workspaceDirectory() async {
    if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'];
      if (appData != null && appData.isNotEmpty) {
        return Directory(p.join(appData, 'Toolbox'));
      }
    }
    if (Platform.isMacOS) {
      final home = Platform.environment['HOME'];
      if (home != null && home.isNotEmpty) {
        return Directory(
            p.join(home, 'Library', 'Application Support', 'Toolbox'));
      }
    }
    final home =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (home != null && home.isNotEmpty) {
      return Directory(p.join(home, '.local', 'share', 'toolbox'));
    }
    return Directory(p.join(Directory.current.path, '.toolbox'));
  }

  Future<File> workspaceFile() async {
    final directory = await workspaceDirectory();
    await directory.create(recursive: true);
    return File(p.join(directory.path, 'workspace.json'));
  }

  Future<File?> _legacyElectronWorkspace() async {
    if (!Platform.isWindows) return null;
    final appData = Platform.environment['APPDATA'];
    if (appData == null || appData.isEmpty) return null;
    for (final name in ['toolbox', 'Toolbox', 'devtoolbox']) {
      final file = File(p.join(appData, name, 'workspace.json'));
      if (await file.exists()) return file;
    }
    return null;
  }

  Future<dynamic> load() async {
    final file = await workspaceFile();
    if (await file.exists()) {
      return _readJson(file, backupOnError: true);
    }
    final legacy = await _legacyElectronWorkspace();
    if (legacy != null) {
      return _readJson(legacy, backupOnError: false);
    }
    return null;
  }

  dynamic _readJson(File file, {required bool backupOnError}) {
    try {
      return jsonDecode(file.readAsStringSync());
    } catch (_) {
      if (backupOnError) {
        try {
          final backup =
              '${file.path}.corrupt-${DateTime.now().millisecondsSinceEpoch}';
          file.renameSync(backup);
        } catch (_) {
          // A fresh workspace will be created when the file cannot be backed up.
        }
      }
      return null;
    }
  }

  Future<bool> save(Workspace workspace) async {
    final file = await workspaceFile();
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(
      const JsonEncoder.withIndent('  ').convert(workspace.toJson()),
      flush: true,
    );
    try {
      await temporary.rename(file.path);
    } catch (_) {
      if (await file.exists()) {
        await file.delete();
      }
      await temporary.rename(file.path);
    }
    return true;
  }

  String defaultExportName() {
    final now = DateTime.now();
    final date = '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    return 'toolbox-workspace-$date.json';
  }

  Future<ExportOutcome> exportTo(String path, Workspace workspace) async {
    try {
      final file = File(path);
      await file.parent.create(recursive: true);
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(workspace.toJson()),
        flush: true,
      );
      return ExportOutcome(ok: true, path: path);
    } catch (error) {
      return ExportOutcome(ok: false, error: error.toString());
    }
  }

  Future<ImportOutcome> importFrom(String path) async {
    try {
      final file = File(path);
      final content = await file.readAsString();
      return ImportOutcome(ok: true, path: path, data: jsonDecode(content));
    } catch (error) {
      return ImportOutcome(ok: false, error: '读取文件失败：$error');
    }
  }

  String defaultDirectoryPath() {
    if (Platform.isWindows) {
      final profile = Platform.environment['USERPROFILE'];
      if (profile != null && profile.isNotEmpty) {
        final documents = Directory(p.join(profile, 'Documents'));
        if (documents.existsSync()) return documents.path;
        return profile;
      }
    }
    final home =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    return home ?? Directory.current.path;
  }
}
