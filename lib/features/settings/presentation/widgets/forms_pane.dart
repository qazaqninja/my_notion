import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/theme/quill_tokens.dart';
import '../../../../shared/theme/tokens.dart';
import '../../../../shared/widgets/quill_overlays.dart';
import '../../../forms/domain/entities/form_bearing_page.dart';
import '../../../forms/domain/repositories/form_bearing_pages_repository.dart';
import '../../../forms/domain/repositories/forms_repository.dart';
import '../../../forms/presentation/cubit/form_bearing_pages_cubit.dart';
import '../../../forms/presentation/widgets/form_submissions_dialog.dart';
import '../../../sync/presentation/bloc/sync_bloc.dart';

/// E58b-iii — Settings → Forms pane. Lists every form-bearing page
/// in the current vault via DriftFormBearingPagesRepository → the
/// local Drift cache, NOT a network call. Each row taps into the
/// existing FormSubmissionsDialog (E51) — same widget the editor's
/// kebab uses, so authors get one consistent surface for browsing
/// submissions whether they came in via Settings or the editor.
///
/// Auth gating happens at row-tap time (not pane-mount) so the
/// pane still renders the list even when the user isn't signed
/// into the backend; the dialog itself is the gate.
///
/// Extracted from settings_page.dart in M1421 (FS-04 slice 1) —
/// the pane was the biggest single addition pushing the page past
/// the 2,000-line threshold. Promoted to a public `FormsPane`
/// since the test target is at the widget level, not a private
/// implementation detail of the settings page.
class FormsPane extends StatelessWidget {
  const FormsPane({super.key, required this.tokens});

  final QuillTokens tokens;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<FormBearingPagesCubit>(
      create: (ctx) =>
          FormBearingPagesCubit(repo: ctx.read<FormBearingPagesRepository>())
            ..load(),
      child: BlocBuilder<FormBearingPagesCubit, FormBearingPagesState>(
        builder: (context, state) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Forms',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: tokens.text,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: 600,
                child: Text(
                  'Pages that declare a `forms:` frontmatter entry. '
                  'Tap a row to browse the submissions that have come '
                  'in for it. The public form URL is a kebab action '
                  'on each editor page (Copy form link).',
                  style: TextStyle(
                      fontSize: 13, color: tokens.text3, height: 1.5),
                ),
              ),
              const SizedBox(height: 18),
              if (state.status == FormBearingPagesStatus.loading &&
                  state.pages.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 1.5, color: tokens.text2),
                  ),
                )
              else if (state.status == FormBearingPagesStatus.failure)
                _FormsErrorRow(
                  message: state.lastError ?? 'Unknown error',
                  onRetry: () =>
                      context.read<FormBearingPagesCubit>().load(),
                  tokens: tokens,
                )
              else if (state.pages.isEmpty)
                _FormsEmptyState(tokens: tokens)
              else
                for (final p in state.pages)
                  _FormBearingPageRow(page: p, tokens: tokens),
            ],
          );
        },
      ),
    );
  }
}

class _FormBearingPageRow extends StatelessWidget {
  const _FormBearingPageRow({required this.page, required this.tokens});
  final FormBearingPage page;
  final QuillTokens tokens;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openSubmissions(context),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    page.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: tokens.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    page.relativePath,
                    style: TextStyle(fontSize: 12, color: tokens.text3),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: tokens.chipBg,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                page.formsRef,
                style: mono(fontSize: 11, color: tokens.text3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSubmissions(BuildContext context) async {
    final sync = context.read<SyncBloc>();
    final token = sync.state.token;
    if (token == null || !sync.state.isAuthed) {
      context.toastWarn('Not logged in',
          sub: 'Sign in to view submissions.');
      return;
    }
    final repo = context.read<FormsRepository>();
    await showDialog<void>(
      context: context,
      builder: (_) => FormSubmissionsDialog(
        ulid: page.ulid,
        load: () => repo.listSubmissions(token: token, ulid: page.ulid),
      ),
    );
  }
}

class _FormsEmptyState extends StatelessWidget {
  const _FormsEmptyState({required this.tokens});
  final QuillTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: SizedBox(
        width: 600,
        child: Text(
          "No form-bearing pages yet. Add `forms: true` to a "
          "page's frontmatter (or `forms: path/to.database.yaml` "
          "for typed schemas) to surface it here.",
          style: TextStyle(fontSize: 13, color: tokens.text3, height: 1.5),
        ),
      ),
    );
  }
}

class _FormsErrorRow extends StatelessWidget {
  const _FormsErrorRow({
    required this.message,
    required this.onRetry,
    required this.tokens,
  });
  final String message;
  final VoidCallback onRetry;
  final QuillTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 16, color: tokens.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Could not load form-bearing pages: $message',
              style: TextStyle(fontSize: 13, color: tokens.text2),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
