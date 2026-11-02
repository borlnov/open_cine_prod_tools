// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_preview_layout.dart';

/// Render one printable screenplay block on the preview's simulated paper page, at its true
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

  /// The text scaler every run of the page is laid out with: none.
  ///
  /// This is a simulation of printed paper, whose type size is the page's own (12-point Courier
  /// rendered at [OcptEditorPreviewLayout.fontSize]), not a UI type size. Letting the platform's
  /// font-scaling preference through would grow the glyphs without growing the page, and the
  /// content would then overflow its simulated sheet exactly the way an inherited `letterSpacing`
  /// does (see [_baseStyle]). The panel scales the whole page down instead when it is too narrow
  /// for it, which keeps the paper readable without ever putting text outside it.
  static const TextScaler _textScaler = TextScaler.noScaling;

  /// The block to render.
  final FountainBlock block;

  /// The pixel layout the block is typeset with.
  final OcptEditorPreviewLayout layout;

  /// Get the base text style every preview run derives from: Courier Prime, black on the white
  /// page,
  /// rendered at exactly [layout]'s [OcptEditorPreviewLayout.lineHeight] (not a fixed factor: see
  /// that getter's own doc comment for why estimate and render must always agree).
  ///
  /// `inherit: false` is load-bearing, not tidiness: an inheriting style is merged onto the
  /// ambient [DefaultTextStyle] (Material's `bodyMedium`) by [Text.rich], and that style's
  /// `letterSpacing` then widens every glyph past the fixed pitch [OcptEditorPreviewLayout]
  /// measured the page's columns with. A full-width line stopped fitting its own box two or three
  /// columns early, so it wrapped onto an extra line that [OcptEditorPreviewLayout
  /// .estimatedLineCount] — which counts columns, not pixels — never counted: with page simulation
  /// on, the surplus lines of every page piled up past the bottom edge of its simulated sheet and
  /// were painted on the panel's backdrop, between two sheets. Every field the page's typography
  /// needs is therefore given explicitly here, including the [TextLeadingDistribution] the app's
  /// typography would otherwise have supplied.
  TextStyle get _baseStyle => TextStyle(
    inherit: false,
    fontFamily: OcptEditorPreviewLayout.fontFamily,
    fontSize: OcptEditorPreviewLayout.fontSize,
    height: layout.lineHeightFactor,
    leadingDistribution: TextLeadingDistribution.even,
    color: Colors.black,
  );

  /// Get the horizontal text alignment of [block]'s element.
  TextAlign get _textAlign => switch (_elementOf(block)?.alignment) {
    FountainLayoutAlignment.center => TextAlign.center,
    FountainLayoutAlignment.right => TextAlign.right,
    _ => TextAlign.left,
  };

  /// Class constructor
  const OcptEditorPreviewBlock({super.key, required this.block, required this.layout});

  /// Build the editor preview block as a [Padding].
  @override
  Widget build(BuildContext context) {
    final content = switch (block) {
      final FountainSceneHeading heading => _OcptPreviewElement(
        block: this,
        element: layout.metrics.sceneHeading,
        child: _OcptPreviewStyledText(
          block: this,
          text:
              // `FountainSceneHeading.headingText` is already uppercased unconditionally by
              // `FountainBlockBuilder`, regardless of the raw source's casing (unlike the character
              // cue/transition text below, kept verbatim in their models and uppercased here instead).
              heading.sceneNumber == null
              ? heading.headingText
              : "${heading.sceneNumber}. ${heading.headingText}",
          style: _baseTextStyleFor(FountainLineType.sceneHeading, _baseStyle),
        ),
      ),
      final FountainActionBlock action => _OcptPreviewElement(
        block: this,
        element: layout.metrics.action,
        child: _OcptPreviewMultilineText(block: this, lines: action.lines, style: _baseStyle),
      ),
      final FountainDialogueGroup dialogue => _OcptPreviewDialogueGroup(
        block: this,
        dialogue: dialogue,
      ),
      final FountainTransition transition => _OcptPreviewElement(
        block: this,
        element: layout.metrics.transition,
        child: _OcptPreviewStyledText(
          block: this,
          text: _printed(transition.text, FountainLineType.transition),
          style: _baseStyle,
        ),
      ),
      final FountainCenteredText centered => _OcptPreviewElement(
        block: this,
        element: layout.metrics.centeredText,
        child: _OcptPreviewStyledText(block: this, text: centered.text, style: _baseStyle),
      ),
      final FountainLyrics lyrics => _OcptPreviewElement(
        block: this,
        element: layout.metrics.lyrics,
        child: _OcptPreviewMultilineText(
          block: this,
          lines: lyrics.lines,
          style: _baseTextStyleFor(FountainLineType.lyrics, _baseStyle),
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

  /// Get the layout box of [block]'s element, or null for blocks without one (e.g. page breaks).
  FountainElementLayout? _elementOf(FountainBlock block) => switch (block) {
    FountainSceneHeading() => layout.metrics.sceneHeading,
    FountainActionBlock() => layout.metrics.action,
    FountainTransition() => layout.metrics.transition,
    FountainCenteredText() => layout.metrics.centeredText,
    FountainLyrics() => layout.metrics.lyrics,
    _ => null,
  };

  /// Apply [FountainPrintStyle.of]'s print-time letter case to [text] for a line of [lineType],
  /// upper-casing it when that type's print style says so: the single source of truth this
  /// preview shares with the PDF exporter and the styled editor's stylesheet for which elements
  /// print upper-cased, so the three never drift apart on the question.
  static String _printed(String text, FountainLineType lineType) =>
      FountainPrintStyle.of(lineType).isUppercase ? text.toUpperCase() : text;

  /// Apply [FountainPrintStyle.of]'s base weight/slope for [lineType] to [style]: the same
  /// shared table [_printed] reads its casing rule from, so a switch case above never hardcodes
  /// its own bold/italic decision for a type the table already has an opinion on (a scene heading
  /// is always bold, lyrics are always italic, regardless of any inline emphasis their own text
  /// might additionally carry through [_inlineSpans]).
  static TextStyle _baseTextStyleFor(FountainLineType lineType, TextStyle style) {
    final printStyle = FountainPrintStyle.of(lineType);
    return style.copyWith(
      fontWeight: printStyle.isBold ? FontWeight.bold : null,
      fontStyle: printStyle.isItalic ? FontStyle.italic : null,
    );
  }

  /// Resolve [text]'s inline emphasis markers into styled [TextSpan]s deriving from [style].
  ///
  /// Inline notes (`[[...]]`) are editor-only: they are not part of the printed screenplay, so
  /// their spans are skipped.
  static List<TextSpan> _inlineSpans(String text, TextStyle style) => [
    for (final span in _inlineParser.parse(text))
      if (span.style != FountainInlineStyle.note)
        TextSpan(
          text: span.text,
          style: switch (span.style) {
            FountainInlineStyle.italic => style.copyWith(fontStyle: FontStyle.italic),
            FountainInlineStyle.bold => style.copyWith(fontWeight: FontWeight.bold),
            FountainInlineStyle.boldItalic => style.copyWith(
              fontWeight: FontWeight.bold,
              fontStyle: FontStyle.italic,
            ),
            FountainInlineStyle.underline => style.copyWith(decoration: TextDecoration.underline),
            _ => style,
          },
        ),
  ];
}

/// A text positioned within its element's layout box: indented from the page's left edge and
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
class _OcptPreviewElement extends StatelessWidget {
  /// The block whose layout the element is positioned with.
  final OcptEditorPreviewBlock block;

  /// The layout box of the element.
  final FountainElementLayout element;

  /// The text to position.
  final Widget child;

  /// Class constructor
  const _OcptPreviewElement({required this.block, required this.element, required this.child});

  /// Build the preview element as an [Align].
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topLeft,
    child: Padding(
      padding: EdgeInsets.only(left: block.layout.indentOf(element)),
      child: SizedBox(width: block.layout.widthOf(element), child: child),
    ),
  );
}

/// A full dialogue group: the character cue, then its parentheticals and dialogue lines, each at
/// its own element's indent.
class _OcptPreviewDialogueGroup extends StatelessWidget {
  /// The block whose layout the dialogue group is typeset with.
  final OcptEditorPreviewBlock block;

  /// The dialogue group to render.
  final FountainDialogueGroup dialogue;

  /// Class constructor
  const _OcptPreviewDialogueGroup({required this.block, required this.dialogue});

  /// Build the preview dialogue group as a [Column].
  @override
  Widget build(BuildContext context) {
    final layout = block.layout;
    final character = dialogue.character;
    final cueText = character.extension == null
        ? character.name
        : "${character.name} (${character.extension})";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _OcptPreviewElement(
          block: block,
          element: layout.metrics.character,
          child: _OcptPreviewStyledText(
            block: block,
            text: OcptEditorPreviewBlock._printed(cueText, FountainLineType.character),
            style: block._baseStyle,
          ),
        ),
        for (final child in dialogue.children)
          switch (child) {
            final FountainParenthetical parenthetical => _OcptPreviewElement(
              block: block,
              element: layout.metrics.parenthetical,
              child: _OcptPreviewStyledText(
                block: block,
                text: "(${parenthetical.text})",
                style: block._baseStyle,
              ),
            ),
            final FountainDialogueLine line => _OcptPreviewElement(
              block: block,
              element: layout.metrics.dialogue,
              child: _OcptPreviewStyledText(block: block, text: line.text, style: block._baseStyle),
            ),
            // A dialogue group's children are only ever parentheticals and dialogue lines.
            _ => const SizedBox.shrink(),
          },
      ],
    );
  }
}

