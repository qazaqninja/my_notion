import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../shared/theme/quill_tokens.dart';
import '../../../../shared/theme/tokens.dart';
import '../../data/comments_service.dart';

class CommentsDialog extends StatefulWidget {
  const CommentsDialog({
    super.key,
    required this.vaultRoot,
    required this.pageUlid,
    required this.defaultAuthor,
  });

  final String vaultRoot;
  final String pageUlid;
  final String defaultAuthor;

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
      _items = _service.list(Directory(widget.vaultRoot), widget.pageUlid);
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
                    child: Text('COMMENTS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.0,
                          color: tokens.text3,
                        )),
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
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          'No comments yet. Start the thread below.',
                          style: TextStyle(fontSize: 13, color: tokens.text3),
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
