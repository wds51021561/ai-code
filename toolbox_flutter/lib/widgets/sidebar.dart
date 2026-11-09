import 'package:flutter/material.dart';

import '../app.dart';
import '../models/types.dart';
import '../theme/app_theme.dart';
import '../utils.dart';
import 'common.dart';

class Sidebar extends StatefulWidget {
  const Sidebar({
    super.key,
    required this.activeSavedId,
    required this.onLoadRequest,
    required this.onNewRequest,
  });

  final String? activeSavedId;
  final void Function(RequestConfig request, String? savedId) onLoadRequest;
  final VoidCallback onNewRequest;

  @override
  State<Sidebar> createState() => _SidebarState();
}

enum _SidebarTab { history, saved }

class _SidebarState extends State<Sidebar> {
  _SidebarTab _tab = _SidebarTab.history;

  Future<void> _clearHistory() async {
    final confirmed = await showConfirmDialog(
      context,
      title: '清空历史记录',
      message: '所有历史请求记录将被删除，收藏和当前请求不受影响。确定清空吗？',
      confirmLabel: '清空历史',
    );
    if (!confirmed || !mounted) return;
    context.appState.clearHistory();
    if (!mounted) return;
    showToolboxToast(context, '历史记录已清空', kind: ToastKind.success);
  }

