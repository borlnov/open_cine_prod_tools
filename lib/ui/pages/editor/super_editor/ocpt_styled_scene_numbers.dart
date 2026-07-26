// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_line_attributions.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_codec.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_edit_requests.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_preview_layout.dart';
import 'package:super_editor/super_editor.dart';

/// Matches a scene number already in the sequential `<integer><optional letters>` shape this
/// app auto-numbers with (e.g. `"4"` or, for an inserted scene, `"4A"`), capturing the integer
/// base in group 1 and the letter suffix (possibly empty) in group 2.
final RegExp _sequentialSceneNumberPattern = RegExp(r'^([0-9]+)([A-Za-z]*)$');

/// Computes the requests needed to bring every scene heading's [ocptSceneNumberMetadataKey]
/// metadata back to a valid, gapless sequential numbering of [document], in source order —
/// every heading always ends up with a number, so it always round-trips into the Fountain source
/// through [OcptWysiwygCodec.encode] (this app has no "hide the numbers from the source" mode).
///
/// Walks the document keeping the last plain integer consumed so far (starting at 0, i.e. no
/// scene consumed yet). A heading with no letter suffix is kept as-is when its number is exactly
/// one past that (it becomes the new "last consumed"); a heading with a letter suffix (e.g. the
/// `"A"` of `"4A"`) is kept as-is when its base equals that same last-consumed integer, without
/// advancing it — a deliberate inserted scene right after it, so `"4B"` or plain `"5"` can still
/// follow it correctly. Every other case — no number yet, or one that does not match what comes
/// next (out of order, a gap, a duplicate, a hand-typed value that makes no sense in context) —
/// is corrected to the next plain integer.
///
/// Pure and stateless: it only reads [document]'s current metadata and returns the requests a
/// caller must still execute against a live `Editor` to actually apply them.
List<EditRequest> sceneNumberNormalizationRequests(Document document) {
  final requests = <EditRequest>[];
  var lastConsumed = 0;

  for (final node in document) {
    if (node is! ParagraphNode) {
      continue;
    }
    final type = OcptFountainLineAttributions.typeOfAttributionValue(node.getMetadataValue("blockType"));
    if (type != FountainLineType.sceneHeading) {
      continue;
    }

    final currentNumber = node.getMetadataValue(ocptSceneNumberMetadataKey);
    final match = currentNumber is String ? _sequentialSceneNumberPattern.firstMatch(currentNumber) : null;
    final base = match == null ? null : int.parse(match.group(1)!);
    final hasLetterSuffix = match != null && match.group(2)!.isNotEmpty;

    if (!hasLetterSuffix && base == lastConsumed + 1) {
      lastConsumed = base!;
      continue;
    }
    if (hasLetterSuffix && base == lastConsumed) {
      continue;
    }

    final correctedNumber = "${lastConsumed + 1}";
    if (currentNumber != correctedNumber) {
      requests.add(
        OcptChangeNodeMetadataRequest(nodeId: node.id, metadata: {ocptSceneNumberMetadataKey: correctedNumber}),
      );
    }
    lastConsumed++;
  }

  return requests;
}

/// A [ComponentBuilder] that draws a scene heading's number (from [sceneNumbers], keyed by node
/// id — the caller normally builds it by reading every heading's already-normalized
/// [ocptSceneNumberMetadataKey] metadata straight off the document, see
/// [sceneNumberNormalizationRequests]) into the heading's own left gutter, right-aligned close to
/// the heading text — mirroring where the PDF exporter prints it in the
/// page margin — without changing the heading's own wrap width, since the number is painted
/// alongside the delegate's component rather than added to its text.
///
/// Delegates the actual paragraph rendering to [ParagraphComponentBuilder] and only intercepts
/// scene-heading nodes; every other node falls through, letting the next builder in the
/// `SuperEditor.componentBuilders` list (normally [ParagraphComponentBuilder] itself, from
/// `defaultComponentBuilders`, but possibly a title-page builder in between) handle it. The number
/// is painted with a non-clipping `Stack`/`Positioned` at a negative left offset, landing inside
/// the node's own `Styles.padding` left inset (which `SingleColumnLayoutComponent` never clips),
/// exactly the way `Padding` leaves room for it.
///
/// The "only a scene heading" claim has to be made independently in **both** [createViewModel] and
/// [createComponent], returning null from each for every other node: `SingleColumnDocumentLayout`
/// resolves a node's component by walking `SuperEditor.componentBuilders` in order and keeping the
/// first non-null `createComponent` result (`layout_single_column/_layout.dart:1001-1006` of the
/// pinned super_editor release), and that walk hands `createComponent` whichever view model was
/// resolved for the node — which may have been built by a *different* builder's `createViewModel`
/// (e.g. a title-page node's, built by the title-page builder). A `createComponent` that accepted
/// every [ParagraphComponentViewModel] regardless of node type would therefore swallow every other
/// builder's nodes too, never letting them run at all.
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
  ///
  /// Claims a node — rather than falling through to let the next builder try — only when
  /// [sceneNumbers] actually has an entry for it: every scene heading is expected to have one (see
  /// [sceneNumbers]'s own doc comment), so its absence is this builder's only stateless signal, at
  /// `createComponent` time, that the node isn't one of its own (see the class-level doc comment
  /// for why `createComponent` cannot simply trust it was only ever handed a heading's view model).
  @override
  Widget? createComponent(
    SingleColumnDocumentComponentContext componentContext,
    SingleColumnLayoutComponentViewModel componentViewModel,
  ) {
    if (componentViewModel is! ParagraphComponentViewModel) {
      return null;
    }

    final number = sceneNumbers[componentViewModel.nodeId];
    if (number == null) {
      return null;
    }

    final base = _delegate.createComponent(componentContext, componentViewModel);
    if (base == null) {
      return null;
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
