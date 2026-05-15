import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show OrderingTerm, OrderingMode;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/db/quill_database.dart' hide Page;
import '../../../../core/markdown/frontmatter_icon.dart';
import '../../../../shared/theme/quill_tokens.dart';
import '../../../../shared/theme/tokens.dart';
import '../../../../shared/widgets/quill_icon.dart';
import '../../../commands/presentation/cubit/command_palette_cubit.dart';
import '../../data/daily_note.dart';
import '../bloc/vault_bloc.dart';
import '../bloc/vault_event.dart';
import '../bloc/vault_state.dart';
import '../widgets/page_header.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    final state = context.watch<VaultBloc>().state;
    return Column(
      children: [
        const PageHeader(crumbs: ['Home']),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(48, 32, 48, 80),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome to Quill',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: tokens.text,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  state is VaultLoaded
                      ? 'Your vault has ${state.pageCount} indexed pages.'
                      : 'Choose a vault to get started.',
                  style: TextStyle(fontSize: 14, color: tokens.text3, height: 1.55),
                ),
                const SizedBox(height: 32),
                Row(children: [
                  _Tile(
                    tokens: tokens,
                    icon: 'search',
                    title: 'Search & open',
                    subtitle: 'Cmd+K to find any page or database.',
                    onTap: () =>
                        context.read<CommandPaletteCubit>().open(),
                  ),
                  const SizedBox(width: 16),
                  _Tile(
                    tokens: tokens,
                    icon: 'database',
                    title: 'Databases',
                    subtitle: 'Browse every .database.yaml in the vault.',
                    onTap: () => context.go('/databases'),
                  ),
                  const SizedBox(width: 16),
                  _Tile(
                    tokens: tokens,
                    icon: 'gear',
                    title: 'Settings',
                    subtitle: 'Workspace, theme, export, advanced.',
                    onTap: () => context.go('/settings'),
                  ),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  _Tile(
                    tokens: tokens,
                    icon: 'plus',
                    title: 'New page',
                    subtitle: 'Cmd+N — title prompt, then a fresh .md.',
                    onTap: () => _promptNewPage(context),
                  ),
                  const SizedBox(width: 16),
                  _Tile(
                    tokens: tokens,
                    icon: 'calendar',
                    title: "Today's note",
                    subtitle: 'Open or create Daily/<YYYY-MM-DD>.md.',
                    onTap: () => _openDailyNote(context),
                  ),
                  const SizedBox(width: 16),
                  _Tile(
                    tokens: tokens,
                    icon: 'tag',
                    title: 'Tags',
                    subtitle: 'See every label across the vault.',
                    onTap: () => context.go('/tags'),
                  ),
                ]),
                if (state is VaultLoaded) ...[
                  const SizedBox(height: 28),
                  const _StatsStrip(),
                  const SizedBox(height: 16),
                  _Pinboard(favorites: state.workspace.favorites),
                  const _UpcomingReminders(),
                  const _RecentlyEdited(),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openDailyNote(BuildContext context) async {
    final vault = context.read<VaultBloc>();
    final state = vault.state;
    if (state is! VaultLoaded) return;
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final r = await DailyNote.openTodaysNote(Directory(state.rootPath));
      if (!r.alreadyExisted) vault.add(const ReindexVault());
      router.go('/editor/${r.ulid}');
    } catch (e) {
      messenger?.showSnackBar(
          SnackBar(content: Text('Daily note failed: $e')));
    }
  }

  Future<void> _promptNewPage(BuildContext context) async {
    final vaultBloc = context.read<VaultBloc>();
    if (vaultBloc.state is! VaultLoaded) return;
    final router = GoRouter.of(context);
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New page'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Title'),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (title == null || title.trim().isEmpty) return;
    vaultBloc.add(CreatePage(
      title: title.trim(),
      onCreated: (ulid) => router.go('/editor/$ulid'),
    ));
  }

}

