import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../shared/theme/quill_tokens.dart';
import '../../../../shared/theme/tokens.dart';
import '../../../../shared/widgets/quill_icon.dart';
import '../../data/comments_service.dart';

class CommentsDialog extends StatefulWidget {
  const CommentsDialog({
    super.key,
    required this.vaultRoot,
    required this.pageUlid,
    required this.defaultAuthor,
    this.blockId,
  });

  final String vaultRoot;
  final String pageUlid;
  final String defaultAuthor;

  /// When set, the dialog scopes to a single block: list filters to
  /// `c.blockId == blockId`, and new comments are tagged with this
  /// blockId. Header shows the block's last-6 ULID chars so the user
  /// knows which anchor they're looking at.
  final String? blockId;

  @override
  State<CommentsDialog> createState() => _CommentsDialogState();
}

class _CommentsDialogState extends State<CommentsDialog> {
  static const _service = CommentsService();
  late Future<List<PageComment>> _items;
  final _bodyCtl = TextEditingController();
  late final TextEditingController _authorCtl;

  @override
  void initState() {
    super.initState();
    _authorCtl = TextEditingController(text: widget.defaultAuthor);
    _refresh();
  }

  @override
  void dispose() {
    _bodyCtl.dispose();
    _authorCtl.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      final blockId = widget.blockId;
      _items = blockId == null
          ? _service.list(Directory(widget.vaultRoot), widget.pageUlid)
          : _service.listForBlock(
              Directory(widget.vaultRoot), widget.pageUlid, blockId);
    });
  }

  Future<void> _submit() async {
    final body = _bodyCtl.text.trim();
    if (body.isEmpty) return;
    await _service.add(
      Directory(widget.vaultRoot),
      widget.pageUlid,
      author: _authorCtl.text.trim().isEmpty
          ? widget.defaultAuthor
          : _authorCtl.text.trim(),
      body: body,
      blockId: widget.blockId,
    );
    _bodyCtl.clear();
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    return Dialog(
      backgroundColor: tokens.surface,
      child: SizedBox(
        width: 480,
        height: 520,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 10, 10),
              decoration: BoxDecoration(
                border: Border(
                    bottom: BorderSide(color: tokens.divider, width: 0.5)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Text('COMMENTS',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.0,
                              color: tokens.text3,
                            )),
                        if (widget.blockId != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: tokens.surface2,
                              borderRadius:
                                  const BorderRadius.all(Radius.circular(3)),
                            ),
                            child: Text(
                              'block · ${widget.blockId!.substring(widget.blockId!.length - 6)}',
                              style: mono(
                                  fontSize: 10, color: tokens.text2),
                            ),
                          ),
                        ],
                      ],
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
              child: FutureBuilder<List<PageComment>>(
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
                            QuillIcon('note',
                                size: 24,
                                strokeWidth: 1.4,
                                color: tokens.text3),
                            const SizedBox(height: 10),
                            Text('No comments yet',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: tokens.text2,
                                )),
                            const SizedBox(height: 2),
                            Text(
                              'Start the thread below.',
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
                    itemBuilder: (context, i) => _row(items[i], tokens),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: tokens.divider, width: 0.5)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SizedBox(
                    width: 110,
                    child: TextField(
                      controller: _authorCtl,
                      style: mono(fontSize: 12, color: tokens.text2),
                      decoration: const InputDecoration(
                        isCollapsed: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 6),
                        hintText: 'author',
                        border: UnderlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _bodyCtl,
                      minLines: 1,
                      maxLines: 4,
                      onSubmitted: (_) => _submit(),
                      style: TextStyle(fontSize: 13, color: tokens.text),
                      decoration: InputDecoration(
                        isCollapsed: true,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                        hintText: 'Add a comment…',
                        hintStyle: TextStyle(fontSize: 12.5, color: tokens.text3),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: tokens.divider2),
                          borderRadius: const BorderRadius.all(Radius.circular(4)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: tokens.divider2),
                          borderRadius: const BorderRadius.all(Radius.circular(4)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    onPressed: _submit,
                    icon: Icon(Icons.send, size: 18, color: tokens.accent),
                    tooltip: 'Post comment (↵)',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(PageComment c, QuillTokens tokens) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.divider, width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(c.author.isEmpty ? 'anon' : c.author,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: c.resolved ? tokens.text3 : tokens.text)),
              const SizedBox(width: 8),
              Text(_relativeTime(c.timestamp),
                  style: mono(fontSize: 11, color: tokens.text3)),
              // Block-scope badge — only shown when the dialog is in
              // page scope (no widget.blockId) and the comment itself
              // is anchored to a block. The header already conveys the
              // scope when widget.blockId is set.
              if (widget.blockId == null && c.blockId != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: tokens.surface2,
                    borderRadius:
                        const BorderRadius.all(Radius.circular(3)),
                  ),
                  child: Text(
                    'block · ${c.blockId!.substring(c.blockId!.length - 6)}',
                    style: mono(fontSize: 10, color: tokens.text3),
                  ),
                ),
              ],
              const Spacer(),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.all(2),
                constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                onPressed: () async {
                  await _service.setResolved(
                    Directory(widget.vaultRoot),
                    widget.pageUlid,
                    c.id,
                    !c.resolved,
                  );
                  _refresh();
                },
                tooltip: c.resolved ? 'Reopen' : 'Mark resolved',
                icon: Icon(
                  c.resolved
                      ? Icons.check_circle
                      : Icons.check_circle_outline,
                  size: 14,
                  color: c.resolved ? tokens.accent : tokens.text3,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.all(2),
                constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                onPressed: () async {
                  await _service.delete(
                      Directory(widget.vaultRoot), widget.pageUlid, c.id);
                  _refresh();
                },
                tooltip: 'Delete',
                icon: Icon(Icons.close, size: 13, color: tokens.text3),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            c.body,
            style: TextStyle(
              fontSize: 13,
              color: c.resolved ? tokens.text3 : tokens.text,
              decoration: c.resolved
                  ? TextDecoration.lineThrough
                  : TextDecoration.none,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  String _relativeTime(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    if (d.inDays < 30) return '${d.inDays}d';
    return t.toIso8601String().split('T').first;
  }
}
