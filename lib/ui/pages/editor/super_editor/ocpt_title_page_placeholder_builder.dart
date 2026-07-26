// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_codec.dart';
import 'package:super_editor/super_editor.dart';

/// A [ComponentBuilder] showing a per-field placeholder hint (e.g. "Title") on an empty title-page
/// field node ([OcptWysiwygCodec.isTitlePageNode]), the fill-in cue the styled editor's title
/// sheet needs for every field the source doesn't already have a value for.
///
/// super_editor ships `HintComponentBuilder` for this exact rendering, reusing its
/// `TextWithHintComponent`, but that widget cannot align a hint at all: its hint `Text.rich` is a
/// non-positioned `Stack` child under loose constraints, so it always sizes to its own intrinsic
/// text width and sits at the stack's `topStart` regardless of the `textAlign` the caller passes
/// in (`text.dart:785-814` of the pinned super_editor `0.3.0-dev.52` release, `TextWithHintComponent
/// .build`) — a centred or right-aligned field's hint would still be painted flush left. This
/// builder therefore stops delegating to `TextWithHintComponent` and instead decorates the
/// delegate's own component directly, the way `OcptSceneNumberGutterComponentBuilder` decorates a
/// scene heading with its number: build the real (`ParagraphComponentBuilder`) component first,
/// then paint the hint in a `Positioned.fill` behind it, so the hint is stretched across the exact
/// box the real component's own `Styles.padding`/`Styles.textAlign`/`Styles.textStyle` already
/// resolved to.
///
/// Claims every title-page field node (not only the empty ones, so a value typed into a field
/// keeps rendering through this same builder rather than jumping to another one), and delegates
/// every other node to whichever builder comes after it in `SuperEditor.componentBuilders` by
/// returning null, the same convention every builder in this directory follows.
class OcptTitlePagePlaceholderComponentBuilder extends ParagraphComponentBuilder {
  /// Creates an [OcptTitlePagePlaceholderComponentBuilder].
  const OcptTitlePagePlaceholderComponentBuilder({required this.placeholders, required this.hintStyleBuilder});

  /// The placeholder text to show for an empty title-page field node, keyed by node id (a node
  /// missing an entry, which should not normally happen, simply never gets a hint): this builder's
  /// `createComponent` is only ever handed a [SingleColumnLayoutComponentViewModel], never the
  /// node's own metadata, so the caller resolves each field's label ahead of time, the same way
  /// `OcptSceneNumberGutterComponentBuilder.sceneNumbers` is keyed by node id.
  final Map<String, String> placeholders;

  /// Decorates a title-page field's own resolved [TextStyle] — read from the delegate's
  /// `componentViewModel.textStyleBuilder(const {})`, i.e. exactly the style the stylesheet
  /// resolved for that node — into the style its placeholder hint is painted with. Must only
  /// `copyWith` on top of the style it's handed (normally the italic slope and a dimmed color),
  /// never build a fresh [TextStyle]: inheriting is what guarantees the placeholder's size and weight
  /// match the value that will replace it.
  final TextStyle Function(TextStyle resolvedStyle) hintStyleBuilder;

  @override
  SingleColumnLayoutComponentViewModel? createViewModel(Document document, DocumentNode node) {
    if (node is! ParagraphNode || !OcptWysiwygCodec.isTitlePageNode(node)) {
      return null;
    }

    return super.createViewModel(document, node);
  }

  @override
  Widget? createComponent(
    SingleColumnDocumentComponentContext componentContext,
    SingleColumnLayoutComponentViewModel componentViewModel,
  ) {
    if (componentViewModel is! ParagraphComponentViewModel) {
      return null;
    }

    final base = super.createComponent(componentContext, componentViewModel);
    if (base == null) {
      return null;
    }

    final placeholder = placeholders[componentViewModel.nodeId];
    if (placeholder == null || componentViewModel.text.toPlainText().isNotEmpty) {
      return base;
    }

    final resolvedStyle = componentViewModel.textStyleBuilder(const {});
    return Stack(
      children: [
        // Painted *behind* the real component (`base` last), so the caret is never hidden by the
        // hint — the same order `TextWithHintComponent` itself uses. `Positioned.fill` stretches
        // the hint across the box `base` defines, which is what makes `textAlign` mean anything at
        // all; the `Stack` stays sized by `base`, its only non-positioned child, so the node keeps
        // the exact height it has today.
        Positioned.fill(
          child: IgnorePointer(
            child: Text(placeholder, textAlign: componentViewModel.textAlignment, style: hintStyleBuilder(resolvedStyle)),
          ),
        ),
        base,
      ],
    );
  }
}
