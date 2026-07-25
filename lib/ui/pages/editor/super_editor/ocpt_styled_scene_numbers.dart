// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_line_attributions.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_codec.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_preview_layout.dart';
import 'package:super_editor/super_editor.dart';

/// Computes the scene number to display next to every scene-heading node of [document], in
/// source order: a heading carrying an explicit [ocptSceneNumberMetadataKey] keeps it and does
/// not consume a computed number; every other heading takes the next integer starting at 1.
///
/// Pure and stateless, deliberately independent of whether the styled editor is actually
/// configured to show these numbers (see `OcptStyledScreenplayEditor.areSceneNumbersVisible`):
/// callers that don't want them displayed simply don't call this or ignore its result.
Map<String, String> computeOcptStyledSceneNumbers(Document document) {
  final numbers = <String, String>{};
  var nextComputedNumber = 1;

  for (final node in document) {
    if (node is! ParagraphNode) {
      continue;
    }
    final type = OcptFountainLineAttributions.typeOfAttributionValue(node.getMetadataValue("blockType"));
    if (type != FountainLineType.sceneHeading) {
      continue;
    }

    final explicitNumber = node.getMetadataValue(ocptSceneNumberMetadataKey);
    if (explicitNumber is String && explicitNumber.isNotEmpty) {
      numbers[node.id] = explicitNumber;
    } else {
      numbers[node.id] = "$nextComputedNumber";
      nextComputedNumber++;
    }
  }

  return numbers;
}

/// A [ComponentBuilder] that draws a scene heading's number (from [sceneNumbers], keyed by node
/// id, normally built by [computeOcptStyledSceneNumbers]) into the heading's own left gutter,
/// right-aligned close to the heading text — mirroring where the PDF exporter prints it in the
/// page margin — without changing the heading's own wrap width, since the number is painted
/// alongside the delegate's component rather than added to its text.
///
/// Delegates the actual paragraph rendering to [ParagraphComponentBuilder] and only intercepts
/// scene-heading nodes; every other node falls through (`createViewModel` returns null), letting
/// the next builder in the `SuperEditor.componentBuilders` list (normally [ParagraphComponentBuilder]
/// itself, from `defaultComponentBuilders`) handle it. The number is painted with a non-clipping
/// `Stack`/`Positioned` at a negative left offset, landing inside the node's own `Styles.padding`
/// left inset (which `SingleColumnLayoutComponent` never clips), exactly the way `Padding` leaves
/// room for it.
class OcptSceneNumberGutterComponentBuilder implements ComponentBuilder {
  /// Creates an [OcptSceneNumberGutterComponentBuilder]. Prefer
  /// [OcptSceneNumberGutterComponentBuilder.build] over calling this directly: it derives
  /// [gutterWidth] and [numberGap] from an `OcptEditorPreviewLayout` consistently with the rest
  /// of the styled editor's typesetting.
  const OcptSceneNumberGutterComponentBuilder({
    required this.sceneNumbers,
    required this.gutterWidth,
    required this.numberGap,
    required this.textStyle,
  });

  /// Builds an [OcptSceneNumberGutterComponentBuilder] for [layout]'s scene-heading indent: the
  /// gutter available to paint a number in is exactly that indent (the same left margin the raw
  /// preview and the PDF exporter both derive from [layout]/`FountainLayoutMetrics`), and the
  /// number stops one glyph width short of the heading's own text.
  factory OcptSceneNumberGutterComponentBuilder.build({
    required Map<String, String> sceneNumbers,
    required OcptEditorPreviewLayout layout,
    required TextStyle textStyle,
  }) => OcptSceneNumberGutterComponentBuilder(
    sceneNumbers: sceneNumbers,
    gutterWidth: layout.indentOf(layout.metrics.sceneHeading),
    numberGap: layout.glyphWidth,
    textStyle: textStyle,
  );

  /// The delegate every scene-heading node's actual paragraph rendering is built through.
  static const _delegate = ParagraphComponentBuilder();

  /// The scene number to paint next to each scene-heading node, keyed by node id; a node with no
  /// entry (should not normally happen once every heading has been numbered) renders with no
  /// number at all.
  final Map<String, String> sceneNumbers;

  /// The width of the gutter available to paint a number in, in logical pixels: the scene
  /// heading's own left indent, i.e. the space between the page's left edge and where its text
  /// starts.
  final double gutterWidth;

  /// The gap kept between the painted number and the heading's own text, in logical pixels.
  final double numberGap;

  /// The text style the number is painted with.
  final TextStyle textStyle;

  /// Delegates to [ParagraphComponentBuilder] for every node, but only actually claims scene
  /// heading nodes (returning null for every other node lets the next builder in the list handle
  /// it) — the gutter number is only ever relevant next to a scene heading.
  @override
  SingleColumnLayoutComponentViewModel? createViewModel(Document document, DocumentNode node) {
    if (node is! ParagraphNode) {
      return null;
    }
    final type = OcptFountainLineAttributions.typeOfAttributionValue(node.getMetadataValue("blockType"));
    if (type != FountainLineType.sceneHeading) {
      return null;
    }

    return _delegate.createViewModel(document, node);
  }

  /// Builds the delegate's normal paragraph component, then, if this node has a scene number to
  /// show, overlays it in the left gutter with a non-clipping `Stack`.
  @override
  Widget? createComponent(
    SingleColumnDocumentComponentContext componentContext,
    SingleColumnLayoutComponentViewModel componentViewModel,
  ) {
    if (componentViewModel is! ParagraphComponentViewModel) {
      return null;
    }
    final base = _delegate.createComponent(componentContext, componentViewModel);
    if (base == null) {
      return null;
    }

    final number = sceneNumbers[componentViewModel.nodeId];
    if (number == null) {
      return base;
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        base,
        Positioned(
          top: 0,
          left: -gutterWidth,
          width: gutterWidth - numberGap,
          child: Text(number, textAlign: TextAlign.right, style: textStyle),
        ),
      ],
    );
  }
}
