// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_editor_stylesheet.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_line_attributions.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_codec.dart';
import 'package:super_editor/super_editor.dart';

/// Builds a styled editor document from [source], the same way the live editor decodes one (see
/// `ocpt_styled_page_pagination_test.dart`).
MutableDocument _documentFrom(String source) => OcptWysiwygCodec.decode(source).document;

/// Finds the single node of [document] classified as [type].
DocumentNode _nodeOfType(MutableDocument document, FountainLineType type) => document.firstWhere(
  (node) =>
      OcptFountainLineAttributions.typeOfAttributionValue(node.getMetadataValue("blockType")) == type,
);

/// Resolves the style map [document]'s [node] gets from [stylesheet]: the first rule whose
/// selector matches it, exactly as super_editor's own styling pipeline picks one.
Map<String, dynamic> _styleOf(Stylesheet stylesheet, Document document, DocumentNode node) => stylesheet
    .rules
    .firstWhere((rule) => rule.selector.matches(document, node))
    .styler(document, node);

void main() {
  final metrics = FountainLayoutMetrics.usLetter();
  final colorScheme = ColorScheme.fromSeed(seedColor: Colors.deepPurple);

  // A character cue, a parenthetical and a dialogue line: the three most tightly indented
  // elements, and the ones a phone's screen has the least room for at their real screenplay
  // position.
  final document = _documentFrom("CHARACTER\n(smiling)\nHello there, how are you doing today?");
  final characterNode = _nodeOfType(document, FountainLineType.character);
  final parentheticalNode = _nodeOfType(document, FountainLineType.parenthetical);
  final dialogueNode = _nodeOfType(document, FountainLineType.dialogue);

  group("OcptFountainEditorStylesheet.build isCompact", () {
    test("shrinks the dialogue element's indent and box width", () {
      final desktop = OcptFountainEditorStylesheet.build(
        metrics: metrics,
        colorScheme: colorScheme,
        isPageSimulationEnabled: false,
      );
      final compact = OcptFountainEditorStylesheet.build(
        metrics: metrics,
        colorScheme: colorScheme,
        isPageSimulationEnabled: false,
        isCompact: true,
      );

      final desktopStyle = _styleOf(desktop, document, dialogueNode);
      final compactStyle = _styleOf(compact, document, dialogueNode);

      final desktopPadding = desktopStyle[Styles.padding] as CascadingPadding;
      final compactPadding = compactStyle[Styles.padding] as CascadingPadding;

      expect(compactPadding.left, lessThan(desktopPadding.left!));
      expect(compactStyle[Styles.maxWidth] as double, lessThan(desktopStyle[Styles.maxWidth] as double));
    });

    test("shrinks the character element's indent and box width, keeping its bold accent style", () {
      final desktop = OcptFountainEditorStylesheet.build(
        metrics: metrics,
        colorScheme: colorScheme,
        isPageSimulationEnabled: false,
      );
      final compact = OcptFountainEditorStylesheet.build(
        metrics: metrics,
        colorScheme: colorScheme,
        isPageSimulationEnabled: false,
        isCompact: true,
      );

      final desktopStyle = _styleOf(desktop, document, characterNode);
      final compactStyle = _styleOf(compact, document, characterNode);

      final desktopPadding = desktopStyle[Styles.padding] as CascadingPadding;
      final compactPadding = compactStyle[Styles.padding] as CascadingPadding;

      expect(compactPadding.left, lessThan(desktopPadding.left!));
      expect(compactStyle[Styles.maxWidth] as double, lessThan(desktopStyle[Styles.maxWidth] as double));

      final desktopTextStyle = desktopStyle[Styles.textStyle] as TextStyle;
      final compactTextStyle = compactStyle[Styles.textStyle] as TextStyle;
      expect(compactTextStyle.fontWeight, FontWeight.bold);
      expect(compactTextStyle.fontWeight, desktopTextStyle.fontWeight);
      expect(compactTextStyle.color, desktopTextStyle.color);
    });

    test("keeps the parenthetical's italic, dimmed style unchanged while shrinking its box", () {
      final desktop = OcptFountainEditorStylesheet.build(
        metrics: metrics,
        colorScheme: colorScheme,
        isPageSimulationEnabled: false,
      );
      final compact = OcptFountainEditorStylesheet.build(
        metrics: metrics,
        colorScheme: colorScheme,
        isPageSimulationEnabled: false,
        isCompact: true,
      );

      final desktopStyle = _styleOf(desktop, document, parentheticalNode);
      final compactStyle = _styleOf(compact, document, parentheticalNode);

      final desktopPadding = desktopStyle[Styles.padding] as CascadingPadding;
      final compactPadding = compactStyle[Styles.padding] as CascadingPadding;
      expect(compactPadding.left, lessThan(desktopPadding.left!));

      final desktopTextStyle = desktopStyle[Styles.textStyle] as TextStyle;
      final compactTextStyle = compactStyle[Styles.textStyle] as TextStyle;
      expect(compactTextStyle.fontStyle, FontStyle.italic);
      expect(compactTextStyle.fontStyle, desktopTextStyle.fontStyle);
      expect(compactTextStyle.color, desktopTextStyle.color);
      expect(compactStyle[Styles.opacity], desktopStyle[Styles.opacity]);
    });

    test("leaves desktop output byte-identical when isCompact is off", () {
      final explicitlyDesktop = OcptFountainEditorStylesheet.build(
        metrics: metrics,
        colorScheme: colorScheme,
        isPageSimulationEnabled: false,
        // Explicit rather than omitted, matching the defaulted call below: naming the value this
        // test is proving is a no-op is the point of the assertion, not an oversight.
        // ignore: avoid_redundant_argument_values
        isCompact: false,
      );
      final defaulted = OcptFountainEditorStylesheet.build(
        metrics: metrics,
        colorScheme: colorScheme,
        isPageSimulationEnabled: false,
      );

      for (final node in [characterNode, parentheticalNode, dialogueNode]) {
        final explicitStyle = _styleOf(explicitlyDesktop, document, node);
        final defaultStyle = _styleOf(defaulted, document, node);

        expect(explicitStyle[Styles.padding], defaultStyle[Styles.padding]);
        expect(explicitStyle[Styles.maxWidth], defaultStyle[Styles.maxWidth]);
        expect(
          (explicitStyle[Styles.textStyle] as TextStyle).fontWeight,
          (defaultStyle[Styles.textStyle] as TextStyle).fontWeight,
        );
      }
    });

    test("never applies while page simulation is on, whatever isCompact is", () {
      final paginated = OcptFountainEditorStylesheet.build(
        metrics: metrics,
        colorScheme: colorScheme,
        isPageSimulationEnabled: true,
        // Explicit rather than omitted, matching the compact-requested call below: naming both
        // sides of the comparison is the point here, not an oversight.
        // ignore: avoid_redundant_argument_values
        isCompact: false,
      );
      final paginatedWithCompactRequested = OcptFountainEditorStylesheet.build(
        metrics: metrics,
        colorScheme: colorScheme,
        isPageSimulationEnabled: true,
        isCompact: true,
      );

      for (final node in [characterNode, parentheticalNode, dialogueNode]) {
        final withoutCompact = _styleOf(paginated, document, node);
        final withCompactRequested = _styleOf(paginatedWithCompactRequested, document, node);

        expect(withCompactRequested[Styles.padding], withoutCompact[Styles.padding]);
        expect(withCompactRequested[Styles.maxWidth], withoutCompact[Styles.maxWidth]);
      }
    });
  });
}
