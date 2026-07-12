<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <benoit.rolandeau@allcircuits.com>

SPDX-License-Identifier: Apache-2.0
-->

# Changelog

## 0.1.0

- Initial release: a pure Dart parser, serializer and layout-metrics engine
  for the Fountain screenplay format.
- Parses title pages, scene headings (with forcing and scene numbers),
  action, character cues (with extensions and dual dialogue), dialogue,
  parentheticals, transitions, centered text, lyrics, sections, synopses,
  notes, boneyard comments and page breaks.
- Parses inline emphasis (italic, bold, bold italic, underline) and inline
  notes, with `\`-escaping.
- Serializes a parsed document back to canonical Fountain text, with a
  guaranteed parse-write-parse round trip.
- Provides US Letter and A4 layout metrics (page margins, per-element
  indents and widths, lines per page) for 12-point Courier.
