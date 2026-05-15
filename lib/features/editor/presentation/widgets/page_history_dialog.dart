import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../shared/theme/quill_tokens.dart';
import '../../../../shared/theme/tokens.dart';
import '../../../../shared/widgets/quill_icon.dart';
import '../../data/page_history.dart';

/// Modal dialog that lists git commits touching [relativePath] and renders
/// the file contents at the selected commit. Restoring/diffing is future
/// work — for now it's a read-only viewer.
class PageHistoryDialog extends StatefulWidget {
  const PageHistoryDialog({
    super.key,
    required this.vaultRoot,
    required this.relativePath,
  });

  final String vaultRoot;
  final String relativePath;

  @override
  State<PageHistoryDialog> createState() => _PageHistoryDialogState();
}

class _PageHistoryDialogState extends State<PageHistoryDialog> {
  static const _history = PageHistory();
  late Future<List<PageVersion>> _commits;
  PageVersion? _selected;
  Future<String>? _content;

  @override
  void initState() {
    super.initState();
    _commits = _history.list(Directory(widget.vaultRoot), widget.relativePath);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    final size = MediaQuery.of(context).size;
    final w = size.width < 760 ? size.width - 32 : 720.0;
    final h = size.height < 560 ? size.height - 60 : 520.0;
    return Dialog(
      backgroundColor: tokens.surface,
      child: SizedBox(
        width: w,
        height: h,
        child: FutureBuilder<List<PageVersion>>(
          future: _commits,
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
            final commits = snap.data!;
            if (commits.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      QuillIcon('git',
                          size: 24,
                          strokeWidth: 1.4,
                          color: tokens.text3),
                      const SizedBox(height: 10),
                      Text('No git history',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: tokens.text2,
                          )),
                      const SizedBox(height: 4),
                      Text(
                        'Make the vault a git repo and commit\nto start tracking versions.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: tokens.text3,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            _selected ??= commits.first;
            _content ??= _history.showAt(
              Directory(widget.vaultRoot),
              widget.relativePath,
              _selected!.sha,
            );
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 260,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: tokens.divider, width: 0.5),
                          ),
                        ),
                        child: Text(
                          'HISTORY',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.0,
                            color: tokens.text3,
                          ),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: commits.length,
                          itemBuilder: (context, i) {
                            final c = commits[i];
                            final selected = c.sha == _selected?.sha;
                            return GestureDetector(
                              onTap: () => setState(() {
                                _selected = c;
                                _content = _history.showAt(
                                  Directory(widget.vaultRoot),
                                  widget.relativePath,
                                  c.sha,
                                );
                              }),
                              child: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: Container(
                                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                                  color: selected ? tokens.hover : Colors.transparent,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        c.message.split('\n').first,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          color: tokens.text,
                                          fontWeight: selected
                                              ? FontWeight.w500
                                              : FontWeight.w400,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${c.author} · ${_relativeTime(c.timestamp)}',
                                        style: mono(fontSize: 10.5, color: tokens.text3),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Container(width: 0.5, color: tokens.divider),
                Expanded(
                  child: FutureBuilder<String>(
                    future: _content,
                    builder: (context, contentSnap) {
                      if (!contentSnap.hasData) {
                        return Center(
                          child: SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 1.5, color: tokens.text2),
                          ),
                        );
                      }
                      return Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                    color: tokens.divider, width: 0.5),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Tooltip(
                                    message: _selected?.sha ?? '',
                                    waitDuration: const Duration(
                                        milliseconds: 400),
                                    child: Text(
                                      _selected?.sha.substring(0, 8) ?? '',
                                      style: mono(
                                          fontSize: 12, color: tokens.text2),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => Navigator.of(context).pop(),
                                  icon: const Icon(Icons.close, size: 18),
                                  tooltip: 'Close',
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(16),
                              child: SelectableText(
                                contentSnap.data!,
                                style:
                                    mono(fontSize: 12.5, color: tokens.text2)
                                        .copyWith(height: 1.6),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _relativeTime(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    if (d.inDays < 30) return '${d.inDays}d ago';
    return t.toIso8601String().split('T').first;
  }
}
