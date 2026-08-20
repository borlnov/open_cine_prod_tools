<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# 0023 - Foreign screenplay import, one way only

## Status

Accepted

## Context

Until this decision the only screenplay that could enter the app was a `.fountain` file. That is
not what a production is sent: what arrives is a Final Draft `.fdx` — the format the trade writes
in — and, for an older or writing-side project, a legacy Celtx `.celtx`. Nobody converts their
screenplay before opening a tool, so the entry door that existed was the one nobody arrives
through.

Two questions had to be answered together, because the second constrains where the first can live:

- **Where does the reading code go?** ADR 0002 put the Fountain parser, serializer and layout
  metrics in `packages/fountain_kit`, a pure Dart package with a round-trip guarantee. Reading
  `.fdx` needs an XML parser, reading `.celtx` needs a zip decoder and an HTML parser, and both
  need `fountain_kit`'s own writers to produce text a Fountain parser reads back the way the
  reader meant.
- **Does the app write those formats too?** An import gesture invites the symmetrical export, and
  a production asked to send its screenplay back to the writer is a real case.

The formats themselves are not symmetrical with Fountain. An `.fdx` carries revision marks, locked
pages, margin notes and a paginated layout; a `.celtx` carries a whole project — a catalogue, a
storyboard, a schedule — around its script. Fountain carries none of that, and the app's source of
truth is Fountain text plus a scene index (ADR 0001, ADR 0012).

## Decision

A **sibling package**, `packages/script_import_kit`, pure Dart, in `fountain_kit`'s own position:
its own `pubspec.yaml`, `analysis_options.yaml`, `README.md`, `CHANGELOG.md` and test suite, taken
by the app as `script_import_kit: path: packages/script_import_kit`. It depends on `fountain_kit`,
on `xml`, `html` and `archive`; **`fountain_kit` never references it**, a dependency not knowing
its dependents.

Its public API is one door — `ScriptImporter.read({bytes, fileName})` — returning a
`ScriptImportResult` (the format that was read, and the screenplay as Fountain text), or throwing a
`ScriptImportException` carrying a `ScriptImportFailure`. Inside, `FdxScriptReader` and
`CeltxScriptReader` produce the same intermediate — a list of typed `ScriptLine`s, saying *this is
a scene heading*, *this is a character cue*, and nothing about Fountain syntax — which one
`ScriptFountainEmitter` renders through `fountain_kit`'s `FountainLineWriter`,
`FountainInlineSerializer` and `FountainTitlePageWriter`.

**The conversion is one way.** The app reads `.fdx` and `.celtx` and writes neither. The screenplay
exports stay `.fountain` and PDF.

## Consequences

`fountain_kit` stays what ADR 0002 made it: a package that knows the Fountain format and no
proprietary one, testable and reusable on that basis. A third format — a `.fadein`, a Trelby
file — is a third reader behind the same emitter and touches no Fountain syntax rule at all, which
is the property the intermediate exists for. The cost is a third package to set up and check
everywhere the app is built or verified, exactly the cost ADR 0002 already accepted once.

**A conversion loses things, and the readers say which.** Margin notes, revision marks, locked
pages and every text style Fountain has no marker for are dropped from an `.fdx`; every Celtx
document but the first script — the catalogue, the storyboard, the notes, the media — is dropped
from a `.celtx`. Each reader's own documentation lists its losses, and a file that cannot be read
at all raises rather than returning the half of it that parsed: a conversion silently dropping what
it did not understand is worse than no conversion, since nothing downstream can tell.

Not exporting these formats is what keeps that honest. Writing an `.fdx` would mean maintaining a
Final Draft pagination this project cannot check — there is no Final Draft here to open the result
in, and a file that opens *slightly* wrong in the tool the writer actually uses is worse than no
file. It also means a production that imports a screenplay, marks it up here and needs to send it
back to the writer sends a `.fountain` or a PDF; that is a known limitation, and the day it has to
change, the round trip is what will have to be argued, not the reading.

The **round-trip test is the load-bearing one**: the emitted text is re-parsed by
`FountainParser.parse` and the blocks are compared to what the reader meant. It is what proves the
forcing markers did their job — an all-caps line of dialogue staying dialogue instead of becoming a
character cue, an action paragraph opening on `INT.` staying action. A reader added without that
test is a reader whose output nobody has checked.

## Alternatives considered

- **A subdirectory of `fountain_kit`**: would put a Final Draft XML schema, a zip decoder and an
  HTML parser inside the package ADR 0002 kept ignorant of every format but Fountain, and would
  hand three dependencies to every consumer of the parser.
- **Reading the formats straight in `lib/`**: would pull Flutter into every test of a conversion
  and put format semantics back in the UI layer, which is the boundary ADR 0002 drew.
- **A published `.fdx` package**: none evaluated produced Fountain, let alone through this app's
  own writers, which is what the round-trip guarantee rests on.
- **Exporting `.fdx` as well**: a Final Draft pagination nobody here can verify, for a round trip
  a `.fountain` or a PDF already serves.
- **Converting on a best-effort basis and never failing**: a screenplay missing the third of its
  scenes the reader did not understand, with nothing downstream able to notice.
- **Reading every Celtx script document** rather than the first: the container holds a project,
  and mapping its documents onto this app's episodes is a question ADR 0019 answers for projects
  created here, not one an import should decide silently.
