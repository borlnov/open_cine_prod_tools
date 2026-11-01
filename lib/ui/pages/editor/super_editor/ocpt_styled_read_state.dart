// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/types/ocpt_inline_style.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/ocpt_styled_editor_controller.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_line_attributions.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_inline_style_attributions.dart';
import 'package:super_editor/super_editor.dart';

/// Reads the caret's block type, the active inline styles and the undo/redo availability off a
/// styled editor and reports them to its [OcptStyledEditorController].
///
/// The document and the composer are resolved through callbacks at call time, since the styled
/// editor replaces both whenever its text is rebuilt from outside.
final class OcptStyledReadState {
  /// Creates an [OcptStyledReadState].
  OcptStyledReadState({
    required OcptStyledEditorController? Function() controllerOf,
    required MutableDocument Function() documentOf,
    required MutableDocumentComposer Function() composerOf,
    required bool Function() canUndoOf,
    required bool Function() canRedoOf,
  }) : _controllerOf = controllerOf,
       _documentOf = documentOf,
       _composerOf = composerOf,
       _canUndoOf = canUndoOf,
       _canRedoOf = canRedoOf;

  /// Resolves the controller the read state is reported to, or null when there is none.
  final OcptStyledEditorController? Function() _controllerOf;

  /// Resolves the document the caret sits in.
  final MutableDocument Function() _documentOf;

  /// Resolves the composer holding the selection.
  final MutableDocumentComposer Function() _composerOf;

  /// Whether there is anything left to undo.
  final bool Function() _canUndoOf;

  /// Whether there is anything left to redo.
  final bool Function() _canRedoOf;

  /// The document the caret sits in.
  MutableDocument get _document => _documentOf();

  /// The composer holding the selection.
  MutableDocumentComposer get _composer => _composerOf();

  /// Refreshes [OcptStyledEditorController]'s read side (the toolbar's dropdown/B-I-U state, and
  /// whether there is anything left to undo or redo) from the caret's current node type, the
  /// active inline styles and the editor's own history, called after every attach, every document
  /// rebuild, every document change, every selection change and every composer-preferences change
  /// (bold/italic/underline toggled for the next typed character while the caret is collapsed).
  void report() {
    final controller = _controllerOf();
    if (controller == null) {
      return;
    }

    final selection = _composer.selection;
    final node = selection == null ? null : _document.getNodeById(selection.extent.nodeId);
    final currentBlockType = node is ParagraphNode
        ? OcptFountainLineAttributions.typeOfAttributionValue(node.getMetadataValue("blockType"))
        : FountainLineType.action;

    controller.updateReadState(
      currentBlockType: currentBlockType,
      activeInlineStyles: {
        for (final style in OcptInlineStyle.values)
          if (doesSelectionHaveStyle(style)) style,
      },
      canUndo: _canUndoOf(),
      canRedo: _canRedoOf(),
    );
  }

  /// Whether [style]'s attribution is active over the current selection: for a collapsed caret,
  /// the composer's pending style preferences (what the next typed character will carry); for an
  /// expanded selection, whether every character of it already carries the attribution.
  ///
  /// Mirrors the pattern super_editor's own mobile toolbar
  /// (`KeyboardEditingToolbarOperations._doesSelectionHaveAttributions`) uses for the same check.
  bool doesSelectionHaveStyle(OcptInlineStyle style) {
    final selection = _composer.selection;
    if (selection == null) {
      return false;
    }

    final attribution = OcptInlineStyleAttributions.attributionOf(style);
    if (selection.isCollapsed) {
      return _composer.preferences.currentAttributions.contains(attribution);
    }
    return _document.doesSelectedTextContainAttributions(selection, {attribution});
  }
}
