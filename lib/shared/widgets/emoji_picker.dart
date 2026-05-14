import 'package:flutter/material.dart';

import '../theme/quill_tokens.dart';
import '../theme/tokens.dart';

/// Hand-curated emoji palette — covers the common Notion icon use cases
/// (work, docs, planning, status, faces, etc.) without pulling in a
/// 4000-glyph emoji database.
const List<String> _kCuratedEmojis = [
  // Documents & writing
  '📄', '📝', '📋', '📑', '🗒️', '📓', '📕', '📗', '📘', '📙',
  '📚', '📖', '🔖', '✏️', '🖊️', '🖋️', '🖍️', '✒️',
  // Work & calendars
  '📅', '📆', '🗓️', '📊', '📈', '📉', '🗂️', '📁', '📂',
  '🗄️', '📎', '🔗', '📍', '📌', '📐', '📏',
  // Status / signals
  '✅', '☑️', '⬜', '✔️', '❌', '⚠️', '🚧', '🛑', '🔥',
  '⭐', '🌟', '💡', '🎯', '🚀', '🏁', '⏰', '⏳', '⌛',
  // People & roles
  '👤', '👥', '👨‍💻', '👩‍💻', '🧑‍💼', '🛠️', '🧠', '🤝', '🤔',
  // Communication
  '💬', '💭', '📣', '📢', '📞', '📧', '📨', '📤', '📥',
  // Tech & data
  '💻', '🖥️', '⌨️', '🖱️', '💾', '💿', '🗃️', '🗳️', '🔒', '🔓',
  '🔑', '🛡️', '🌐', '🛰️', '🔌', '🔋', '⚙️', '🔧', '🧰',
  // Money & business
  '💰', '💵', '💳', '🏦', '🏢', '🏪', '📦', '🛒',
  // Faces (positive)
  '😀', '😃', '😄', '😁', '🙂', '😊', '🥳', '😎', '🤓', '🤩',
  // Nature & misc
  '🌱', '🌳', '🌲', '🌴', '🌵', '🌿', '☘️', '🍀', '🌷', '🌸',
  '🌹', '🌺', '🌻', '🌼', '🍎', '🍊', '🍋', '🍒', '🍓',
  // Animals
  '🐱', '🐶', '🐭', '🐰', '🦊', '🐼', '🐨', '🦁', '🐯', '🐮',
];

/// Modal grid of curated emojis. Picking one pops the dialog with the
/// chosen string. Tapping the "Clear" footer pops with empty string.
Future<String?> pickEmoji(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => const _EmojiPickerDialog(),
  );
}

class _EmojiPickerDialog extends StatefulWidget {
  const _EmojiPickerDialog();

  @override
  State<_EmojiPickerDialog> createState() => _EmojiPickerDialogState();
}

class _EmojiPickerDialogState extends State<_EmojiPickerDialog> {
  List<String> _filtered() {
    // No semantic search (no labels) — just return all unless we add a
    // name index later.
    return _kCuratedEmojis;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    final items = _filtered();
    return Dialog(
      backgroundColor: tokens.surface,
      child: SizedBox(
        width: 360,
        height: 420,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: tokens.divider, width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Text('PICK ICON',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0,
                        color: tokens.text3,
                      )),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(''),
                    child:
                        Text('Clear', style: TextStyle(color: tokens.text2)),
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
              child: GridView.builder(
                padding: const EdgeInsets.all(8),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 8,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                ),
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final glyph = items[i];
                  return GestureDetector(
                    onTap: () => Navigator.of(context).pop(glyph),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: tokens.surface2,
                          borderRadius:
                              const BorderRadius.all(Radius.circular(4)),
                        ),
                        child: Text(glyph,
                            style: const TextStyle(fontSize: 18)),
                      ),
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: tokens.divider, width: 0.5)),
              ),
              child: Text(
                '${items.length} curated · drag an emoji from the system picker for more',
                style: mono(fontSize: 10.5, color: tokens.text3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
