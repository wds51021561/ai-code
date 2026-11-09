import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../theme/app_theme.dart';
import 'common.dart';

enum _FileDialogMode { open, save }

Future<String?> showOpenWorkspaceFileDialog(
  BuildContext context, {
  required String initialDirectory,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _FileBrowserDialog(
      mode: _FileDialogMode.open,
      initialDirectory: initialDirectory,
      suggestedName: '',
    ),
  );
}

Future<String?> showSaveWorkspaceFileDialog(
  BuildContext context, {
  required String initialDirectory,
  required String suggestedName,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _FileBrowserDialog(
      mode: _FileDialogMode.save,
      initialDirectory: initialDirectory,
      suggestedName: suggestedName,
    ),
  );
}

class _FileBrowserDialog extends StatefulWidget {
  const _FileBrowserDialog({
    required this.mode,
    required this.initialDirectory,
    required this.suggestedName,
  });

  final _FileDialogMode mode;
  final String initialDirectory;
  final String suggestedName;

  @override
  State<_FileBrowserDialog> createState() => _FileBrowserDialogState();
}

class _FileBrowserDialogState extends State<_FileBrowserDialog> {
  late Directory _directory;
  late final TextEditingController _nameController =
      TextEditingController(text: widget.suggestedName);
  List<FileSystemEntity> _entries = const [];
  String? _error;
  String? _selectedFile;

  bool get _isSave => widget.mode == _FileDialogMode.save;

  @override
  void initState() {
    super.initState();
    _directory = _existingDirectory(widget.initialDirectory);
    if (_directory.path != Directory(widget.initialDirectory).path) {
      final profile =
          Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
      if (profile != null && profile.isNotEmpty) {
        final documents = Directory(p.join(profile, 'Documents'));
        if (documents.existsSync()) _directory = documents;
      }
    }
    _loadEntries();
  }

