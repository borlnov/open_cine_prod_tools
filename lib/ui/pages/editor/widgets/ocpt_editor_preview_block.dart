// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_preview_layout.dart';

/// Renders one printable screenplay block on the preview's simulated paper page, at its true
/// screenplay position: indented from the page's left edge, capped at its element's width, and
/// aligned per its element's convention (left for most, centered for centered text, right for
/// transitions).
///
/// The preview simulates paper, so the text is always black regardless of the app theme. Inline
/// emphasis (`*italic*`, `**bold**`, `_underline_`...) is resolved through the
/// [FountainInlineParser]; inline notes are editor-only and are skipped.
class OcptEditorPreviewBlock extends StatelessWidget {
  /// The inline parser used to resolve emphasis markers into styled spans.
  static const _inlineParser = FountainInlineParser();

  /// The block to render.
  final FountainBlock block;

  /// The pixel layout the block is typeset with.
  final OcptEditorPreviewLayout layout;

  /// Class constructor
  const OcptEditorPreviewBlock({
    super.key,
    required this.block,
    required this.layout,
  });

  /// The base text style every preview run derives from: Courier Prime, black on the white page,
  /// rendered at exactly [layout]'s [OcptEditorPreviewLayout.lineHeight] (not a fixed factor: see
  /// that getter's own doc comment for why estimate and render must always agree).
  TextStyle get _baseStyle => TextStyle(
    fontFamily: OcptEditorPreviewLayout.fontFamily,
    fontSize: OcptEditorPreviewLayout.fontSize,
    height: layout.lineHeightFactor,
    color: Colors.black,
  );

  @override
  Widget build(BuildContext context) {
    final content = switch (block) {
      final FountainSceneHeading heading => _element(
        layout.metrics.sceneHeading,
        _styledText(
          // `FountainSceneHeading.headingText` is already uppercased unconditionally by
          // `FountainBlockBuilder`, regardless of the raw source's casing (unlike the character
          // cue/transition text below, kept verbatim in their models and uppercased here instead).
          heading.sceneNumber == null
              ? heading.headingText
              : "${heading.sceneNumber}. ${heading.headingText}",
          _baseStyle.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      final FountainActionBlock action => _element(
        layout.metrics.action,
        _multilineText(action.lines, _baseStyle),
      ),
      final FountainDialogueGroup dialogue => _dialogueGroup(dialogue),
      final FountainTransition transition => _element(
        layout.metrics.transition,
        _styledText(_printed(transition.text, FountainLineType.transition), _baseStyle),
      ),
      final FountainCenteredText centered => _element(
        layout.metrics.centeredText,
        _styledText(centered.text, _baseStyle),
      ),
      final FountainLyrics lyrics => _element(
        layout.metrics.lyrics,
        _multilineText(
          lyrics.lines,
          _baseStyle.copyWith(fontStyle: FontStyle.italic),
        ),
      ),
      FountainPageBreak() => Padding(
        padding: EdgeInsets.symmetric(
          horizontal: layout.indentOf(layout.metrics.action),
          vertical: layout.lineHeight / 2,
        ),
        child: const Divider(color: Colors.black26, height: 1),
      ),
      // Never printed (the preview filters them out) or never top-level (character cues,
      // parentheticals and dialogue lines only live inside a dialogue group).
      _ => const SizedBox.shrink(),
    };

    return Padding(
      padding: EdgeInsets.only(bottom: layout.blockSpacing),
      child: content,
    );
  }

  /// Positions [text] within [element]'s layout box: indented from the page's left edge and
  /// capped at the element's width.
  ///
  /// The outer [Align] is load-bearing, not decorative: each block sits in the preview's
  /// `ListView.builder`, which gives every item a *tight* cross-axis (width) constraint equal to
  /// the page's own width. A bare `SizedBox(width: ...)` cannot narrow a tight constraint — it
  /// gets silently clamped back up to the incoming width, so the element's `SizedBox` below would
  /// always render as wide as the whole page, swallowing the box's right margin entirely (left
  /// margin and top margin stay visible because they come from padding/indent, not from a width
  /// cap). `Align` loosens the constraint it hands to its child before positioning it, letting the
  /// `SizedBox` genuinely shrink to [FountainElementLayout.maxWidthColumns].
  Widget _element(FountainElementLayout element, Widget text) => Align(
    alignment: Alignment.topLeft,
    child: Padding(
      padding: EdgeInsets.only(left: layout.indentOf(element)),
      child: SizedBox(width: layout.widthOf(element), child: text),
    ),
  );

  /// Renders a full dialogue group: the character cue, then its parentheticals and dialogue
  /// lines, each at its own element's indent.
  Widget _dialogueGroup(FountainDialogueGroup dialogue) {
    final character = dialogue.character;
    final cueText = character.extension == null
        ? character.name
        : "${character.name} (${character.extension})";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _element(
          layout.metrics.character,
          _styledText(_printed(cueText, FountainLineType.character), _baseStyle),
        ),
        for (final child in dialogue.children)
          switch (child) {
            final FountainParenthetical parenthetical => _element(
              layout.metrics.parenthetical,
              _styledText("(${parenthetical.text})", _baseStyle),
            ),
            final FountainDialogueLine line => _element(
              layout.metrics.dialogue,
              _styledText(line.text, _baseStyle),
            ),
            // A dialogue group's children are only ever parentheticals and dialogue lines.
            _ => const SizedBox.shrink(),
          },
      ],
    );
  }

