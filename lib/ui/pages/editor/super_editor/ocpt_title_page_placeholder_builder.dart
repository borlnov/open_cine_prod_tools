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
/// super_editor ships `HintComponentBuilder` for this exact rendering (`TextWithHintComponent`,
/// reused here as-is), but only ever for the document's first node, which does not generalize to
/// six specific field nodes anywhere in the document: this builder keeps
/// `HintComponentBuilder`'s approach (delegate to [ParagraphComponentBuilder] for the real paragraph
/// view model, wrap it in a [HintComponentViewModel] carrying the hint text) but selects nodes by
/// [ocptTitlePageKeyMetadataKey] instead of by position, mirroring how
/// `OcptSceneNumberGutterComponentBuilder` also delegates to [ParagraphComponentBuilder] for one
/// specific kind of node.
///
/// Delegates every other node (a non-title-page node, or a title-page node that already has text)
/// to whichever builder comes after it in `SuperEditor.componentBuilders` by returning null, the
/// same convention every builder in this directory follows.
class OcptTitlePagePlaceholderComponentBuilder extends ParagraphComponentBuilder {
  /// Creates an [OcptTitlePagePlaceholderComponentBuilder].
  const OcptTitlePagePlaceholderComponentBuilder({required this.placeholders, required this.hintStyleBuilder});

  /// The placeholder text to show for each empty title-page field, keyed by
  /// [ocptTitlePageFieldKeys] (a field missing from this map, which should not normally happen,
  /// simply never gets a hint).
  final Map<String, String> placeholders;

  /// The text style the hint is painted with.
  final TextStyle Function(BuildContext) hintStyleBuilder;

  @override
  SingleColumnLayoutComponentViewModel? createViewModel(Document document, DocumentNode node) {
    if (node is! ParagraphNode || node.text.toPlainText().isNotEmpty) {
      return null;
    }

    final key = node.getMetadataValue(ocptTitlePageKeyMetadataKey);
    final placeholder = key is String ? placeholders[key] : null;
    if (placeholder == null) {
      return null;
    }

    final base = super.createViewModel(document, node);
    if (base is! ParagraphComponentViewModel) {
      return null;
    }

    return HintComponentViewModel.fromParagraphViewModel(base, hintText: placeholder);
  }

  @override
  Widget? createComponent(
    SingleColumnDocumentComponentContext componentContext,
    SingleColumnLayoutComponentViewModel componentViewModel,
  ) {
    if (componentViewModel is! HintComponentViewModel) {
      return null;
    }

    return TextWithHintComponent(
      key: componentContext.componentKey,
      text: componentViewModel.text,
      textAlign: componentViewModel.textAlignment,
      textStyleBuilder: componentViewModel.textStyleBuilder,
      hintText: AttributedText(componentViewModel.hintText),
      hintStyleBuilder: (attributions) => hintStyleBuilder(componentContext.context),
      textSelection: componentViewModel.selection,
      selectionColor: componentViewModel.selectionColor,
    );
  }
}
