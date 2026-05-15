import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/theme/quill_tokens.dart';
import '../../../../shared/theme/tokens.dart';
import '../../../../shared/widgets/quill_icon.dart';
import '../../../../shared/widgets/quill_overlays.dart';
import '../../data/trash_service.dart';
import '../bloc/vault_bloc.dart';
import '../bloc/vault_event.dart';

class TrashDialog extends StatefulWidget {
  const TrashDialog({super.key, required this.vaultRoot});
  final String vaultRoot;

  @override
  State<TrashDialog> createState() => _TrashDialogState();
}

class _TrashDialogState extends State<TrashDialog> {
  late Future<List<TrashedItem>> _items;
  static const _service = TrashService();

  @override
  void initState() {
    super.initState();
    _items = _service.list(Directory(widget.vaultRoot));
  }

  void _refresh() => setState(() {
        _items = _service.list(Directory(widget.vaultRoot));
      });

  Future<void> _confirmEmpty(BuildContext context) async {
    final items = await _items;
    if (items.isEmpty || !context.mounted) return;
    final ok = await showQuillConfirm(
      context,
      title: 'Empty trash?',
      sub:
          'This permanently deletes ${items.length} ${items.length == 1 ? "file" : "files"}. This cannot be undone.',
      icon: 'trash',
      confirmLabel: 'Delete forever',
      danger: true,
    );
    if (!ok) return;
    var deleted = 0;
    for (final item in items) {
      if (await _service.deleteForever(item)) deleted++;
    }
    if (!context.mounted) return;
    final failed = items.length - deleted;
    if (failed > 0) {
      // Some files couldn't be deleted — permission, locked by
      // another process, etc. Tell the user how many made it through
      // and how many didn't, since the dialog count was already
      // confirmed and they expect a complete cleanup.
      context.toastWarn(
          'Emptied $deleted of ${items.length}',
          sub: '$failed ${failed == 1 ? "file" : "files"} could not be deleted');
    } else {
      context.toastSuccess(
          'Emptied trash · $deleted ${deleted == 1 ? "file" : "files"}');
    }
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    final size = MediaQuery.of(context).size;
    final w = size.width < 600 ? size.width - 32 : 560.0;
    final h = size.height < 520 ? size.height - 60 : 480.0;
    return Dialog(
      backgroundColor: tokens.surface,
      child: SizedBox(
        width: w,
        height: h,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 10, 10),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: tokens.divider, width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: FutureBuilder<List<TrashedItem>>(
                      future: _items,
                      builder: (context, snap) {
                        final n = snap.data?.length ?? 0;
                        return Tooltip(
                          message: n == 0
                              ? 'Trash is empty'
                              : n == 1
                                  ? '1 trashed item'
                                  : '$n trashed items',
                          waitDuration:
                              const Duration(milliseconds: 500),
                          child: Text(
                            n == 0 ? 'TRASH' : 'TRASH · $n',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.0,
                              color: tokens.text3,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _confirmEmpty(context),
                    icon: const Icon(Icons.delete_outline, size: 14),
                    label: const Text('Empty trash'),
                    style: TextButton.styleFrom(
                      foregroundColor: tokens.text2,
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<TrashedItem>>(
                future: _items,
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return Center(
                      child: SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 1.5, color: tokens.text2),
                      ),
                    );
                  }
                  final items = snap.data!;
                  if (items.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            QuillIcon('trash',
                                size: 24,
                                strokeWidth: 1.4,
                                color: tokens.text3),
                            const SizedBox(height: 10),
                            Text('Trash is empty',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: tokens.text2,
                                )),
                            const SizedBox(height: 2),
                            Text(
                              'Deleted pages will appear here.',
                              style: TextStyle(
                                  fontSize: 12, color: tokens.text3),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final item = items[i];
                      return _row(item, tokens);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(TrashedItem item, QuillTokens tokens) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.divider, width: 0.5)),
      ),
      child: Row(
        children: [
          if (item.emojiIcon != null)
            SizedBox(
              width: 16,
              height: 16,
              child: Center(
                child: Text(item.emojiIcon!,
                    style: const TextStyle(fontSize: 14, height: 1)),
              ),
            )
          else
            Icon(Icons.delete_outline, size: 16, color: tokens.text3),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Tooltip(
                  message: item.title,
                  waitDuration: const Duration(milliseconds: 600),
                  child: Text(
                    item.title,
                    style: TextStyle(fontSize: 13, color: tokens.text),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Tooltip(
                  message: '${item.bucket} · ${item.basename}',
                  waitDuration: const Duration(milliseconds: 600),
                  child: Text(
                    '${item.bucket} · ${item.basename}',
                    style: mono(fontSize: 11, color: tokens.text3),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () async {
              try {
                final newPath = await _service.restore(
                    item, Directory(widget.vaultRoot));
                if (!mounted) return;
                context.read<VaultBloc>().add(const ReindexVault());
                context.toastSuccess(
                    item.title.isEmpty
                        ? 'Restored ${item.basename}'
                        : 'Restored "${item.title}"',
                    sub: newPath,
                    subMono: true);
                _refresh();
              } catch (e) {
                if (!mounted) return;
                context.toastError('Restore failed', sub: '$e');
              }
            },
            child: Text('Restore', style: TextStyle(color: tokens.accent)),
          ),
          TextButton(
            onPressed: () async {
              final confirmed = await showQuillConfirm(
                context,
                title: 'Delete forever?',
                sub:
                    'This permanently deletes "${item.title}". This cannot be undone.',
                icon: 'trash',
                confirmLabel: 'Delete forever',
                danger: true,
              );
              if (!confirmed || !mounted) return;
              final ok = await _service.deleteForever(item);
              if (!ok || !mounted) return;
              context.toastSuccess(
                  item.title.isEmpty
                      ? 'Deleted ${item.basename}'
                      : 'Deleted "${item.title}"',
                  sub: item.basename,
                  subMono: true);
              _refresh();
            },
            child: Text('Delete', style: TextStyle(color: tokens.text2)),
          ),
        ],
      ),
    );
  }
}
