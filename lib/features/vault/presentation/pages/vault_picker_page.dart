import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../shared/theme/quill_tokens.dart';
import '../../../../shared/theme/tokens.dart';
import '../../../../shared/widgets/quill_icon.dart';
import '../bloc/vault_bloc.dart';
import '../bloc/vault_event.dart';
import '../bloc/vault_state.dart';

/// Shows up next to "Choose folder…" when SharedPreferences has the
/// last-opened vault path. Hidden when there's no prior vault, or when
/// the saved folder no longer exists on disk (we don't check — the
/// LoadFromPath path already surfaces missing-folder errors).
class _ReopenLastVaultButton extends StatefulWidget {
  const _ReopenLastVaultButton();

  @override
  State<_ReopenLastVaultButton> createState() => _ReopenLastVaultButtonState();
}

class _ReopenLastVaultButtonState extends State<_ReopenLastVaultButton> {
  String? _path;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString('vault.path');
    if (!mounted) return;
    setState(() => _path = s);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    final path = _path;
    if (path == null || path.isEmpty) return const SizedBox.shrink();
    return OutlinedButton.icon(
      onPressed: () => context.read<VaultBloc>().add(LoadFromPath(path)),
      icon: QuillIcon('reveal', size: 12, color: tokens.text2),
      label: Text('Reopen ${p.basename(path)}'),
      style: OutlinedButton.styleFrom(
        foregroundColor: tokens.text2,
        side: BorderSide(color: tokens.divider2, width: 0.5),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(6)),
        ),
      ),
    );
  }
}

class VaultPickerPage extends StatelessWidget {
  const VaultPickerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    return Scaffold(
      backgroundColor: tokens.bg,
      body: BlocBuilder<VaultBloc, VaultState>(
        builder: (context, state) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: tokens.accent,
                          borderRadius: const BorderRadius.all(Radius.circular(8)),
                        ),
                        child: Text(
                          'q',
                          style: mono(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Quill',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: tokens.text,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Open your vault',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: tokens.text,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'A vault is a folder of .md files. Quill never moves your files — '
                    'we just read and write them in place. Markdown on disk is the source of truth.',
                    style: TextStyle(fontSize: 14, color: tokens.text3, height: 1.55),
                  ),
                  const SizedBox(height: 24),
                  if (state is VaultLoading)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 1.5, color: tokens.text2),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Indexing ${state.rootPath ?? ''}…',
                          style: mono(fontSize: 12, color: tokens.text3),
                        ),
                      ],
                    )
                  else
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => context.read<VaultBloc>().add(const PickVault()),
                          icon: QuillIcon('folder', size: 14, color: Colors.white),
                          label: const Text('Choose folder…'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: tokens.accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.all(Radius.circular(6)),
                            ),
                          ),
                        ),
                        const _ReopenLastVaultButton(),
                      ],
                    ),
                  if (state is VaultError) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFB66954), width: 0.5),
                        borderRadius: const BorderRadius.all(Radius.circular(6)),
                      ),
                      child: Text(state.message, style: TextStyle(color: tokens.text2, fontSize: 13)),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
