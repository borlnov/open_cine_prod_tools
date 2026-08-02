<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# fountain_kit

A pure Dart parser, serializer and layout-metrics engine for the
[Fountain](https://fountain.io/syntax) screenplay format.

`fountain_kit` has no Flutter dependency and no I/O of its own: it takes a
`String` in and hands back an immutable, typed document tree. It is the core
domain asset behind Open Cine Prod Tools' screenplay editor, but it does not
depend on the app and can be used standalone in any Dart project.

## Spec coverage

- Title page (`key: value`, multi-line values via indented continuation
  lines).
- Scene headings, including forcing (`.`), scene numbers (`#4A#`), and every
  `INT`/`EXT`/`EST`/`INT./EXT`/`I/E` variant.
- Action, forced with `!`.
- Character cues, forced with `@` (allowing lowercase names), with
  parenthetical extensions (`(V.O.)`) and dual dialogue (`^`).
- Dialogue and parentheticals.
- Transitions, forced with `>`.
- Centered text (`> text <`).
- Lyrics (`~`).
- Sections (`#` through `######`) and synopses (`=`).
- Notes (`[[note]]`), standalone or inline.
- Boneyard block comments (`/* ... */`), possibly spanning several lines.
- Page breaks (`===`).
- Inline emphasis (`*italic*`, `**bold**`, `***bold italic***`,
  `_underline_`), with `\`-escaping and inline notes.

## Usage

```dart
import 'package:fountain_kit/fountain_kit.dart';

void main() {
  const parser = FountainParser();
  final document = parser.parse('''
INT. KITCHEN - DAY

SARAH
(to herself)
Smells like Sunday.
''');

  for (final scene in document.scenes) {
    print(scene.headingText);
  }

  const serializer = FountainSerializer();
  final text = serializer.write(document);

  final metrics = FountainLayoutMetrics.usLetter();
  print('${metrics.linesPerPage} lines per page');
}
```

`FountainParser.parse` runs in clearly separated, side-effect-free passes
(boneyard extraction, note extraction, title page extraction, line
classification, block building), which keeps the door open for a future
incremental re-parse of just a changed region of a document.

## Pagination and source provenance

`FountainScriptComposer.compose` lays a parsed document out into printed
pages, applying the professional US screenplay conventions (blank spacer
lines, a scene heading or a character cue never left last on a page, a split
dialogue group getting its `(MORE)` and its repeated `NAME (CONT'D)` cue).

Every printed line it emits carries a nullable
`FountainScriptLine.sourceRange` pointing back into the document's own source
text, so a caller can map a span of source characters onto the rows it was
printed on — what an annotation drawn beside the text needs, and something
only the code that did the wrapping can know. The anchoring is best effort: a
line whose text cannot be located in the source gets no range rather than a
wrong one, and `FountainScriptLine.isSynthetic` marks the lines the composer
wrote itself.

## License

Licensed under the Apache-2.0 license, like the rest of Open Cine Prod
Tools. See the repository's [LICENSES](../../LICENSES/) directory for the
full license text.
