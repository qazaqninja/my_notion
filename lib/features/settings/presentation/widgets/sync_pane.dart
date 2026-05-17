import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/theme/quill_tokens.dart';
import '../../../../shared/widgets/quill_overlays.dart';
import '../../../sync/domain/usecases/collect_bulk_push_entries.dart';
import '../../../sync/presentation/bloc/sync_bloc.dart';
import '../../../sync/presentation/bloc/sync_event.dart';
import '../../../sync/presentation/bloc/sync_state.dart';
import '../../../sync/presentation/widgets/sync_connected_card.dart';
import '../../../vault/presentation/bloc/vault_bloc.dart';
import '../../../vault/presentation/bloc/vault_state.dart';

/// Phase E E14 (M1312): Settings → Sync pane.
/// Exposes the SyncBloc state to the user: login / signup form when
/// disconnected, status + logout when connected, error chip on
/// failure.
///
/// Extracted from settings_page.dart in M1423 (FS-04 slice 2) —
/// the sync cluster (this pane + _SyncLoginCard + the bulk-push
/// helper) was the next-largest single concern after FormsPane
/// landed in its own file.
class SyncPane extends StatelessWidget {
  const SyncPane({super.key, required this.tokens});

  final QuillTokens tokens;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SyncBloc, SyncState>(
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sync target',
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
                'Connect your vault to a self-hosted Quill v2 backend for '
                'multi-device sync, public page sharing, and (eventually) '
                'multiplayer. The backend lives at `http://localhost:8080` '
                'in dev — production deploys swap the URL in app.dart.',
                style:
                    TextStyle(fontSize: 13, color: tokens.text3, height: 1.5),
              ),
            ),
            const SizedBox(height: 18),
            if (state.isAuthed)
              SyncConnectedCard(
                state: state,
                tokens: tokens,
                onPushAll: () => _onPushAllUnsynced(context),
              )
            else
              _SyncLoginCard(state: state, tokens: tokens),
            if (state.lastError != null && state.lastError != 'conflict') ...[
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .errorContainer
                      .withValues(alpha: 0.4),
                  borderRadius: const BorderRadius.all(Radius.circular(4)),
                ),
                child: Text(
                  state.lastError!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  /// E32 — walk the vault tree, read every `.md` file, compute sha256,
  /// and dispatch `SyncPushAllRequested`. The bloc handler skips
  /// entries whose local sha already matches `knownShas[relpath]`,
  /// so re-clicking the button after a successful seed is a no-op.
  ///
  /// CA-04 note (M1423 audit): the orchestrator suggested passing
  /// `VaultState? vault` as a prop instead of importing VaultBloc
  /// here. We deliberately keep the inline `context.read<VaultBloc>`
  /// inside this async callback: the user may tap "Push all" several
  /// seconds after build, by which point a prop snapshot could be
  /// stale (vault picker swap, reindex completion). Reading inside
  /// the callback always gets the live state.
  Future<void> _onPushAllUnsynced(BuildContext context) async {
    final vault = context.read<VaultBloc>().state;
    if (vault is! VaultLoaded) {
      context.toastWarn('No vault open', sub: 'Pick a vault folder first.');
      return;
    }
    final sync = context.read<SyncBloc>();
    if (!sync.state.isAuthed) {
      context.toastWarn('Not logged in',
          sub: 'Sign in to the v2 backend first.');
      return;
    }
    final entries = await collectBulkPushEntries(
      tree: vault.tree,
      vaultRoot: vault.rootPath,
    );
    if (entries.isEmpty) {
      if (context.mounted) {
        context.toastInfo('No files to push', sub: 'Vault is empty.');
      }
      return;
    }
    sync.add(SyncPushAllRequested(entries));
    if (context.mounted) {
      context.toastInfo(
        'Bulk push queued',
        sub: '${entries.length} file${entries.length == 1 ? '' : 's'}',
      );
    }
  }
}

class _SyncLoginCard extends StatefulWidget {
  const _SyncLoginCard({required this.state, required this.tokens});
  final SyncState state;
  final QuillTokens tokens;

  @override
  State<_SyncLoginCard> createState() => _SyncLoginCardState();
}

class _SyncLoginCardState extends State<_SyncLoginCard> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit({required bool signup}) {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) return;
    final bloc = context.read<SyncBloc>();
    if (signup) {
      bloc.add(SyncSignupRequested(email: email, password: password));
    } else {
      bloc.add(SyncLoginRequested(email: email, password: password));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    final busy = widget.state.status == SyncStatus.loading;
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
          TextField(
            controller: _email,
            enabled: !busy,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _password,
            obscureText: true,
            enabled: !busy,
            decoration: const InputDecoration(
              labelText: 'Password (8+ chars)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onSubmitted: (_) => _submit(signup: false),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              FilledButton(
                onPressed: busy ? null : () => _submit(signup: false),
                child: const Text('Log in'),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: busy ? null : () => _submit(signup: true),
                child: const Text('Sign up'),
              ),
              if (busy) ...[
                const SizedBox(width: 14),
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
