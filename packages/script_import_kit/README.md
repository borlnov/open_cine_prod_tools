<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# script_import_kit

A pure Dart reader turning the screenplay files a production is actually
sent into [Fountain](https://fountain.io/syntax) text.

Nobody converts their screenplay before opening a tool: what arrives is a
Final Draft `.fdx`. `script_import_kit` reads one and hands back Fountain
source text, so that the receiving application only ever has one format to
store, edit, print and export.

The conversion is **one way**, and knowingly lossy: this package reads
foreign formats and never writes one. Fountain stays the source of truth;
what a format carries and Fountain does not is dropped on purpose, and each
reader's own documentation says exactly what it drops.

It has no Flutter dependency and no I/O of its own: it takes the file's
bytes in and hands back a `String`, which is what keeps it testable from a
document written inline in a test and usable from any Dart project.

## Format coverage

### Final Draft (`.fdx`)

A `<Paragraph Type="…">` becomes a line of screenplay:

| `Paragraph Type` | Fountain |
| --- | --- |
| `Scene Heading` | scene heading, the `Number` attribute becoming `#N#` |
| `Action`, `General` | action |
| `Character` | character cue (a `(V.O.)` extension stays in the text) |
| `Parenthetical` | parenthetical |
| `Dialogue` | dialogue |
| `Transition` | transition |
| `Shot` | action |
| `New Act`, `End of Act` | centered text (`> ACT ONE <`) |
| `Cast List`, any unknown type | action |

A `<DualDialogue>` group's second character cue takes Fountain's `^`.
`<Text Style="Bold+Italic">` runs become the matching emphasis markup.

The `<TitlePage>` is a page of free-form prose rather than a set of named
fields, so it is read the way a person reads it: the first line is the
title, a "written by" / "scénario de" line is the credit and the line after
it the author, a "based on" / "d'après" line is the source, a line saying
"draft" or "version" names the draft — and whatever is left becomes the
contact block, so not one line of the original is lost.

**Not carried over**: `<ScriptNote>` margin notes (an authoring
side-channel with no printed equivalent), revision marks, locked pages, and
every text style Fountain has no marker for.

## Usage

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:script_import_kit/script_import_kit.dart';

void main() {
  final bytes = File('the-last-kettle.fdx').readAsBytesSync();

  try {
    final result = const ScriptImporter().read(
      bytes: Uint8List.fromList(bytes),
      fileName: 'the-last-kettle.fdx',
    );
    print(result.fountainText);
  } on ScriptImportException catch (exception) {
    print('could not be read as a screenplay: ${exception.failure.name}');
  }
}
```

A file that cannot be read raises a `ScriptImportException` carrying a
`ScriptImportFailure`, rather than returning a half-wrong screenplay: a
conversion that silently drops the half of a file it did not understand is
worse than no conversion at all, since nothing downstream can tell.

## How a reader produces Fountain

A reader never writes one character of Fountain by hand. It produces a list
of typed lines — this is a scene heading, this is a character cue — and one
shared emitter renders them through `fountain_kit`'s own line writer,
inline serializer and title page writer, deciding each line's forcing
marker from its neighbours the way the Fountain classifier reads them.

That is what guarantees that re-parsing the produced text yields the very
types the reader meant: an all-caps line of dialogue stays dialogue rather
than becoming a character cue, and an action paragraph opening on `INT.`
stays action rather than becoming a scene heading.

## License

Licensed under the Apache-2.0 license, like the rest of Open Cine Prod
Tools. See the repository's [LICENSES](../../LICENSES/) directory for the
full license text.
