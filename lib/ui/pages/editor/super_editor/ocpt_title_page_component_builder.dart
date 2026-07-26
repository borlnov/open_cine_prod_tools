// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_title_page_layout.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_codec.dart';
import 'package:super_editor/super_editor.dart';

/// A [ComponentBuilder] rendering a title-page field's own placeholder hint (e.g. "Title") on an
/// empty node, and shifting the Contact/Source nodes onto Draft date's row — everything this
/// styled editor's title sheet needs beyond a plain [ParagraphComponentBuilder]
/// ([OcptWysiwygCodec.isTitlePageNode]).
///
/// **The placeholder hint.** super_editor ships `HintComponentBuilder` for this exact rendering,
/// reusing its `TextWithHintComponent`, but that widget cannot align a hint at all: its hint
/// `Text.rich` is a non-positioned `Stack` child under loose constraints, so it always sizes to
/// its own intrinsic text width and sits at the stack's `topStart` regardless of the `textAlign`
/// the caller passes in (`text.dart:785-814` of the pinned super_editor `0.3.0-dev.52` release,
/// `TextWithHintComponent.build`) — a centred or right-aligned field's hint would still be painted
/// flush left. This builder therefore stops delegating to `TextWithHintComponent` and instead
/// decorates the delegate's own component directly, the way `OcptSceneNumberGutterComponentBuilder`
/// decorates a scene heading with its number: build the real (`ParagraphComponentBuilder`)
/// component first, then paint the hint in a `Positioned.fill` behind it, so the hint is stretched
/// across the exact box the real component's own `Styles.padding`/`Styles.textAlign`/
/// `Styles.textStyle` already resolved to.
///
/// **The row shift.** `OcptFountainEditorStylesheet`'s title-page rule lays Draft date, Contact and
/// Source out as three ordinary rows of a `SingleColumnDocumentLayout`'s `Column`, one node per
/// row — it cannot do otherwise, since the two fields stay two separately-editable Fountain
/// title-page nodes (see `ocptTitlePageFieldLayoutOf`'s own doc comment). Benoit wants the PDF's
/// bottom row instead: Contact and Draft date on the same line. This builder gets there by
/// painting Contact (and, so it still follows immediately underneath, Source) `rowShift` logical
/// pixels higher than the `Column` placed them — a **paint-time** `Transform.translate`, applied
/// only to the node's own component, never to its row's height.
///
/// That is safe here specifically because of how super_editor resolves the caret, the selection
/// and the tap target: not by widget hit testing, but by measuring the `RenderBox` the component's
/// own `GlobalKey` is attached to (`componentContext.componentKey`, attached to `base` below) via
/// `RenderBox.localToGlobal`/`getTransformTo` (`_findComponentClosestToOffset`/
/// `_isOffsetInComponent`, and `getRectForPosition`, at `layout_single_column/_layout.dart:574-635`
/// and `253-266` of the pinned release). A `Transform` sitting between that `RenderBox` and the
/// document layout's own box is a genuine render-tree ancestor, so every one of those calls
/// already accounts for it — the caret, the selection and the tap target move exactly where the
/// text is painted, even though the `Column` still thinks Contact's row starts one `rowShift`
/// lower. `computeOcptStyledTitlePageMetrics`'s flow height is therefore unchanged by this
/// transform (see its own doc comment); only the paint position moves.
///
/// The row shift is deliberately computed in [createViewModel], not read from a value resolved
/// once by the widget that constructs this builder: the outer `OcptStyledScreenplayEditor` widget does
/// not rebuild on every keystroke (super_editor's own document-driven layout re-renders without
/// it), but this builder's own `createViewModel` *is* re-invoked, with the live [Document], for
/// every title-page node on every document change — including a brand new node an Enter split
/// inside Contact just created. A value threaded in through the constructor instead would freeze
/// at whatever the document looked like the last time the outer widget happened to rebuild, and a
/// freshly split node born after that point would never receive its shift at all.
///
/// Claims every title-page field node (not only the empty ones, so a value typed into a field
/// keeps rendering through this same builder rather than jumping to another one), and delegates
/// every other node to whichever builder comes after it in `SuperEditor.componentBuilders` by
/// returning null, the same convention every builder in this directory follows.
///
/// The claim has to be made independently in **both** [createViewModel] and [createComponent],
/// checking the node's own [ocptTitlePageFieldAttribution] `blockType` in each: `SuperEditor`'s
/// layout resolves a node's component by walking `SuperEditor.componentBuilders` in order and
/// keeping the first non-null `createComponent` result, and that walk hands `createComponent`
/// whichever view model was actually resolved for the node — which may have been built by a
/// *different* builder's `createViewModel` (e.g. an ordinary body node's, built by the default
/// `ParagraphComponentBuilder`). A `createComponent` that accepted every
/// [ParagraphComponentViewModel] regardless of node type would swallow every other builder's nodes
/// too (see `OcptSceneNumberGutterComponentBuilder`'s own doc comment for the same fact, and the
/// bug it and this builder both had before `blockType` was checked here).
class OcptTitlePageComponentBuilder extends ParagraphComponentBuilder {
  /// Creates an [OcptTitlePageComponentBuilder].
  OcptTitlePageComponentBuilder({required this.placeholders, required this.hintStyleBuilder, required this.metrics});

