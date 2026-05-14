import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/ulid/ulid_generator.dart';

/// A handful of useful built-in templates Quill ships out of the box.
/// Authored as raw markdown so the byte-identical round-trip survives
/// after the user edits them. The `id:` placeholder gets replaced with
/// a fresh ULID on install — each template lands as a normal vault
/// page that can be duplicated via the existing "New page from template…"
/// flow.
class SeedTemplates {
  const SeedTemplates({this.ulids = const UlidGenerator()});
  final UlidGenerator ulids;

  /// Built-in templates as (filename, raw markdown without id) tuples.
  static const _templates = <(String, String)>[
    (
      'Meeting notes.md',
      '''---
id: __ULID__
title: Meeting notes
icon: 💬
type: meeting
attendees: []
date: __DATE__
---

# Meeting notes

> [!NOTE]
> Replace this template with the actual agenda before the meeting.

## Agenda

- Topic 1
- Topic 2
- Topic 3

## Discussion

(notes)

## Decisions

- [ ] Decision 1
- [ ] Decision 2

## Action items

- [ ] Owner — Action
- [ ] Owner — Action
''',
    ),
    (
      'Weekly review.md',
      '''---
id: __ULID__
title: Weekly review
icon: 📅
type: review
week_of: __DATE__
---

# Weekly review

## Wins

-

## Lessons

-

## Next week

- [ ]
- [ ]
- [ ]

## Metrics

| Metric | Value |
| --- | --- |
|  |  |
|  |  |
''',
    ),
    (
      'Decision log.md',
      '''---
id: __ULID__
title: Decision log
icon: 🗂️
type: decision
status: proposed
owner:
date: __DATE__
---

# Decision: <short title>

**Context**

What's the situation? What constraints apply?

**Options**

1. Option A — pros / cons
2. Option B — pros / cons
3. Option C — pros / cons

**Decision**

Chose option X because …

**Consequences**

-
-

## Follow-ups

- [ ]
- [ ]
''',
    ),
    (
      'Project plan.md',
      '''---
id: __ULID__
title: Project plan
icon: 🗺️
type: project
status: planning
owner:
start: __DATE__
target:
---

# Project: <name>

## Why

One sentence on why this matters now.

## Scope

In:
-

Out:
-

## Milestones

- [ ] M1 —
- [ ] M2 —
- [ ] M3 —

## Risks

| Risk | Likelihood | Mitigation |
| --- | --- | --- |
|  |  |  |
''',
    ),
    (
      'Reading notes.md',
      '''---
id: __ULID__
title: Reading notes
icon: 📚
type: reading
source:
author:
date: __DATE__
---

# Reading notes — <title>

## Highlights

>

## My take

-

## Open questions

-

## Related

- [[]]
''',
    ),
  ];

  /// Install every built-in template into `<vaultRoot>/Templates/`.
  /// Skips files that already exist so re-running is safe. Returns the
  /// number of files actually written.
  Future<int> install(Directory vaultRoot) async {
    final dir = Directory(p.join(vaultRoot.path, 'Templates'));
    await dir.create(recursive: true);
    final today = DateTime.now();
    final iso =
        '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    var written = 0;
    for (final (filename, raw) in _templates) {
      final file = File(p.join(dir.path, filename));
      if (await file.exists()) continue;
      final ulid = ulids.generate();
      final body =
          raw.replaceAll('__ULID__', ulid).replaceAll('__DATE__', iso);
      await file.writeAsString(body);
      written++;
    }
    return written;
  }
}
