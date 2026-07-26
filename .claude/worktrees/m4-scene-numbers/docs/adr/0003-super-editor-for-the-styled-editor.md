<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# 0003 - super_editor for the styled editor

## Status

Accepted

## Context

The editor's default mode is a styled, WYSIWYG view of the screenplay: the real page layout,
block-type dropdown, Tab cycling between screenplay element types, smart Enter, and inline
bold/italic/underline - all while the underlying source of truth stays plain Fountain text. This
needs a rich document-editing widget, not a plain text field, and one flexible enough to encode
Fountain semantics without reinventing text editing, selection and IME handling from scratch.

## Decision

The styled mode is built on [`super_editor`](https://pub.dev/packages/super_editor). The document
keeps one `ParagraphNode` per non-blank Fountain source line; a blank source line carries no node
of its own, instead folded into the following node's `ocptBlankLinesBefore` metadata. Each node
also carries `blockType` (the line's `FountainLineType`, read by the stylesheet), `ocptTypeLocked`
(set when the type was picked manually via the dropdown or Tab, sticky until the block's text is
emptied) and `ocptHadForcingMarker` (the source line used an explicit forcing marker, so one is
re-emitted on encode even if auto-detection alone would suffice). `OcptWysiwygCodec`
(`lib/ui/pages/editor/super_editor/`) is the only Fountain <-> document boundary; it is built on
`fountain_kit`'s `FountainLineClassifier`/`FountainLineWriter`/`FountainInlineParser`/
`FountainInlineSerializer`.

`super_editor` is pre-1.0 and pinned to an exact version, `0.3.0-dev.52`. Since Flutter 3.44,
`TextInputConnection` declares an abstract `updateStyle(TextInputStyle)` that the package's IME
decorator, `DocumentImeInputClient`, only overrides from `dev.51` onwards, so the pin cannot go
below that. From `dev.52` the package re-exports `BlinkController`, which the styled editor widget
tests disable, so `super_text_layout` no longer needs a direct dev-dependency of its own.
Its stylesheets only merge `TextStyle` and padding across matching rules - other properties
(`maxWidth`, `textAlign`) silently drop if more than one rule matches a block - so every Fountain
line type gets one mutually exclusive `StyleRule`, with no `BlockSelector.all` baseline rule.

## Consequences

The editor gets selection, IME and text-layout handling for free instead of custom-built, at the
price of tracking a pre-1.0, fast-moving dependency: the exact-version pin has to be revisited by
hand (not by a caret range) every time the app's Flutter SDK version moves, and the stylesheet
constraint (one exclusive rule per line type) has to be kept in mind by anyone adding a new
Fountain element to the styled mode. The `ocptBlankLinesBefore`/`ocptTypeLocked`/
`ocptHadForcingMarker` metadata is app-specific bookkeeping that only `OcptWysiwygCodec` and the
keyboard-actions/pagination code understand - it has to stay in sync with `fountain_kit`'s model
whenever either changes.

## Alternatives considered

- A raw text field with syntax highlighting only: simpler, but it is exactly what the app's raw
  mode already offers, and would not give the "real page layout" WYSIWYG experience the styled
  mode targets.
- A custom editor built on Flutter's `EditableText`: full control over behavior, but it would mean
  reimplementing selection, multi-block layout and IME integration that `super_editor` already
  provides.