/// Tile grid of the user's pinned pages (`.quill.yaml` `favorites:`).
/// Each tile shows the page title + relative path; tapping opens the
/// editor. Hidden when no favorites are pinned. Rendered above
/// "Upcoming reminders" and "Recently edited" so the user's chosen
/// pages get the top slot.
/// One-line summary across the home page: page / database / tag / orphan
/// counts. Lightweight — one drift `count(*)` plus one walk of relations.
/// Clicking shows nothing today; users get full breakdowns via
/// "Vault stats" / "Show orphan pages" / etc. in the command palette.
class _StatsStrip extends StatefulWidget {
  const _StatsStrip();
  @override
  State<_StatsStrip> createState() => _StatsStripState();
}

class _StatsStripState extends State<_StatsStrip> {
  late Future<_StripCounts> _counts;

  @override
  void initState() {
    super.initState();
    _counts = _load();
  }

  Future<_StripCounts> _load() async {
    final db = context.read<QuillDatabase>();
    final pages = await db.select(db.pages).get();
    final dbs = await db.select(db.databases).get();
    final relations = await db.select(db.relations).get();
    final tagSet = <String>{};
    final linked = <String>{};
    for (final r in relations) {
      linked.add(r.fromUlid);
      linked.add(r.toUlid);
    }
    final staleCutoff =
        DateTime.now().subtract(const Duration(days: 90)).millisecondsSinceEpoch;
    int orphans = 0;
    int stale = 0;
    for (final p in pages) {
      if (!linked.contains(p.ulid)) orphans++;
      if (p.mtimeMs < staleCutoff) stale++;
      if (p.frontmatterJson.isEmpty) continue;
      try {
        final m = jsonDecode(p.frontmatterJson);
        if (m is Map && m['tags'] is List) {
          for (final t in (m['tags'] as List)) {
            final s = '$t'.trim();
            if (s.isNotEmpty) tagSet.add(s);
          }
        }
      } catch (_) {}
    }
    return _StripCounts(
      pages: pages.length,
      databases: dbs.length,
      tags: tagSet.length,
      orphans: orphans,
      stale: stale,
    );
  }

