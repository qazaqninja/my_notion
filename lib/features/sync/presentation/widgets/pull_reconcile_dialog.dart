import 'package:flutter/material.dart';

import '../../../../shared/theme/quill_tokens.dart';
import '../../../../shared/theme/tokens.dart';
import '../../../../shared/widgets/quill_icon.dart';
import '../../domain/entities/sync_file.dart';

/// E24 — Modal that surfaces the server-side copy fetched by
/// `SyncFetchFileRequested` and lets the user decide whether to overwrite
/// their local body with it. Pure presentational widget — the bloc-side
/// dispatch is owned by the caller via the [onUseServer] / [onKeepLocal]
/// callbacks.
///
/// Layout adapts to width:
/// - >= 720 px (or `forceSideBySide: true`): two columns, local left,
///   server right.
/// - otherwise stacked vertically (mobile / narrow editor).
class PullReconcileDialog extends StatelessWidget {
  const PullReconcileDialog({
    super.key,
    required this.serverBody,
    required this.localBody,
    required this.onUseServer,
    required this.onKeepLocal,
    this.forceSideBySide = false,
  });

  final SyncFileBody serverBody;
  final String localBody;
  final VoidCallback onUseServer;
  final VoidCallback onKeepLocal;

  /// Test-only override that skips the LayoutBuilder breakpoint so the
  /// widget renders consistently regardless of the test harness size.
  final bool forceSideBySide;

  bool get _identical => serverBody.body == localBody;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<QuillTokens>()!;
    return Dialog(
      backgroundColor: tokens.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  QuillIcon('download', size: 18, color: tokens.text),
                  const SizedBox(width: 8),
                  Text(
                    _identical
                        ? 'Server copy matches local'
                        : 'Pull from server',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: tokens.text,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Dismiss',
                    onPressed: () {
                      onKeepLocal();
                      Navigator.of(context).maybePop();
                    },
                    icon: QuillIcon('x', size: 16, color: tokens.text2),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'sha ${serverBody.summary.sha256.substring(0, 8)} · '
                '${serverBody.summary.relpath}',
                style: mono(
                  color: tokens.text3,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final sideBySide =
                        forceSideBySide || constraints.maxWidth >= 720;
                    if (sideBySide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                              child: _BodyPanel(
                            title: 'Local',
                            body: localBody,
                            tokens: tokens,
                          )),
                          const SizedBox(width: 12),
                          Expanded(
                              child: _BodyPanel(
                            title: 'Server',
                            body: serverBody.body,
                            tokens: tokens,
                          )),
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                            child: _BodyPanel(
                          title: 'Local',
                          body: localBody,
                          tokens: tokens,
                        )),
                        const SizedBox(height: 8),
                        Expanded(
                            child: _BodyPanel(
                          title: 'Server',
                          body: serverBody.body,
                          tokens: tokens,
                        )),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      onKeepLocal();
                      Navigator.of(context).maybePop();
                    },
                    child: const Text('Keep local'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _identical
                        ? null
                        : () {
                            onUseServer();
                            Navigator.of(context).maybePop();
                          },
                    child: const Text('Use server version'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BodyPanel extends StatelessWidget {
  const _BodyPanel({
    required this.title,
    required this.body,
    required this.tokens,
  });

  final String title;
  final String body;
  final QuillTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: tokens.codeBg,
        border: Border.all(color: tokens.divider),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: tokens.divider),
              ),
            ),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: tokens.text2,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(10),
              child: SelectableText(
                body.isEmpty ? '(empty)' : body,
                style: mono(fontSize: 12, color: tokens.text),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