/// Lines rendered as one text widget, one source line per rendered paragraph.
class _OcptPreviewMultilineText extends StatelessWidget {
  /// The block whose alignment the text follows.
  final OcptEditorPreviewBlock block;

  /// The lines to render.
  final List<String> lines;

  /// The style the lines derive from.
  final TextStyle style;

  /// Class constructor
  const _OcptPreviewMultilineText({required this.block, required this.lines, required this.style});

  /// Build the preview multiline text as a [Text].
  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        for (var i = 0; i < lines.length; i++) ...[
          if (i > 0) const TextSpan(text: "\n"),
          ...OcptEditorPreviewBlock._inlineSpans(lines[i], style),
        ],
      ],
    ),
    style: style,
    textAlign: block._textAlign,
    textScaler: OcptEditorPreviewBlock._textScaler,
  );
}

/// One text, with its inline emphasis resolved.
class _OcptPreviewStyledText extends StatelessWidget {
  /// The block whose alignment the text follows.
  final OcptEditorPreviewBlock block;

  /// The text to render.
  final String text;

  /// The style the text derives from.
  final TextStyle style;

  /// Class constructor
  const _OcptPreviewStyledText({required this.block, required this.text, required this.style});

  /// Build the preview styled text as a [Text].
  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(children: OcptEditorPreviewBlock._inlineSpans(text, style)),
    style: style,
    textAlign: block._textAlign,
    textScaler: OcptEditorPreviewBlock._textScaler,
  );
}