  Future<void> _deleteSaved(SavedRequest item) async {
    final confirmed = await showConfirmDialog(
      context,
      title: '删除收藏',
      message: '确定删除收藏「${item.name}」吗？此操作无法恢复。',
      confirmLabel: '删除收藏',
    );
    if (!confirmed || !mounted) return;
    context.appState.removeSaved(item.id);
    if (!mounted) return;
    showToolboxToast(context, '收藏已删除', kind: ToastKind.success);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.appState;
    final workspace = state.workspace;
    final colors = context.colors;

    return Container(
      width: 252,
      decoration: BoxDecoration(
        color: colors.panel,
        border: Border(right: BorderSide(color: colors.line)),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 47,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Text(
                    '请求',
                    style: TextStyle(
                      color: colors.faint,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const Spacer(),
                  ToolboxButton(
                    icon: const Icon(Icons.add_rounded),
                    variant: ToolboxButtonVariant.ghost,
                    size: ToolboxButtonSize.iconSm,
                    tooltip: '新建请求',
                    onPressed: widget.onNewRequest,
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: colors.line),
                bottom: BorderSide(color: colors.line),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _SidebarTabButton(
                    icon: Icons.history_rounded,
                    label: '历史',
                    count: workspace.history.length,
                    active: _tab == _SidebarTab.history,
                    onTap: () => setState(() => _tab = _SidebarTab.history),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _SidebarTabButton(
                    icon: Icons.bookmark_border_rounded,
                    label: '收藏',
                    count: workspace.saved.length,
                    active: _tab == _SidebarTab.saved,
                    onTap: () => setState(() => _tab = _SidebarTab.saved),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _tab == _SidebarTab.history
                ? _HistoryList(
                    entries: workspace.history,
                    onLoad: (entry) =>
                        widget.onLoadRequest(entry.request, null),
                    onDelete: state.removeHistory,
                  )
                : _SavedList(
                    items: workspace.saved,
                    activeSavedId: widget.activeSavedId,
                    onLoad: (item) =>
                        widget.onLoadRequest(item.request, item.id),
                    onDelete: _deleteSaved,
                  ),
          ),
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: colors.line)),
            ),
            child: Row(
              children: [
                Text(
                  'Ctrl + Enter 发送',
                  style: TextStyle(color: colors.faint, fontSize: 10),
                ),
                const Spacer(),
                if (_tab == _SidebarTab.history && workspace.history.isNotEmpty)
                  InkWell(
                    onTap: _clearHistory,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 2, vertical: 2),
                      child: Text(
                        '清空',
                        style: TextStyle(color: colors.faint, fontSize: 10),
                      ),
                    ),
                  )
                else
                  Text(
                    '${workspace.saved.length} 条收藏',
                    style: TextStyle(color: colors.faint, fontSize: 10),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarTabButton extends StatelessWidget {
  const _SidebarTabButton({
    required this.icon,
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: active ? colors.panel2 : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: active ? Border.all(color: colors.line) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 13, color: active ? colors.accent : colors.faint),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: active ? colors.ink : colors.muted,
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '$count',
              style: TextStyle(
                color: colors.faint,
                fontFamily: monoFontFamily,
                fontSize: 9.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({
    required this.entries,
    required this.onLoad,
    required this.onDelete,
  });

  final List<HistoryEntry> entries;
  final ValueChanged<HistoryEntry> onLoad;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const EmptyState(
        icon: Icons.schedule_rounded,
        title: '暂无历史记录',
        description: '发送请求后会自动记录在这里',
        compact: true,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: _HistoryTile(
            entry: entry,
            onTap: () => onLoad(entry),
            onDelete: () => onDelete(entry.id),
          ),
        );
      },
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.entry,
    required this.onTap,
    required this.onDelete,
  });

  final HistoryEntry entry;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final errored = (entry.error ?? '').isNotEmpty;
    final status = entry.status == 0 ? null : entry.status;
    final color = status != null
        ? (errored ? colors.warning : statusColor(colors, status))
        : colors.danger;

    return HoverBuilder(
      builder: (context, hovered) {
        return Stack(
          children: [
            InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(8, 8, 28, 8),
                decoration: BoxDecoration(
                  color: hovered ? colors.panel2 : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: hovered ? colors.line : Colors.transparent,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        MethodBadge(method: entry.request.method, minWidth: 44),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            requestDisplayUrl(entry.request),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.ink,
                              fontFamily: monoFontFamily,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          formatRelativeTime(entry.at),
                          style: TextStyle(color: colors.faint, fontSize: 10),
                        ),
                        const SizedBox(width: 6),
                        Text('·',
                            style: TextStyle(
                                color: colors.lineStrong, fontSize: 10)),
                        const SizedBox(width: 6),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                              color: color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          status == null ? 'ERR' : '$status',
                          style: TextStyle(color: color, fontSize: 10),
                        ),
                        if (entry.duration != null) ...[
                          const SizedBox(width: 6),
                          Text('·',
                              style: TextStyle(
                                  color: colors.lineStrong, fontSize: 10)),
                          const SizedBox(width: 6),
                          Text(
                            '${entry.duration!.round()} ms',
                            style: TextStyle(color: colors.faint, fontSize: 10),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (hovered)
              Positioned(
                top: 4,
                right: 4,
                child: ToolboxButton(
                  icon: const Icon(Icons.delete_outline_rounded),
                  variant: ToolboxButtonVariant.ghost,
                  size: ToolboxButtonSize.iconSm,
                  tooltip: entry.error ?? '删除历史',
                  onPressed: onDelete,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SavedList extends StatelessWidget {
  const _SavedList({
    required this.items,
    required this.activeSavedId,
    required this.onLoad,
    required this.onDelete,
  });

  final List<SavedRequest> items;
  final String? activeSavedId;
  final ValueChanged<SavedRequest> onLoad;
  final ValueChanged<SavedRequest> onDelete;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const EmptyState(
        icon: Icons.bookmark_border_rounded,
        title: '暂无收藏',
        description: '点击请求栏右侧「保存」收藏当前请求',
        compact: true,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: _SavedTile(
            item: item,
            active: item.id == activeSavedId,
            onTap: () => onLoad(item),
            onDelete: () => onDelete(item),
          ),
        );
      },
    );
  }
}

class _SavedTile extends StatelessWidget {
  const _SavedTile({
    required this.item,
    required this.active,
    required this.onTap,
    required this.onDelete,
  });

  final SavedRequest item;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return HoverBuilder(
      builder: (context, hovered) {
        return Stack(
          children: [
            InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(8, 8, 28, 8),
                decoration: BoxDecoration(
                  color: active
                      ? colors.accentSoft
                      : (hovered ? colors.panel2 : Colors.transparent),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: active
                        ? colors.accent.withValues(alpha: 0.25)
                        : (hovered ? colors.line : Colors.transparent),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.ink,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        MethodBadge(method: item.request.method, minWidth: 44),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            requestDisplayUrl(item.request),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.muted,
                              fontFamily: monoFontFamily,
                              fontSize: 10.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '更新于 ${formatRelativeTime(item.updatedAt)}',
                      style: TextStyle(color: colors.faint, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),
            if (hovered)
              Positioned(
                top: 4,
                right: 4,
                child: ToolboxButton(
                  icon: const Icon(Icons.delete_outline_rounded),
                  variant: ToolboxButtonVariant.ghost,
                  size: ToolboxButtonSize.iconSm,
                  tooltip: '删除收藏',
                  onPressed: onDelete,
                ),
              ),
          ],
        );
      },
    );
  }
}
