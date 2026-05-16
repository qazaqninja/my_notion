import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/theme/quill_tokens.dart';
import '../bloc/sync_bloc.dart';
import '../bloc/sync_event.dart';
import '../bloc/sync_state.dart';

/// Settings → Sync "connected" card. Shows the logged-in indicator, a
/// Log out button, the last successful push, and any unresolved
/// conflict from the most recent failed push with a one-tap Retry pull.
///
/// Lives under `features/sync/presentation/widgets/` so it can be
/// pumped in isolation from settings_page.dart's sidebar chrome (which
/// runs a fixed-width nav `Row` that overflows the default test
/// viewport).
class SyncConnectedCard extends StatelessWidget {
  const SyncConnectedCard({
    super.key,
    required this.state,
    required this.tokens,
  });

  final SyncState state;
  final QuillTokens tokens;

  @override
  Widget build(BuildContext context) {
    final lastPush = state.lastPush;
    final conflict = state.lastConflict;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surface2,
        border: Border.all(color: tokens.divider2, width: 0.5),
        borderRadius: const BorderRadius.all(Radius.circular(6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.green.shade400,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Connected',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: tokens.text,
                  ),
                ),
              ),
              OutlinedButton(
                onPressed: () => context
                    .read<SyncBloc>()
                    .add(const SyncLogoutRequested()),
                child: const Text('Log out'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _ActivityRow(
            label: 'Last push',
            value: lastPush == null
                ? '—'
                : '${lastPush.relpath} · ${syncRelativeTime(lastPush.mtime)}',
            sub: lastPush == null
                ? null
                : 'sha ${_shortSha(lastPush.sha256)}…',
            tokens: tokens,
          ),
          if (conflict != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: tokens.dangerTint,
                border: Border.all(color: tokens.danger, width: 0.5),
                borderRadius: const BorderRadius.all(Radius.circular(4)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Unresolved conflict',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: tokens.danger,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${conflict.relpath} · server sha '
                          '${_shortSha(conflict.sha256)}…',
                          style: TextStyle(
                            fontSize: 12,
                            color: tokens.text2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed: () => context.read<SyncBloc>().add(
                          SyncFetchFileRequested(relpath: conflict.relpath),
                        ),
                    child: const Text('Retry pull'),
                  ),
                ],
              ),
            ),
          ],
          // E28 — un-classified `lastError` (anything except the four
          // structured codes we already render elsewhere) is treated as
          // a transient network failure. Surface it inline with a
          // 'Retry now' button so the user can re-arm the sync round-
          // trip without restarting the app.
          if (isNetworkError(state.lastError)) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: tokens.surface,
                border: Border.all(color: tokens.divider2, width: 0.5),
                borderRadius: const BorderRadius.all(Radius.circular(4)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Network error',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: tokens.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          state.lastError ?? '',
                          style: TextStyle(
                            fontSize: 12,
                            color: tokens.text2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed: () => context
                        .read<SyncBloc>()
                        .add(const SyncListRequested()),
                    child: const Text('Retry now'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Error codes the rest of the UI already renders structurally
/// (toasts, dialogs, banners). Anything else gets treated as a generic
/// network error by `SyncConnectedCard` and surfaced with a Retry now.
const _kStructuredSyncErrors = <String>{
  'conflict',
  'not_found',
  'token_invalid',
  'not_authenticated',
  'invalid_credentials',
  'invalid_signup',
  'email_taken',
};

/// Whether [code] (typically `SyncState.lastError`) represents a
/// generic / network-class error that should surface in the sync card
/// rather than a flow-specific toast or banner.
bool isNetworkError(String? code) {
  if (code == null || code.isEmpty) return false;
  return !_kStructuredSyncErrors.contains(code);
}

/// First 8 chars of a sha, or the whole thing if it's shorter — keeps
/// the activity row from blowing up on placeholder hashes in tests.
String _shortSha(String sha) =>
    sha.length >= 8 ? sha.substring(0, 8) : sha;

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.label,
    required this.value,
    required this.tokens,
    this.sub,
  });
  final String label;
  final String value;
  final String? sub;
  final QuillTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: tokens.text3),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(fontSize: 12, color: tokens.text2),
              ),
              if (sub != null)
                Text(
                  sub!,
                  style: TextStyle(
                    fontSize: 11,
                    color: tokens.text3,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Compact relative time formatter — `now`, `Xs ago`, `Xm ago`,
/// `Xh ago`, `Xd ago`. Exposed for unit tests.
String syncRelativeTime(DateTime when) {
  final diff = DateTime.now().difference(when);
  if (diff.isNegative) return 'just now';
  if (diff.inSeconds < 5) return 'now';
  if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}
