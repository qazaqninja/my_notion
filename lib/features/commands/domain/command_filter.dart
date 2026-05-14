/// Parsed filter scope for command-palette queries. The cubit uses
/// this to decide which underlying source (pages / databases / path
/// walk) to query, and how to display the results.
enum CommandFilterScope { none, db, tag, path }

class CommandFilter {
  const CommandFilter(this.scope, this.term);
  final CommandFilterScope scope;
  final String term;

  /// Recognised prefixes that scope the search:
  /// - `db:foo` / `@db:foo` / `database:foo` → databases by name.
  /// - `tag:foo` / `@tag:foo` → pages with frontmatter `tags:` matching.
  /// - `in:Inbox` / `path:Inbox/` / `@in:Inbox` / `folder:Inbox` →
  ///   pages whose `relativePath` starts with the rest.
  ///
  /// Anything else falls through to a normal FTS search.
  static CommandFilter parse(String q) {
    final raw = q.trim();
    if (raw.isEmpty) return const CommandFilter(CommandFilterScope.none, '');
    final s = raw.startsWith('@') ? raw.substring(1) : raw;
    final colon = s.indexOf(':');
    if (colon <= 0) return CommandFilter(CommandFilterScope.none, raw);
    final prefix = s.substring(0, colon).toLowerCase();
    final rest = s.substring(colon + 1).trim();
    switch (prefix) {
      case 'db':
      case 'database':
        return CommandFilter(CommandFilterScope.db, rest);
      case 'tag':
        return CommandFilter(CommandFilterScope.tag, rest);
      case 'in':
      case 'path':
      case 'folder':
        return CommandFilter(CommandFilterScope.path, rest);
      default:
        return CommandFilter(CommandFilterScope.none, raw);
    }
  }
}
