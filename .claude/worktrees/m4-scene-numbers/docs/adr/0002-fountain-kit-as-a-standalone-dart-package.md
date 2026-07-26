<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# 0002 - fountain_kit as a standalone Dart package

## Status

Accepted

## Context

The Fountain format (parsing, serializing, and computing the layout metrics needed to paginate a
screenplay) is domain logic that several parts of the app need: the raw-mode editor, the styled
WYSIWYG editor, the side-by-side preview, PDF export, and the scene index. None of that logic
depends on Flutter or on any Open Cine Prod Tools UI concept.

## Decision

The parser, serializer and layout metrics live in `packages/fountain_kit`, a pure Dart package
(`sdk: ^3.11.1`) with no Flutter dependency, its own `pubspec.yaml`/`pubspec.lock`, its own
`analysis_options.yaml` (based on `package:lints/recommended.yaml`), and its own `README.md` and
`CHANGELOG.md`. It carries a round-trip guarantee: parsing a Fountain document and serializing it
back returns the original text. The app depends on it as a path dependency
(`fountain_kit: path: packages/fountain_kit`) and every layer that touches Fountain semantics -
`OcptWysiwygCodec`, the raw-mode preview, the PDF exporter, `OcptSceneIndexService` - is built on
its public API (`FountainLineClassifier`, `FountainLineWriter`, `FountainInlineParser`,
`FountainInlineSerializer`, `FountainLayoutMetrics`, and the document/scene-heading models).

## Consequences

The package is testable on the plain Dart VM (no widget bindings, no device), which makes its
test suite fast and keeps its round-trip guarantee cheap to verify. It is reusable outside this
app if the parser is ever needed elsewhere, and the package boundary keeps screenplay semantics
out of the UI layer. The cost is a second package to set up and check everywhere the app is
built or verified: its own `pub get`, its own analyze/test pass, its own lint rules to keep in
sync in spirit with the app's, and its own versioning inside the monorepo.

## Alternatives considered

- Keep the parser under `lib/`: simpler short-term, but it would pull Flutter into every test of
  parsing logic and blur the boundary between screenplay semantics and UI code.
- Depend on an existing published Fountain package: none evaluated offered the exact
  layout-metrics and round-trip guarantees this app's editor and PDF export rely on.
