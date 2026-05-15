import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/theme/quill_tokens.dart';
import '../../../vault/domain/entities/frontmatter_entry.dart';
import '../bloc/editor_bloc.dart';
import '../bloc/editor_event.dart';
import '../bloc/editor_state.dart';

/// Large editable title at the top of the editor. Click → TextField,
/// commits on Enter / blur. Edits dispatch through the existing
/// EditFrontmatterField / AddFrontmatterField path so the frontmatter
/// `title:` stays in sync — the page filename does NOT rename automatically
/// (a future enhancement; for now title is a frontmatter value and the
/// .md filename stays stable).
class PageTitleField extends StatefulWidget {
  const PageTitleField({super.key, required this.title});
  final String title;

  @override
  State<PageTitleField> createState() => _PageTitleFieldState();
}

class _PageTitleFieldState extends State<PageTitleField> {
  bool _editing = false;
  final FocusNode _focus = FocusNode();
  late final TextEditingController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = TextEditingController(text: widget.title);
  }

  @override
  void didUpdateWidget(PageTitleField old) {
    super.didUpdateWidget(old);
    if (!_editing && widget.title != _ctl.text) {
      _ctl.text = widget.title;
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    _ctl.dispose();
    super.dispose();
  }

  void _start() {
    setState(() => _editing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focus.requestFocus();
      _ctl.selection =
          TextSelection(baseOffset: 0, extentOffset: _ctl.text.length);
    });
  }

  void _commit() {
    final next = _ctl.text.trim();
    setState(() => _editing = false);
    if (next.isEmpty || next == widget.title) return;
    final bloc = context.read<EditorBloc>();
    final state = bloc.state;
    if (state is! EditorLoaded) return;
    final existing = state.page.frontmatter.find('title');
    if (existing == null) {
      bloc.add(AddFrontmatterField(FrontmatterEntry(
        key: 'title',
        rawScalar: next,
        type: FrontmatterType.text,
        value: next,
      )));
    } else {
      bloc.add(EditFrontmatterField(
        'title',
        existing.copyWith(rawScalar: next, value: next),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    final style = TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.w700,
      color: tokens.text,
      letterSpacing: -0.6,
      height: 1.2,
    );
    if (!_editing) {
      final isEmpty = widget.title.trim().isEmpty;
      return GestureDetector(
        onTap: _start,
        behavior: HitTestBehavior.opaque,
        child: MouseRegion(
          cursor: SystemMouseCursors.text,
          child: Tooltip(
            message: isEmpty
                ? 'Click to set a page title'
                : 'Click to rename · saved to frontmatter `title:`',
            waitDuration: const Duration(milliseconds: 600),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 18, 0, 8),
              child: Text(
                isEmpty ? 'Untitled' : widget.title,
                style: isEmpty
                    ? style.copyWith(
                        color: tokens.text3, fontStyle: FontStyle.italic)
                    : style,
              ),
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 18, 0, 8),
      child: TextField(
        controller: _ctl,
        focusNode: _focus,
        onSubmitted: (_) => _commit(),
        onTapOutside: (_) {
          if (_editing) _commit();
        },
        maxLines: null,
        style: style,
        decoration: const InputDecoration(
          isCollapsed: true,
          border: InputBorder.none,
        ),
      ),
    );
  }
}
