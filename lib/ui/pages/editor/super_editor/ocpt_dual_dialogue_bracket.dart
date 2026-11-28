// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:material_ui/material_ui.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_page_pagination.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_codec.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_comments.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_preview_layout.dart';
import 'package:super_editor/super_editor.dart';

/// Where one node of a dual-dialogue pair sits in the bracket drawn in the page's left margin.
typedef OcptDualDialogueBracketSegment = ({
  /// Whether the node is the first of the pair, where the bracket starts.
  bool isFirst,

  /// Whether the node is the last of the pair, where the bracket ends.
  bool isLast,

  /// How far above the node the bracket reaches to meet the previous node's, in logical pixels.
  double topExtension,
});

/// A [ComponentBuilder] that marks a dual-dialogue pair in the stacked styled editor.
///
/// The styled editor keeps the two speeches of a pair one under the other, since super_editor's
/// drag selection assumes components ordered from the top of the page to its bottom
/// (`docs/architecture/screenplay.md`). Two things say they are printed side by side: a vertical
/// bracket in the left margin joining the pair from its first cue to the last line of its second
/// speech, and, for a cue carrying the `^` with no speech right before it to pair with, a dimmed
/// `^` after the name.
///
/// Delegates the actual paragraph rendering to [ParagraphComponentBuilder] and only claims the
/// nodes it has something to draw for, in both [createViewModel] and [createComponent], the way
/// `OcptSceneNumberGutterComponentBuilder` does (see its class doc comment for why both must).
class OcptDualDialogueBracketComponentBuilder implements ComponentBuilder {
  /// The delegate every claimed node's actual paragraph rendering is built through.
  static const _delegate = ParagraphComponentBuilder();

  /// The bracket segment of each node of a pair, keyed by node id.
  final Map<String, OcptDualDialogueBracketSegment> segments;

  /// The ids of the cue nodes carrying the `^` with no pair, which get the dimmed marker.
  final Set<String> orphanCueIds;

  /// The distance from the text column of an action to the page's left edge, in logical pixels.
  final double marginWidth;

  /// The width of the box an action's node is laid out in, indent included, in logical pixels.
  final double actionBoxWidth;

  /// The distance kept between the bracket and the action text column, in logical pixels.
  final double bracketGap;

  /// The width of the bracket's horizontal ends, in logical pixels.
  final double endWidth;

  /// The thickness of the bracket's strokes, in logical pixels.
  final double strokeWidth;

  /// The colour the bracket is drawn in.
  final Color color;

  /// The opacity the orphan marker is painted with, against its cue's own colour.
  final double orphanOpacity;

  /// Create an [OcptDualDialogueBracketComponentBuilder]. Prefer
  /// [OcptDualDialogueBracketComponentBuilder.build], which derives everything from the document.
  const OcptDualDialogueBracketComponentBuilder({
    required this.segments,
    required this.orphanCueIds,
    required this.marginWidth,
    required this.actionBoxWidth,
    required this.bracketGap,
    required this.endWidth,
    required this.strokeWidth,
    required this.color,
    required this.orphanOpacity,
  });

  /// Build the builder for [document], laid out with [layout] (its indents multiplied by [scale]
  /// on a compact surface) and drawing in [color].
  factory OcptDualDialogueBracketComponentBuilder.build({
    required Document document,
    required OcptEditorPreviewLayout layout,
    required Color color,
    double scale = 1,
  }) {
    final analysis = OcptWysiwygDualDialogue.analysisOf(document);
    final segments = <String, OcptDualDialogueBracketSegment>{};
    for (final pair in analysis.pairs) {
      final ids = [...pair.leftNodeIds, ...pair.rightNodeIds];
      for (var index = 0; index < ids.length; index++) {
        final node = document.getNodeById(ids[index])! as ParagraphNode;
        segments[ids[index]] = (
          isFirst: index == 0,
          isLast: index == ids.length - 1,
          topExtension: index == 0 ? 0 : _blankHeightOf(node, layout),
        );
      }
    }

    return OcptDualDialogueBracketComponentBuilder(
      segments: segments,
      orphanCueIds: analysis.orphanCueIds,
      marginWidth: layout.indentOf(layout.metrics.action) * scale,
      actionBoxWidth:
          (layout.indentOf(layout.metrics.action) + layout.widthOf(layout.metrics.action)) * scale,
      bracketGap: layout.glyphWidth * scale,
      endWidth: layout.glyphWidth * scale * 0.5,
      strokeWidth: 1.5,
      color: color,
      orphanOpacity: 0.45,
    );
  }

  /// Delegate to [ParagraphComponentBuilder] for the nodes of a pair and the orphan cues, and let
  /// the next builder handle every other.
  @override
  SingleColumnLayoutComponentViewModel? createViewModel(Document document, DocumentNode node) {
    if (node is! ParagraphNode || !_claims(node.id)) {
      return null;
    }
    return _delegate.createViewModel(document, node);
  }

