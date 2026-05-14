/// Trello JSON export → Quill database shape.
///
/// Trello exports a board as a single JSON object with `name`, `lists`,
/// `cards`, and a long tail (members, actions, checklists, etc) we
/// don't care about. We map:
///
///   - board.name      → database folder name
///   - lists           → `status` select column options (in board order)
///   - cards           → one page per open card
///   - card.idList     → frontmatter `status:` (resolved to list name)
///   - card.labels     → frontmatter `labels: [...]` (multi)
///   - card.due        → frontmatter `due:` (YYYY-MM-DD)
///   - card.name       → page title
///   - card.desc       → page body (verbatim — Trello desc is already Markdown-ish)
///
/// Closed cards + cards in closed lists are skipped — users typically
/// don't want their archive imported.
library;

import 'dart:convert';

class TrelloCard {
  const TrelloCard({
    required this.title,
    required this.body,
    required this.status,
    required this.labels,
    this.due,
  });
  final String title;
  final String body;
  final String status;
  final List<String> labels;
  final String? due; // ISO date YYYY-MM-DD
}

class TrelloBoard {
  const TrelloBoard({
    required this.name,
    required this.statusOptions,
    required this.cards,
  });
  final String name;

  /// Open list names in board order — used as the `status` column's
  /// select options.
  final List<String> statusOptions;
  final List<TrelloCard> cards;
}

class TrelloToDatabase {
  const TrelloToDatabase._();

  /// Parse a Trello board JSON. Returns null when the file isn't a
  /// recognisable Trello export.
  static TrelloBoard? convert(String json) {
    final dynamic doc;
    try {
      doc = jsonDecode(json);
    } catch (_) {
      return null;
    }
    if (doc is! Map) return null;
    final name = '${doc['name'] ?? ''}'.trim();
    if (name.isEmpty) return null;

    final lists = doc['lists'];
    final listNames = <String, String>{};
    final closedLists = <String>{};
    final openListsInOrder = <String>[];
    if (lists is List) {
      for (final l in lists) {
        if (l is! Map) continue;
        final id = '${l['id'] ?? ''}';
        final ln = '${l['name'] ?? ''}'.trim();
        if (id.isEmpty || ln.isEmpty) continue;
        listNames[id] = ln;
        if (l['closed'] == true) {
          closedLists.add(id);
        } else {
          openListsInOrder.add(ln);
        }
      }
    }

    final out = <TrelloCard>[];
    final cards = doc['cards'];
    if (cards is List) {
      for (final c in cards) {
        if (c is! Map) continue;
        if (c['closed'] == true) continue;
        final idList = '${c['idList'] ?? ''}';
        if (closedLists.contains(idList)) continue;
        final title = '${c['name'] ?? ''}'.trim();
        if (title.isEmpty) continue;
        final status = listNames[idList] ?? '';
        final desc = '${c['desc'] ?? ''}';
        final labels = <String>[];
        final lbls = c['labels'];
        if (lbls is List) {
          for (final l in lbls) {
            if (l is Map) {
              final ln = '${l['name'] ?? ''}'.trim();
              if (ln.isNotEmpty) labels.add(ln);
            }
          }
        }
        final due = c['due'] is String && (c['due'] as String).length >= 10
            ? (c['due'] as String).substring(0, 10)
            : null;
        out.add(TrelloCard(
          title: title,
          body: desc,
          status: status,
          labels: labels,
          due: due,
        ));
      }
    }
    return TrelloBoard(
      name: name,
      statusOptions: openListsInOrder,
      cards: out,
    );
  }
}