  void _searchPalette(BuildContext context, String query) {
    final cubit = context.read<CommandPaletteCubit>();
    cubit.open();
    cubit.setQuery(query);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    return FutureBuilder<_StripCounts>(
      future: _counts,
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox(height: 18);
        final c = snap.data!;
        // (label, count, color?, palette-query)
        final pieces = <(String, int, Color?, String)>[
          ('pages', c.pages, null, 'vault stats'),
          ('databases', c.databases, null, 'browse all databases'),
          ('tags', c.tags, null, 'browse tags'),
          ('orphans', c.orphans,
              c.orphans == 0 ? null : const Color(0xFFCB5A4F),
              'show orphan'),
          ('stale', c.stale, null, 'show stale'),
        ];
        return Row(
          children: [
            for (var i = 0; i < pieces.length; i++) ...[
              if (i > 0)
                Text('  ·  ',
                    style: mono(fontSize: 12, color: tokens.text3)),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => _searchPalette(context, pieces[i].$4),
                  child: Text(
                    '${pieces[i].$2} ${pieces[i].$1}',
                    style: mono(
                        fontSize: 12,
                        color: pieces[i].$3 ?? tokens.text2),
                  ),
                ),
              ),
            ],
            const Spacer(),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => setState(() => _counts = _load()),
                child: Tooltip(
                  message: 'Refresh stats',
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(Icons.refresh,
                        size: 13, color: tokens.text3),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StripCounts {
  const _StripCounts({
    required this.pages,
    required this.databases,
    required this.tags,
    required this.orphans,
    required this.stale,
  });
  final int pages;
  final int databases;
  final int tags;
  final int orphans;
  final int stale;
}

class _Pinboard extends StatefulWidget {
  const _Pinboard({required this.favorites});
  final List<String> favorites;

  @override
  State<_Pinboard> createState() => _PinboardState();
}

class _PinboardState extends State<_Pinboard> {
  late Future<List<_PinEntry>> _entries;

  @override
  void initState() {
    super.initState();
    _entries = _load();
  }

  @override
  void didUpdateWidget(_Pinboard old) {
    super.didUpdateWidget(old);
    if (!_sameList(old.favorites, widget.favorites)) {
      _entries = _load();
    }
  }

  static bool _sameList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<List<_PinEntry>> _load() async {
    if (widget.favorites.isEmpty) return const [];
    final db = context.read<QuillDatabase>();
    final ulidSet = widget.favorites.toSet();
    final rows = await (db.select(db.pages)
          ..where((p) => p.ulid.isIn(ulidSet.toList())))
        .get();
    final byUlid = {for (final r in rows) r.ulid: r};
    return [
      for (final u in widget.favorites)
        if (byUlid[u] != null)
          _PinEntry(
            ulid: u,
            title: byUlid[u]!.title,
            relativePath: byUlid[u]!.relativePath,
            emojiIcon:
                emojiFromFrontmatterJson(byUlid[u]!.frontmatterJson),
          ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    return FutureBuilder<List<_PinEntry>>(
      future: _entries,
      builder: (context, snap) {
        final list = snap.data ?? const [];
        if (list.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PINBOARD',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                  color: tokens.text3,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final e in list)
                    GestureDetector(
                      onTap: () => context.go('/editor/${e.ulid}'),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Container(
                          width: 220,
                          padding:
                              const EdgeInsets.fromLTRB(12, 10, 12, 10),
                          decoration: BoxDecoration(
                            color: tokens.surface,
                            border: Border.all(
                                color: tokens.divider2, width: 0.5),
                            borderRadius:
                                const BorderRadius.all(Radius.circular(6)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  if (e.emojiIcon != null)
                                    SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: Center(
                                        child: Text(
                                          e.emojiIcon!,
                                          style: const TextStyle(
                                              fontSize: 11, height: 1),
                                        ),
                                      ),
                                    )
                                  else
                                    QuillIcon('star',
                                        size: 12,
                                        strokeWidth: 1.7,
                                        color: tokens.accent),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      e.title,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                        color: tokens.text,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                e.relativePath,
                                style: mono(
                                    fontSize: 11, color: tokens.text3),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PinEntry {
  const _PinEntry({
    required this.ulid,
    required this.title,
    required this.relativePath,
    this.emojiIcon,
  });
  final String ulid;
  final String title;
  final String relativePath;
  final String? emojiIcon;
}

/// Shows pages whose frontmatter `reminder:` date is within the next 7
/// days (or already overdue). Surfaces the M89 reminder badges on the
/// home page so the user spots upcoming work without opening each
/// page. Hidden when there's nothing to surface.
class _UpcomingReminders extends StatefulWidget {
  const _UpcomingReminders();
  @override
  State<_UpcomingReminders> createState() => _UpcomingRemindersState();
}

class _UpcomingRemindersState extends State<_UpcomingReminders> {
  late Future<List<_ReminderEntry>> _entries;

  @override
  void initState() {
    super.initState();
    _entries = _load();
  }

  Future<List<_ReminderEntry>> _load() async {
    final db = context.read<QuillDatabase>();
    final rows = await db.select(db.pages).get();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final horizon = today.add(const Duration(days: 7));
    final out = <_ReminderEntry>[];
    for (final r in rows) {
      // Hand-parse `reminder:` from the frontmatter_json blob.
      final m = RegExp(r'"reminder"\s*:\s*"([^"]+)"')
          .firstMatch(r.frontmatterJson);
      if (m == null) continue;
      final raw = m.group(1)?.trim() ?? '';
      final due = DateTime.tryParse(raw);
      if (due == null) continue;
      final dueDay = DateTime(due.year, due.month, due.day);
      if (dueDay.isAfter(horizon)) continue;
      out.add(_ReminderEntry(
        ulid: r.ulid,
        title: r.title,
        relativePath: r.relativePath,
        due: dueDay,
      ));
    }
    out.sort((a, b) => a.due.compareTo(b.due));
    return out.take(8).toList();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    return FutureBuilder<List<_ReminderEntry>>(
      future: _entries,
      builder: (context, snap) {
        final list = snap.data ?? const [];
        if (list.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'UPCOMING REMINDERS',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                  color: tokens.text3,
                ),
              ),
              const SizedBox(height: 8),
              for (final e in list) _row(e, tokens),
            ],
          ),
        );
      },
    );
  }

  Widget _row(_ReminderEntry e, QuillTokens tokens) {
    final today = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);
    final days = e.due.difference(todayDay).inDays;
    final overdue = days < 0;
    final isToday = days == 0;
    final label = isToday
        ? 'today'
        : days == 1
            ? 'tomorrow'
            : days > 0
                ? 'in ${days}d'
                : '${-days}d overdue';
    final fg = overdue
        ? const Color(0xFFCB5A4F)
        : isToday
            ? tokens.accent
            : tokens.text2;
    return GestureDetector(
      onTap: () => context.go('/editor/${e.ulid}'),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: tokens.divider, width: 0.5),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.notifications_active_outlined,
                  size: 12, color: fg),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  e.title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: tokens.text,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              Text(label, style: mono(fontSize: 11, color: fg)),
              const SizedBox(width: 12),
              Text(
                e.relativePath,
                style: mono(fontSize: 11, color: tokens.text3),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReminderEntry {
  const _ReminderEntry({
    required this.ulid,
    required this.title,
    required this.relativePath,
    required this.due,
  });
  final String ulid;
  final String title;
  final String relativePath;
  final DateTime due;
}

class _RecentlyEdited extends StatefulWidget {
  const _RecentlyEdited();

  @override
  State<_RecentlyEdited> createState() => _RecentlyEditedState();
}

class _RecentlyEditedState extends State<_RecentlyEdited> {
  late Future<List<_RecentEntry>> _entries;

  @override
  void initState() {
    super.initState();
    _entries = _load();
  }

  Future<List<_RecentEntry>> _load() async {
    final db = context.read<QuillDatabase>();
    final rows = await (db.select(db.pages)
          ..orderBy([(p) =>
              OrderingTerm(expression: p.mtimeMs, mode: OrderingMode.desc)])
          ..limit(5))
        .get();
    return [
      for (final r in rows)
        _RecentEntry(
          ulid: r.ulid,
          title: r.title,
          relativePath: r.relativePath,
          mtime: r.mtimeMs,
          emojiIcon: emojiFromFrontmatterJson(r.frontmatterJson),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    return FutureBuilder<List<_RecentEntry>>(
      future: _entries,
      builder: (context, snap) {
        final list = snap.data ?? const [];
        if (list.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'RECENTLY EDITED',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
                color: tokens.text3,
              ),
            ),
            const SizedBox(height: 8),
            for (final e in list)
              GestureDetector(
                onTap: () => context.go('/editor/${e.ulid}'),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: tokens.divider, width: 0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        if (e.emojiIcon != null)
                          SizedBox(
                            width: 13,
                            height: 13,
                            child: Center(
                              child: Text(
                                e.emojiIcon!,
                                style: const TextStyle(
                                    fontSize: 12, height: 1),
                              ),
                            ),
                          )
                        else
                          QuillIcon('file-md',
                              size: 13,
                              strokeWidth: 1.7,
                              color: tokens.text3),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            e.title,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                              color: tokens.text,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: Text(
                            e.relativePath,
                            textAlign: TextAlign.right,
                            style: mono(fontSize: 11, color: tokens.text3),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _ago(e.mtime),
                          style: mono(fontSize: 11, color: tokens.text3),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  static String _ago(int mtimeMs) {
    final secs =
        ((DateTime.now().millisecondsSinceEpoch - mtimeMs) ~/ 1000)
            .clamp(0, 1 << 30);
    if (secs < 60) return 'just now';
    if (secs < 3600) return '${secs ~/ 60}m';
    if (secs < 86400) return '${secs ~/ 3600}h';
    return '${secs ~/ 86400}d';
  }
}

class _RecentEntry {
  const _RecentEntry({
    required this.ulid,
    required this.title,
    required this.relativePath,
    required this.mtime,
    this.emojiIcon,
  });
  final String ulid;
  final String title;
  final String relativePath;
  final int mtime;
  final String? emojiIcon;
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.tokens,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });
  final QuillTokens tokens;
  final String icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: MouseRegion(
        cursor: onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: tokens.surface,
              border: Border.all(color: tokens.divider2, width: 0.5),
              borderRadius: const BorderRadius.all(Radius.circular(6)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                QuillIcon(icon, size: 16, color: tokens.text2),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: tokens.text),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: mono(fontSize: 11, color: tokens.text3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
