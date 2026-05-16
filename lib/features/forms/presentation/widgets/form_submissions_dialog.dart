import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../shared/theme/quill_tokens.dart';
import '../../../../shared/theme/tokens.dart';
import '../../../../shared/widgets/quill_icon.dart';
import '../../domain/entities/form_submission.dart';
import '../../domain/repositories/forms_repository.dart';

/// E51 — owner-facing dialog that lists form submissions for the page
/// at [ulid]. Pure presentation: the [load] callback is what actually
/// calls the repository (decoupled so widget tests can supply a fake
/// future without standing up the full HTTP client).
class FormSubmissionsDialog extends StatefulWidget {
  const FormSubmissionsDialog({
    super.key,
    required this.ulid,
    required this.load,
  });

  final String ulid;
  final Future<List<FormSubmission>> Function() load;

  @override
  State<FormSubmissionsDialog> createState() => _FormSubmissionsDialogState();
}

class _FormSubmissionsDialogState extends State<FormSubmissionsDialog> {
  late Future<List<FormSubmission>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.load();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<QuillTokens>()!;
    return Dialog(
      backgroundColor: tokens.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  QuillIcon('inbox', size: 18, color: tokens.text),
                  const SizedBox(width: 8),
                  Text(
                    'Form submissions',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: tokens.text,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Dismiss',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: QuillIcon('x', size: 16, color: tokens.text2),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                widget.ulid,
                style: mono(color: tokens.text3, fontSize: 12),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: FutureBuilder<List<FormSubmission>>(
                  future: _future,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.6,
                            color: tokens.accent,
                          ),
                        ),
                      );
                    }
                    if (snap.hasError) {
                      return _ErrorView(
                        error: snap.error!,
                        tokens: tokens,
                        onRetry: () => setState(() {
                          _future = widget.load();
                        }),
                      );
                    }
                    final submissions = snap.data ?? const [];
                    if (submissions.isEmpty) {
                      return Center(
                        child: Text(
                          'No submissions yet.',
                          style: TextStyle(
                            color: tokens.text3,
                            fontSize: 13,
                          ),
                        ),
                      );
                    }
                    return ListView.separated(
                      itemCount: submissions.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 12,
                        color: tokens.divider2,
                      ),
                      itemBuilder: (_, i) =>
                          _SubmissionTile(submission: submissions[i], tokens: tokens),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubmissionTile extends StatelessWidget {
  const _SubmissionTile({required this.submission, required this.tokens});

  final FormSubmission submission;
  final QuillTokens tokens;

  static const _jsonEncoder = JsonEncoder.withIndent('  ');

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: tokens.surface2,
        border: Border.all(color: tokens.divider, width: 0.5),
        borderRadius: const BorderRadius.all(Radius.circular(4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  submission.createdAt.toIso8601String(),
                  style: mono(color: tokens.text2, fontSize: 12),
                ),
              ),
              if (submission.sourceIp != null)
                Text(
                  'from ${submission.sourceIp}',
                  style: TextStyle(color: tokens.text3, fontSize: 11),
                ),
            ],
          ),
          const SizedBox(height: 6),
          SelectableText(
            _jsonEncoder.convert(submission.fields),
            style: mono(color: tokens.text, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.error,
    required this.tokens,
    required this.onRetry,
  });

  final Object error;
  final QuillTokens tokens;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final String label = switch (error) {
      FormsNotOwnerException _ =>
        "This page is not yours, or it hasn't been published yet.",
      FormsAuthException _ => 'Session expired — log in again.',
      final FormsNetworkException e => 'Network: ${e.message}',
      _ => error.toString(),
    };
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(color: tokens.text2, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
