/// Pure-Dart emoji shortcode lookup. Maps `:tada:` → `🎉` etc. The
/// set is intentionally short (the 50 most-used emoji across Slack /
/// Discord / Notion); adding the full Unicode list would balloon the
/// table for marginal benefit.
library;

const Map<String, String> kEmojiShortcodes = {
  // People + faces
  'smile': '😄',
  'grin': '😁',
  'joy': '😂',
  'laughing': '😆',
  'wink': '😉',
  'blush': '😊',
  'heart_eyes': '😍',
  'sunglasses': '😎',
  'thinking': '🤔',
  'sob': '😭',
  'cry': '😢',
  'sweat_smile': '😅',
  'pray': '🙏',
  'wave': '👋',
  'clap': '👏',
  'muscle': '💪',
  'point_right': '👉',
  'eyes': '👀',
  'thumbsup': '👍',
  '+1': '👍',
  'thumbsdown': '👎',
  '-1': '👎',
  // Hearts + symbols
  'heart': '❤️',
  'broken_heart': '💔',
  'sparkles': '✨',
  'fire': '🔥',
  '100': '💯',
  'tada': '🎉',
  'rocket': '🚀',
  'star': '⭐',
  'warning': '⚠️',
  'white_check_mark': '✅',
  'x': '❌',
  'question': '❓',
  'exclamation': '❗',
  // Work / objects
  'bulb': '💡',
  'memo': '📝',
  'pencil': '✏️',
  'pushpin': '📌',
  'paperclip': '📎',
  'book': '📖',
  'bookmark': '🔖',
  'mag': '🔍',
  'lock': '🔒',
  'unlock': '🔓',
  'key': '🔑',
  'hammer': '🔨',
  'wrench': '🔧',
  'gear': '⚙️',
  'package': '📦',
  'inbox_tray': '📥',
  'outbox_tray': '📤',
  // Weather + nature
  'sun': '☀️',
  'moon': '🌙',
  'star2': '🌟',
  'snowflake': '❄️',
  'umbrella': '☂️',
  'coffee': '☕',
};

/// Replace every `:name:` shortcode in [source] with its emoji. Unknown
/// shortcodes are left as-is so the user can still type `:foo:` as
/// literal text. Returns the new string.
///
/// Recognises only well-formed `[a-z0-9_+\-]+` between the colons —
/// avoids accidentally rewriting `[link text]: target` reference-link
/// definitions or YAML mappings like `key: value`.
String replaceEmojiShortcodes(String source) {
  if (source.isEmpty) return source;
  return source.replaceAllMapped(
    RegExp(r':([a-z0-9_+\-]+):'),
    (match) => kEmojiShortcodes[match.group(1)!] ?? match.group(0)!,
  );
}
