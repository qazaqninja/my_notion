// Multi-line `## H2` document templates dropped at the caret by the
// scaffold-family slash entries (`/lorem`, `/meeting`, `/standup`,
// `/retro`, `/adr`). Extracted from `source_line_ops.dart` in M1000
// because the family is self-contained — pure string constants with
// no dependencies on the transform helpers — and broke the parent
// file's line budget the second time after M983's split.
//
// All values are exported through `source_line_ops.dart` so existing
// callers (the slash dispatch in `source_view.dart`, the test suite)
// don't change a single import line. Caret-landing offsets used by
// the dispatch arms live next to those switch cases, not here.

/// The canonical lorem-ipsum paragraph used by the `/lorem` slash
/// entry. Three sentences, ~30 words each — enough to test
/// layout/spacing without overwhelming a small block. Held as a
/// constant so the slash dispatch stays one line.
const String kLoremIpsumParagraph =
    'Lorem ipsum dolor sit amet, consectetur adipiscing elit. '
    'Sed do eiusmod tempor incididunt ut labore et dolore magna '
    'aliqua. Ut enim ad minim veniam, quis nostrud exercitation '
    'ullamco laboris nisi ut aliquip ex ea commodo consequat.';

/// Four-section meeting-notes scaffold dropped at the caret by the
/// `/meeting` slash entry: Attendees / Agenda / Decisions / Action
/// items, each headed by an h2 and seeded with a single empty list
/// marker so the user can start typing immediately. Action items use
/// the GFM unchecked-todo form so they surface in the "Show pages
/// with open todos" palette entry (M985).
const String kMeetingNotesScaffold =
    '## Attendees\n'
    '- \n'
    '\n'
    '## Agenda\n'
    '- \n'
    '\n'
    '## Decisions\n'
    '- \n'
    '\n'
    '## Action items\n'
    '- [ ] \n';

/// Three-section daily-standup scaffold dropped at the caret by the
/// `/standup` slash entry: Yesterday / Today / Blockers. The
/// canonical agile-standup template, minus seeded list markers so the
/// user can choose bullets or prose per section. Caret lands one line
/// below the first heading.
const String kStandupNotesScaffold =
    '## Yesterday\n'
    '\n'
    '## Today\n'
    '\n'
    '## Blockers\n'
    '\n';

/// Three-section retrospective scaffold dropped at the caret by the
/// `/retro` slash entry: What went well / What didn't / Action items.
/// The classic agile-retrospective template, with action items
/// pre-seeded as GFM unchecked-todos so the M985 "open todos"
/// palette surfaces them when the retro page is committed.
const String kRetroNotesScaffold =
    '## What went well\n'
    '- \n'
    '\n'
    "## What didn't\n"
    '- \n'
    '\n'
    '## Action items\n'
    '- [ ] \n';

/// Three-section ADR (Architecture Decision Record) scaffold dropped
/// at the caret by the `/adr` slash entry: Context / Decision /
/// Consequences. The Michael Nygard form, minus the Status section
/// (Quill users typically track status via a frontmatter field or a
/// database select column, not inline prose).
const String kAdrNotesScaffold =
    '## Context\n'
    '\n'
    '## Decision\n'
    '\n'
    '## Consequences\n'
    '\n';
