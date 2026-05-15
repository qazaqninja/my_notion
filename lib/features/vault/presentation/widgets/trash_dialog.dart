import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/theme/quill_tokens.dart';
import '../../../../shared/theme/tokens.dart';
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Empty trash?'),
        content: Text(
          'This permanently deletes ${items.length} '
          '${items.length == 1 ? "file" : "files"}. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete forever'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    for (final item in items) {
      await _service.deleteForever(item);
    }
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    return Dialog(
      backgroundColor: tokens.surface,
      child: SizedBox(
        width: 560,
        height: 480,
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
                    child: Text(
                      'TRASH',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0,
                        color: tokens.text3,
                      ),
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
                      child: Text(
                        'Trash is empty.',
                        style: TextStyle(fontSize: 13, color: tokens.text3),
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
                Text(item.title,
                    style: TextStyle(fontSize: 13, color: tokens.text)),
                const SizedBox(height: 2),
                Text('${item.bucket} · ${item.basename}',
                    style: mono(fontSize: 11, color: tokens.text3)),
              ],
            ),
          ),
          TextButton(
            onPressed: () async {
              final newPath =
                  await _service.restore(item, Directory(widget.vaultRoot));
              if (!mounted) return;
              context
                  .read<VaultBloc>()
                  .add(const ReindexVault());
              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                SnackBar(content: Text('Restored to $newPath')),
              );
              _refresh();
            },
            child: Text('Restore', style: TextStyle(color: tokens.accent)),
          ),
          TextButton(
            onPressed: () async {
              final ok = await _service.deleteForever(item);
              if (!ok || !mounted) return;
              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                SnackBar(content: Text('Deleted ${item.basename}')),
              );
              _refresh();
            },
            child: Text('Delete', style: TextStyle(color: tokens.text2)),
          ),
        ],
      ),
    );
  }
}