  /// The placeholder text to show for an empty field, keyed by [ocptTitlePageFieldKeys] (a key
  /// missing an entry, which should not normally happen, simply never gets a hint shown for it):
  /// this builder resolves which node, if any, gets a given field's hint itself (see
  /// [_placeholderFieldKeyByNodeId]), so the caller only ever needs to say what each *field* is
  /// called, not which node currently represents it.
  final Map<String, String> placeholders;

  /// Decorates a title-page field's own resolved [TextStyle] — read from the delegate's
  /// `componentViewModel.textStyleBuilder(const {})`, i.e. exactly the style the stylesheet
  /// resolved for that node — into the style its placeholder hint is painted with. Must only
  /// `copyWith` on top of the style it's handed (normally the italic slope and a dimmed color),
  /// never build a fresh [TextStyle]: inheriting is what guarantees the placeholder's size and weight
  /// match the value that will replace it.
  final TextStyle Function(TextStyle resolvedStyle) hintStyleBuilder;

  /// The layout metrics [computeOcptStyledTitlePageMetrics] needs to compute `rowShift` — the same
  /// metrics the stylesheet and the pagination pass were built with.
  final FountainLayoutMetrics metrics;

  /// [computeOcptStyledTitlePageMetrics]'s `rowShift`, refreshed against the live document every
  /// time [createViewModel] runs for a Contact or Source node, and read back by [createComponent]
  /// (which never sees the document, only this node's view model) for that same node moments
  /// later, in the same layout pass. Absent for every other title-page node.
  final Map<String, double> _rowShiftByNodeId = {};

  /// The [ocptTitlePageFieldKeys] key of the field [createComponent] should paint a placeholder
  /// hint for, keyed by node id — present only for a field's **first** node (a field spanning
  /// several nodes, from an Enter split inside it, would otherwise show the same hint on every one
  /// of them), refreshed against the live document every time [createViewModel] runs for a
  /// title-page node, and read back by [createComponent] for that same node moments later, in the
  /// same layout pass (mirrors [_rowShiftByNodeId]'s own lifetime, see the class-level doc comment
  /// for why that pattern is safe here). Absent for every node that isn't a field's first.
  final Map<String, String> _placeholderFieldKeyByNodeId = {};

  @override
  SingleColumnLayoutComponentViewModel? createViewModel(Document document, DocumentNode node) {
    if (node is! ParagraphNode || !OcptWysiwygCodec.isTitlePageNode(node)) {
      return null;
    }

    final key = node.getMetadataValue(ocptTitlePageKeyMetadataKey) as String;
    if (key == "Contact" || key == "Source") {
      _rowShiftByNodeId[node.id] = computeOcptStyledTitlePageMetrics(document: document, metrics: metrics).rowShift;
    } else {
      _rowShiftByNodeId.remove(node.id);
    }

    final previous = document.getNodeBeforeById(node.id);
    final isFirstNodeOfField =
        previous is! ParagraphNode ||
        !OcptWysiwygCodec.isTitlePageNode(previous) ||
        previous.getMetadataValue(ocptTitlePageKeyMetadataKey) != key;
    if (isFirstNodeOfField) {
      _placeholderFieldKeyByNodeId[node.id] = key;
    } else {
      _placeholderFieldKeyByNodeId.remove(node.id);
    }

    return super.createViewModel(document, node);
  }

  @override
  Widget? createComponent(
    SingleColumnDocumentComponentContext componentContext,
    SingleColumnLayoutComponentViewModel componentViewModel,
  ) {
    if (componentViewModel is! ParagraphComponentViewModel ||
        componentViewModel.blockType != ocptTitlePageFieldAttribution) {
      return null;
    }

    final base = super.createComponent(componentContext, componentViewModel);
    if (base == null) {
      return null;
    }

    final fieldKey = _placeholderFieldKeyByNodeId[componentViewModel.nodeId];
    final placeholder = fieldKey == null ? null : placeholders[fieldKey];
    final Widget content;
    if (placeholder == null || componentViewModel.text.toPlainText().isNotEmpty) {
      content = base;
    } else {
      final resolvedStyle = componentViewModel.textStyleBuilder(const {});
      content = Stack(
        children: [
          // Painted *behind* the real component (`base` last), so the caret is never hidden by the
          // hint — the same order `TextWithHintComponent` itself uses. `Positioned.fill` stretches
          // the hint across the box `base` defines, which is what makes `textAlign` mean anything
          // at all; the `Stack` stays sized by `base`, its only non-positioned child, so the node
          // keeps the exact height it has today.
          Positioned.fill(
            child: IgnorePointer(
              child: Text(
                placeholder,
                textAlign: componentViewModel.textAlignment,
                style: hintStyleBuilder(resolvedStyle),
              ),
            ),
          ),
          base,
        ],
      );
    }

    final rowShift = _rowShiftByNodeId[componentViewModel.nodeId];
    if (rowShift == null || rowShift == 0) {
      return content;
    }

    return Transform.translate(offset: Offset(0, -rowShift), child: content);
  }
}
