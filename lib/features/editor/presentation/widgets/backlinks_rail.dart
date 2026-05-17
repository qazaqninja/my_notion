import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/paths.dart';
import '../../../../core/routing/routes.dart';
import '../../../../shared/theme/quill_tokens.dart';
import '../../../../shared/theme/tokens.dart';
import '../../../../shared/widgets/quill_icon.dart';
import '../../../relations/domain/repositories/relations_repository.dart';

/// Right-rail "Linked from" section. Queries Drift `relations` table for
/// inverse links and renders a card per linking page.
class BacklinksRail extends StatelessWidget {
  const BacklinksRail({super.key, required this.toUlid});
  final String toUlid;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    final repo = context.read<RelationsRepository>();
    return FutureBuilder<List<Backlink>>(
      future: repo.backlinksFor(toUlid),
      builder: (context, snap) {
        final links = snap.data ?? const [];
        if (links.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 24, bottom: 8),
              child: Row(
                children: [
                  Text(
                    'LINKED FROM',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                      color: tokens.text3,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Tooltip(
                    message: links.length == 1
                        ? '1 page links here'
                        : '${links.length} pages link here',
                    waitDuration: const Duration(milliseconds: 500),
                    child: Text('${links.length}',
                        style: mono(fontSize: 11, color: tokens.text3)),
                  ),
                ],
              ),
            ),
            for (final bl in links)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _BacklinkCard(bl: bl, tokens: tokens),
              ),
          ],
        );
      },
    );
  }
}

class _BacklinkCard extends StatefulWidget {
  const _BacklinkCard({required this.bl, required this.tokens});

  final Backlink bl;
  final QuillTokens tokens;

  @override
  State<_BacklinkCard> createState() => _BacklinkCardState();
}

class _BacklinkCardState extends State<_BacklinkCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    final bl = widget.bl;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => context.go(Routes.editor(bl.fromUlid)),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          decoration: BoxDecoration(
            color: _hover ? tokens.surface2 : tokens.surface,
            border: Border.all(
                color: _hover ? tokens.accent : tokens.divider2,
                width: 0.5),
            borderRadius: const BorderRadius.all(Radius.circular(5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  if (bl.emojiIcon != null)
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: Center(
                        child: Text(
                          bl.emojiIcon!,
                          style: const TextStyle(fontSize: 11, height: 1),
                        ),
                      ),
                    )
                  else
                    QuillIcon('file-md',
                        size: 12, strokeWidth: 1.7, color: tokens.text3),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Tooltip(
                      message: bl.title,
                      waitDuration: const Duration(milliseconds: 600),
                      child: Text(
                        bl.title,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: tokens.text,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Tooltip(
                message: bl.relativePath,
                waitDuration: const Duration(milliseconds: 600),
                child: Text(
                  stripMdExtension(bl.relativePath),
                  style: mono(fontSize: 10.5, color: tokens.text3),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                bl.snippet,
                style: TextStyle(
                  fontSize: 12,
                  color: tokens.text2,
                  fontStyle: FontStyle.italic,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
