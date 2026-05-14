---
id: 01HX0V9R5N6E8L3P7Q8S9U2X4B
title: Northwind
stage: expanding
arr: 420000
owner: Diego
health: green
tags: [logistics, enterprise, expansion]
updated: 2026-05-13
---

# Northwind

Logistics company, 96 paid seats, expanding into routing v2. Primary
contact: Maya Reyes (VP Eng). Renewal locked through Q4; expansion
conversation tied to the migration milestone.

## Status

- Migration to v2 routing — kickoff May 06, target GA Jun 30
- Open ticket on rate-limit thresholds — [CASE-4421]
- Quarterly review attended by Maya, Jon (CIO), and our team

## Related

See [[01HX0VEY5T6K7R9X4Y8Z0A3D4G]] and the [[01HX0VH3AW0N0V5C8C4F6H8K9L]].

## Notes

Maya raised concerns about webhook delivery during the May 08 review.
We agreed to a follow-up by end of month with hard SLA numbers.

```bash
$ ops report --account northwind --since 2026-05-01
7 incidents · 99.94% uptime · p95 142ms
```