  Directory _existingDirectory(String path) {
    var directory = Directory(path);
    for (var attempt = 0; attempt < 12; attempt++) {
      if (directory.existsSync()) return directory;
      final parent = directory.parent;
      if (parent.path == directory.path) break;
      directory = parent;
    }
    return Directory.current;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _loadEntries() {
    try {
      final items = _directory.listSync(followLinks: false).where((entity) {
        final name = p.basename(entity.path);
        if (name.startsWith('.')) return false;
        return entity is Directory || entity is File;
      }).toList();
      items.sort((left, right) {
        final leftDir = left is Directory;
        final rightDir = right is Directory;
        if (leftDir != rightDir) return leftDir ? -1 : 1;
        return p.basename(left.path).toLowerCase().compareTo(
              p.basename(right.path).toLowerCase(),
            );
      });
      setState(() {
        _entries = items;
        _error = null;
        _selectedFile = null;
      });
    } catch (error) {
      setState(() {
        _entries = const [];
        _selectedFile = null;
        _error = '无法读取目录：$error';
      });
    }
  }

  void _navigate(Directory directory) {
    setState(() => _directory = directory);
    _loadEntries();
  }

  void _goUp() {
    final parent = _directory.parent;
    if (parent.path == _directory.path) return;
    _navigate(parent);
  }

  void _selectFile(File file) {
    setState(() {
      _selectedFile = file.path;
      if (_isSave) _nameController.text = p.basename(file.path);
    });
  }

  void _openSelected() {
    if (_isSave) {
      _save();
      return;
    }
    if (_selectedFile == null) return;
    Navigator.of(context).pop(_selectedFile);
  }

  void _save() {
    var name = _nameController.text.trim();
    if (name.isEmpty) return;
    if (!name.toLowerCase().endsWith('.json')) name = '$name.json';
    final path = p.join(_directory.path, name);
    Navigator.of(context).pop(path);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final entries = _entries.where((entity) {
      return entity is Directory ||
          _isSave ||
          p.basename(entity.path).toLowerCase().endsWith('.json');
    }).toList();
    return Dialog(
      backgroundColor: colors.panel,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.line),
      ),
      child: SizedBox(
        width: 760,
        height: 540,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 14, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isSave ? '导出工作区' : '导入工作区',
                          style: TextStyle(
                            color: colors.ink,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isSave
                              ? '选择保存目录并填写文件名。'
                              : '选择要导入的 Toolbox 工作区 JSON 文件。',
                          style: TextStyle(color: colors.muted, fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                  ToolboxButton(
                    icon: const Icon(Icons.close_rounded),
                    variant: ToolboxButtonVariant.ghost,
                    size: ToolboxButtonSize.iconSm,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: colors.panel2.withValues(alpha: 0.4),
                border: Border(
                  top: BorderSide(color: colors.line),
                  bottom: BorderSide(color: colors.line),
                ),
              ),
              child: Row(
                children: [
                  ToolboxButton(
                    icon: const Icon(Icons.arrow_upward_rounded),
                    variant: ToolboxButtonVariant.ghost,
                    size: ToolboxButtonSize.iconSm,
                    tooltip: '上一级',
                    onPressed: _directory.parent.path == _directory.path
                        ? null
                        : _goUp,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: colors.panel,
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: colors.line),
                      ),
                      child: SelectableText(
                        _directory.path,
                        maxLines: 1,
                        style: TextStyle(
                          color: colors.muted,
                          fontFamily: monoFontFamily,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style:
                              TextStyle(color: colors.danger, fontSize: 11.5),
                        ),
                      ),
                    )
                  : _entries.isEmpty
                      ? const EmptyState(
                          icon: Icons.folder_open_rounded,
                          title: '目录为空',
                          description: '没有可显示的文件或文件夹',
                          compact: true,
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          itemCount: entries.length,
                          itemBuilder: (context, index) {
                            final entity = entries[index];
                            final name = p.basename(entity.path);
                            final isDirectory = entity is Directory;
                            final isSelected =
                                !isDirectory && _selectedFile == entity.path;
                            return InkWell(
                              onTap: () => isDirectory
                                  ? _navigate(entity)
                                  : _selectFile(entity as File),
                              onDoubleTap: () {
                                if (isDirectory) {
                                  _navigate(entity);
                                } else {
                                  _selectFile(entity as File);
                                  _openSelected();
                                }
                              },
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 1),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 9),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? colors.accentSoft
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(7),
                                  border: Border.all(
                                    color: isSelected
                                        ? colors.accent.withValues(alpha: 0.25)
                                        : Colors.transparent,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isDirectory
                                          ? Icons.folder_outlined
                                          : Icons.description_outlined,
                                      size: 16,
                                      color: isDirectory
                                          ? colors.accent
                                          : colors.muted,
                                    ),
                                    const SizedBox(width: 9),
                                    Expanded(
                                      child: Text(
                                        name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: isSelected
                                              ? colors.ink
                                              : colors.muted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: BoxDecoration(
                color: colors.panel2.withValues(alpha: 0.6),
                border: Border(top: BorderSide(color: colors.line)),
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _isSave
                        ? Row(
                            children: [
                              Icon(Icons.save_outlined,
                                  size: 14, color: colors.faint),
                              const SizedBox(width: 7),
                              Expanded(
                                child: TextField(
                                  controller: _nameController,
                                  onChanged: (_) => setState(() {}),
                                  onSubmitted: (_) => _save(),
                                  style: TextStyle(
                                    color: colors.ink,
                                    fontFamily: monoFontFamily,
                                    fontSize: 11.5,
                                  ),
                                  cursorColor: colors.accent,
                                  decoration: InputDecoration(
                                    hintText: 'toolbox-workspace.json',
                                    hintStyle: TextStyle(
                                      color: colors.faint,
                                      fontSize: 11.5,
                                    ),
                                    filled: true,
                                    fillColor: colors.panel,
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(7),
                                      borderSide:
                                          BorderSide(color: colors.line),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(7),
                                      borderSide: BorderSide(
                                        color: colors.accent
                                            .withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Text(
                            _selectedFile == null
                                ? '请选择一个 .json 文件'
                                : p.basename(_selectedFile!),
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _selectedFile == null
                                  ? colors.faint
                                  : colors.muted,
                              fontFamily: monoFontFamily,
                              fontSize: 10.5,
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  ToolboxButton(
                    label: '取消',
                    variant: ToolboxButtonVariant.ghost,
                    size: ToolboxButtonSize.sm,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  ToolboxButton(
                    label: _isSave ? '保存' : '打开',
                    variant: ToolboxButtonVariant.primary,
                    size: ToolboxButtonSize.sm,
                    onPressed: _isSave
                        ? (_nameController.text.trim().isEmpty ? null : _save)
                        : (_selectedFile == null ? null : _openSelected),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