  /// Build the delegate's paragraph component, with the bracket or the orphan marker over it.
  @override
  Widget? createComponent(
    SingleColumnDocumentComponentContext componentContext,
    SingleColumnLayoutComponentViewModel componentViewModel,
  ) {
    if (componentViewModel is! ParagraphComponentViewModel || !_claims(componentViewModel.nodeId)) {
      return null;
    }
    final base = _delegate.createComponent(componentContext, componentViewModel);
    if (base == null) {
      return null;
    }

    final segment = segments[componentViewModel.nodeId];
    final orphanMarker = orphanCueIds.contains(componentViewModel.nodeId)
        ? Positioned.fill(
            child: IgnorePointer(
              key: ValueKey("dualDialogueOrphan:${componentViewModel.nodeId}"),
              child: _OrphanMarker(
                viewModel: componentViewModel,
                opacity: orphanOpacity,
                context: componentContext.context,
              ),
            ),
          )
        : null;
    if (segment == null) {
      return Stack(clipBehavior: Clip.none, children: [base, ?orphanMarker]);
    }

    final padding = componentViewModel.padding.resolve(TextDirection.ltr);
    return LayoutBuilder(
      builder: (context, constraints) {
        // The document column centres every node's box, whose width is the node's own `maxWidth`
        // while the column is wide enough for it and the column's own width once it is narrower,
        // so the page's left edge, where an action's box starts, sits half the difference between
        // this box and the action's one to the left of this box.
        final boxWidth = constraints.maxWidth + padding.horizontal;
        final columnWidth = OcptDualDialogueColumnScope.maybeOf(context);
        final actionWidth = columnWidth == null || actionBoxWidth < columnWidth
            ? actionBoxWidth
            : columnWidth;
        final centering = (boxWidth - actionWidth) / 2;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            base,
            ?orphanMarker,
            Positioned(
              left: centering - padding.left + marginWidth - bracketGap - endWidth,
              top: -segment.topExtension,
              bottom: 0,
              width: endWidth,
              child: IgnorePointer(
                key: ValueKey("dualDialogueBracket:${componentViewModel.nodeId}"),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(color: color, width: strokeWidth),
                      top: segment.isFirst
                          ? BorderSide(color: color, width: strokeWidth)
                          : BorderSide.none,
                      bottom: segment.isLast
                          ? BorderSide(color: color, width: strokeWidth)
                          : BorderSide.none,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Tell whether this builder draws something for the node [nodeId].
  bool _claims(String nodeId) => segments.containsKey(nodeId) || orphanCueIds.contains(nodeId);

  /// Get a key that changes whenever the pairs or the orphan cues of [document] do, for the
  /// owner of the builder to tell when it must build a fresh one.
  static String keyOf(Document document) => OcptWysiwygDualDialogue.analysisOf(document).key;

  /// Get the height of the blank lines the stylesheet opens above [node], which the bracket bridges
  /// unless the node starts a simulated page.
  static double _blankHeightOf(ParagraphNode node, OcptEditorPreviewLayout layout) {
    // Any non-zero value starts a page, a negative one included: it is how a page start whose
    // padding was clamped away is stored (see `ocptPageStartMetadataOf`).
    final pageStart = node.getMetadataValue(ocptStartsNewPageMetadataKey);
    if (pageStart is double && pageStart != 0) {
      return 0;
    }
    final count = OcptWysiwygComments.blankLinesBeforeOf(node);
    return count.clamp(0, ocptMaxBlankLinesBeforeSpacing) * layout.lineHeight;
  }
}

/// The width of the column the styled editor's nodes are centred in, for the bracket to find the
/// page's left edge from: a node's own box is as wide as the column once the column is narrower
/// than the node's `maxWidth`, and so is an action's.
class OcptDualDialogueColumnScope extends InheritedWidget {
  /// The width of the column, in logical pixels.
  final double width;

  /// Create an [OcptDualDialogueColumnScope].
  const OcptDualDialogueColumnScope({super.key, required this.width, required super.child});

  /// Tell whether a change of [oldWidget] to this scope has to rebuild the nodes below it.
  @override
  bool updateShouldNotify(OcptDualDialogueColumnScope oldWidget) => width != oldWidget.width;

  /// Get the width of the column [context] sits in, or null when no scope is above it.
  static double? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<OcptDualDialogueColumnScope>()?.width;
}

/// The dimmed `^` painted after the last character of an orphan cue, where the cue's text ends.
///
/// Measured with the cue's own text layout so it follows the name, whatever its length, without
/// being part of the node's text: the caret and the selection never reach it.
class _OrphanMarker extends StatelessWidget {
  /// The cue's view model, which holds its text and its style.
  final ParagraphComponentViewModel viewModel;

  /// The opacity the marker is painted with, against the cue's own colour.
  final double opacity;

  /// The context the cue's text is resolved in.
  final BuildContext context;

  /// Class constructor.
  const _OrphanMarker({required this.viewModel, required this.opacity, required this.context});

  /// Build the marker at the end of the cue's text.
  @override
  Widget build(BuildContext buildContext) => LayoutBuilder(
    builder: (layoutContext, constraints) {
      final span = viewModel.text.computeInlineSpan(
        context,
        viewModel.textStyleBuilder,
        viewModel.inlineWidgetBuilders,
      );
      final painter = TextPainter(
        text: span,
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.noScaling,
      )..layout(maxWidth: constraints.maxWidth);
      final end = painter.getOffsetForCaret(TextPosition(offset: viewModel.text.length), Rect.zero);
      painter.dispose();

      final style = viewModel.textStyleBuilder({});
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: end.dx,
            top: end.dy,
            child: Text(
              " ^",
              style: style.copyWith(color: style.color?.withValues(alpha: opacity)),
            ),
          ),
        ],
      );
    },
  );
}