  /// Renders [lines] as one text widget, one source line per rendered paragraph.
  Widget _multilineText(List<String> lines, TextStyle style) => Text.rich(
    TextSpan(
      children: [
        for (var i = 0; i < lines.length; i++) ...[
          if (i > 0) const TextSpan(text: "\n"),
          ..._inlineSpans(lines[i], style),
        ],
      ],
    ),
    style: style,
    textAlign: _textAlign,
  );

  /// Renders [text] as one text widget, resolving its inline emphasis.
  Widget _styledText(String text, TextStyle style) => Text.rich(
    TextSpan(children: _inlineSpans(text, style)),
    style: style,
    textAlign: _textAlign,
  );

  /// The horizontal text alignment of [block]'s element.
  TextAlign get _textAlign => switch (_elementOf(block)?.alignment) {
    FountainLayoutAlignment.center => TextAlign.center,
    FountainLayoutAlignment.right => TextAlign.right,
    _ => TextAlign.left,
  };

  /// The layout box of [block]'s element, or null for blocks without one (e.g. page breaks).
  FountainElementLayout? _elementOf(FountainBlock block) => switch (block) {
    FountainSceneHeading() => layout.metrics.sceneHeading,
    FountainActionBlock() => layout.metrics.action,
    FountainTransition() => layout.metrics.transition,
    FountainCenteredText() => layout.metrics.centeredText,
    FountainLyrics() => layout.metrics.lyrics,
    _ => null,
  };

  /// Applies [FountainPrintStyle.of]'s print-time letter case to [text] for a line of [lineType],
  /// upper-casing it when that type's print style says so: the single source of truth this
  /// preview shares with the PDF exporter for which elements print upper-cased, so the two never
  /// drift apart on the question.
  static String _printed(String text, FountainLineType lineType) =>
      FountainPrintStyle.of(lineType).isUppercase ? text.toUpperCase() : text;

  /// Resolves [text]'s inline emphasis markers into styled [TextSpan]s deriving from [style].
  ///
  /// Inline notes (`[[...]]`) are editor-only: they are not part of the printed screenplay, so
  /// their spans are skipped.
  static List<TextSpan> _inlineSpans(String text, TextStyle style) => [
    for (final span in _inlineParser.parse(text))
      if (span.style != FountainInlineStyle.note)
        TextSpan(
          text: span.text,
          style: switch (span.style) {
            FountainInlineStyle.italic => style.copyWith(
              fontStyle: FontStyle.italic,
            ),
            FountainInlineStyle.bold => style.copyWith(
              fontWeight: FontWeight.bold,
            ),
            FountainInlineStyle.boldItalic => style.copyWith(
              fontWeight: FontWeight.bold,
              fontStyle: FontStyle.italic,
            ),
            FountainInlineStyle.underline => style.copyWith(
              decoration: TextDecoration.underline,
            ),
            _ => style,
          },
        ),
  ];
}
