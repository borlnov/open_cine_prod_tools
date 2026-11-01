// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_text_search.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_clipboard_actions.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_line_attributions.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_replace_node_text_request.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_search.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_spell_check_ranges.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_codec.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_context_menu.dart';
import 'package:spell_kit/spell_kit.dart';
import 'package:super_editor/super_editor.dart';

/// The styled editor's right-click context menu handling: resolves what sits under a right-click
/// (a caret, a selection, a misspelled word), keeps the answer the menu shows, and carries out the
/// entry the writer picks.
///
/// The document, the editor and the composer are resolved through callbacks at call time, since
/// the styled editor replaces all three whenever its text is rebuilt from outside.
final class OcptStyledContextMenu {
  /// The controller opening/closing the right-click context menu ([OcptEditorContextMenu]), which
  /// the owning widget's build also positions it with, at the tap [onSecondaryTapUp] resolved.
  final MenuController controller;

  /// Resolves the document the menu acts on.
  final MutableDocument Function() _documentOf;

  /// Resolves the editor executing the menu's requests.
  final Editor Function() _editorOf;

  /// Resolves the composer holding the selection.
  final MutableDocumentComposer Function() _composerOf;

  /// The key bound to the document layout, used to resolve the position under a right-click.
  final GlobalKey _documentLayoutKey;

  /// The focus node of the styled editor, focused back after every entry.
  final FocusNode _focusNode;

  /// The spell-check state a right-click on a misspelled word is resolved against.
  final OcptStyledSpellCheckRanges _spellCheck;

  /// Whether the owning widget is still mounted.
  final bool Function() _isMounted;

  /// Rebuilds the owning widget around `change`.
  final void Function(VoidCallback change) _setState;

  /// Resolves the owning widget's current suggestions callback.
  final Future<List<String>> Function(String word)? Function() _onSpellingSuggestionsRequestedOf;

  /// Resolves the owning widget's current ignore-word callback.
  final ValueChanged<String>? Function() _onWordIgnoredOf;

  /// Resolves the owning widget's current learn-word callback.
  final ValueChanged<String>? Function() _onWordLearnedOf;

  /// The node id [_misspelledRange]/[_misspelledWord] belong to, or null when
  /// the last right-click didn't land on a misspelling. Set by [onSecondaryTapUp], read back by
  /// [applySuggestion] to know which node to rewrite.
  String? _misspelledNodeId;

  /// The range (relative to [_misspelledNodeId]'s own text at the moment of the tap)
  /// [_misspelledWord] was found at.
  SpellRange? _misspelledRange;

  /// The misspelled word the last right-click landed on, or null when it didn't — read by the build
  /// to gate [OcptEditorContextMenu]'s spelling group (its own `misspelledWord` parameter).
  String? _misspelledWord;

  /// Up to five spelling suggestions for [_misspelledWord], fetched once by
  /// [onSecondaryTapUp] when the menu opened — never refetched on every rebuild.
  List<String> _suggestions;

  /// Get the misspelled word the last right-click landed on, or null when it didn't — read by the
  /// owning widget's build to gate [OcptEditorContextMenu]'s spelling group.
  String? get misspelledWord => _misspelledWord;

  /// Up to five spelling suggestions for [misspelledWord], fetched once when the menu opened —
  /// never refetched on every rebuild.
  List<String> get suggestions => _suggestions;

  /// Tell whether the owning widget is still mounted.
  bool get mounted => _isMounted();

  /// Tell whether [_composer]'s current selection is expanded, i.e. there is something for the
  /// right-click context menu's Cut/Copy entries to act on: read fresh on every the build, so it
  /// always reflects whatever [onSecondaryTapUp] just resolved before forcing that rebuild (see
  /// that method's own doc comment).
  bool get hasExpandedSelection {
    final selection = _composer.selection;
    return selection != null && !selection.isCollapsed;
  }

  /// Get the block type the right-click context menu's submenu should show as selected, or null
  /// when
  /// the caret sits on no block that can be retyped — no selection at all, a node that isn't a
  /// `ParagraphNode`, or a title-page field (mirrors `applyBlockType`'s own guard, since picking a
  /// type from the submenu ultimately calls it). [OcptEditorContextMenu] also reads this null-ness
  /// to decide whether the submenu appears at all.
  FountainLineType? get blockType {
    final selection = _composer.selection;
    if (selection == null) {
      return null;
    }

    final node = _document.getNodeById(selection.extent.nodeId);
    if (node is! ParagraphNode || OcptWysiwygCodec.isTitlePageNode(node)) {
      return null;
    }

    return OcptFountainLineAttributions.typeOfAttributionValue(node.getMetadataValue("blockType"));
  }

  /// Get the document the menu acts on.
  MutableDocument get _document => _documentOf();

  /// Get the editor executing the menu's requests.
  Editor get _editor => _editorOf();

  /// Get the composer holding the selection.
  MutableDocumentComposer get _composer => _composerOf();

  /// Create an [OcptStyledContextMenu].
  OcptStyledContextMenu({
    required MutableDocument Function() documentOf,
    required Editor Function() editorOf,
    required MutableDocumentComposer Function() composerOf,
    required GlobalKey documentLayoutKey,
    required FocusNode focusNode,
    required OcptStyledSpellCheckRanges spellCheck,
    required bool Function() isMounted,
    required void Function(VoidCallback change) setState,
    required Future<List<String>> Function(String word)? Function()
    onSpellingSuggestionsRequestedOf,
    required ValueChanged<String>? Function() onWordIgnoredOf,
    required ValueChanged<String>? Function() onWordLearnedOf,
  }) : controller = MenuController(),
       _suggestions = const [],
       _documentOf = documentOf,
       _editorOf = editorOf,
       _composerOf = composerOf,
       _documentLayoutKey = documentLayoutKey,
       _focusNode = focusNode,
       _spellCheck = spellCheck,
       _isMounted = isMounted,
       _setState = setState,
       _onSpellingSuggestionsRequestedOf = onSpellingSuggestionsRequestedOf,
       _onWordIgnoredOf = onWordIgnoredOf,
       _onWordLearnedOf = onWordLearnedOf;

  /// Resolve the document position under a right-click and open [controller] there.
  ///
  /// [details]' global position is converted to the document layout's own local coordinates through
  /// [DocumentLayout.getDocumentOffsetFromAncestorOffset] — a thin wrapper, on the pinned
  /// `0.3.0-dev.52`, around that exact layout's own `RenderBox.globalToLocal` — never the gesture
  /// detector's own local offset: that's what keeps this correct under the page-simulation
  /// `FittedBox` scaling, which the raw local offset would otherwise silently ignore. (The layout's
  /// box itself isn't reachable through [_documentLayoutKey] directly: `SuperEditor` wraps it in a
  /// `SliverToBoxAdapter` internally, so walking down from that key's own element lands on the
  /// sliver's render object, not the box.)
  ///
  /// A collapsed caret is placed at that position unless it already sits inside an expanded
  /// selection — right-clicking inside a selection must never destroy it, which is the whole point
  /// of the Cut/Copy entries the menu is about to show.
  ///
  /// Also resolves the styled spelling group (`docs/architecture/screenplay.md`): if the
  /// resolved document position falls inside one of [the last applied ranges]'s own ranges
  /// (see `OcptStyledSpellCheckRanges.misspellingAt`), the misspelled word is read out of that node's **current** display
  /// text (never the text the range was computed against, which may be stale) and
  /// `OcptStyledScreenplayEditor.onSpellingSuggestionsRequested` is awaited for up to five
  /// suggestions before the menu opens — the one isolate round trip a right-click accepts
  /// paying only when a right-click actually asks for it. `details.localPosition` is captured
  /// before that await (an [Offset] the widget tree could otherwise recycle from under a stale
  /// reference), `mounted` is checked after it, and the answer is dropped outright if the caret has
  /// moved on in the meantime — a suggestion list for a word the writer already clicked away from
  /// would be worse than none.
  ///
  /// Either way, `setState` runs right before the menu opens: nothing about a selection change
  /// (placing this exact caret included) schedules a rebuild of this widget on its own (see
  /// `_onSelectionChanged`'s own doc comment on why a separate read-state channel exists for the
  /// toolbar), so without it the build would hand [OcptEditorContextMenu] the *previous* selection's
  /// Cut/Copy/submenu availability — and the *previous* right-click's spelling group — instead of
  /// the one this tap just settled on.
  Future<void> onSecondaryTapUp(TapUpDetails details) async {
    final layout = _documentLayoutKey.currentState as DocumentLayout?;
    if (layout == null) {
      return;
    }

    final documentOffset = layout.getDocumentOffsetFromAncestorOffset(details.globalPosition);
    final position = layout.getDocumentPositionNearestToOffset(documentOffset);
    if (position == null) {
      return;
    }

    final selection = _composer.selection;
    final tapIsInsideSelection =
        selection != null &&
        !selection.isCollapsed &&
        _document.doesSelectionContainPosition(selection, position);
    if (!tapIsInsideSelection) {
      _editor.execute([
        ChangeSelectionRequest(
          DocumentSelection.collapsed(position: position),
          SelectionChangeType.placeCaret,
          SelectionReason.userInteraction,
        ),
      ]);
    }

    final localPosition = details.localPosition;
    final selectionAfterTap = _composer.selection;
    final misspelling = _spellCheck.misspellingAt(position);

    final nodeId = misspelling?.nodeId;
    final range = misspelling?.range;
    final word = misspelling?.word;
    var fetchedSuggestions = const <String>[];

    final onSpellingSuggestionsRequested = _onSpellingSuggestionsRequestedOf();
    if (word != null && onSpellingSuggestionsRequested != null) {
      final fetched = await onSpellingSuggestionsRequested(word);
      if (!mounted || _composer.selection != selectionAfterTap) {
        return;
      }
      fetchedSuggestions = fetched.take(5).toList(growable: false);
    }

    _setState(() {
      _misspelledNodeId = nodeId;
      _misspelledRange = range;
      _misspelledWord = word;
      _suggestions = fetchedSuggestions;
    });
    controller.open(position: localPosition);
  }

  /// Handle the right-click context menu's suggestion entries: replaces
  /// [_misspelledNodeId]/[_misspelledRange] with [suggestion], through the
  /// very same [OcptReplaceNodeTextRequest] + [OcptStyledSearch.replaceMatchesInText] path
  /// `replaceCurrentMatch` already uses — a single [Editor.execute] call, so the edit and the
  /// reclassification pass it triggers merge into **one** undo step
  /// (`docs/architecture/screenplay.md`, "Undo and redo").
  ///
  /// The node is re-read and the range re-clamped against its *current* text length right here,
  /// rather than trusting what [onSecondaryTapUp] resolved: an edit made elsewhere while the menu
  /// was open (the suggestion fetch's own await gap, chiefly) could have moved that node's text out
  /// from under the range. A range that no longer fits is dropped — nothing is written — rather
  /// than handed to [OcptStyledSearch.replaceMatchesInText], which would otherwise slice past the text's end.
  void applySuggestion(String suggestion) {
    final nodeId = _misspelledNodeId;
    final range = _misspelledRange;
    if (nodeId == null || range == null) {
      _focusNode.requestFocus();
      return;
    }

    final node = _document.getNodeById(nodeId);
    if (node is! ParagraphNode || range.end > node.text.toPlainText().length) {
      _focusNode.requestFocus();
      return;
    }

    _editor.execute([
      OcptReplaceNodeTextRequest(
        nodeId: nodeId,
        text: OcptStyledSearch.replaceMatchesInText(node.text, [
          OcptTextMatch(start: range.start, end: range.end),
        ], suggestion),
      ),
    ]);

    _focusNode.requestFocus();
  }

  /// Handle the right-click context menu's "Ignore this word" entry: reports
  /// [_misspelledWord] up through `OcptStyledScreenplayEditor.onWordIgnored` and hands
  /// focus back to the editor, same as every other menu entry. Never touches the document itself —
  /// the bloc's own re-check is what makes the underline disappear, once it answers.
  void ignoreWord() {
    final word = _misspelledWord;
    if (word != null) {
      _onWordIgnoredOf()?.call(word);
    }
    _focusNode.requestFocus();
  }

  /// Handle the right-click context menu's "Add to the project's dictionary" entry, the mirror of
  /// [ignoreWord] for `OcptStyledScreenplayEditor.onWordLearned`.
  void learnWord() {
    final word = _misspelledWord;
    if (word != null) {
      _onWordLearnedOf()?.call(word);
    }
    _focusNode.requestFocus();
  }

  /// Close the right-click context menu when a left click lands anywhere on the document while it
  /// is open, the way clicking away from a menu closes it everywhere else in the app.
  ///
  /// Only the primary button does this: the secondary button is what opens the menu in the first
  /// place ([onSecondaryTapUp] runs on its tap *up*, after this very handler has seen its down),
  /// and closing on it would make a second right-click a toggle rather than a re-position. Clicks
  /// on the menu itself never reach here — it is an overlay painted above this surface, and it
  /// absorbs its own pointers.
  void onPointerDownOverDocument(PointerDownEvent event) {
    if (event.buttons != kPrimaryButton || !controller.isOpen) {
      return;
    }

    controller.close();
  }

  /// Handle the right-click context menu's Copy entry: copies the current selection's Fountain
  /// source to
  /// the clipboard through [ocptCopySelectionToClipboard], the same helper the Ctrl+C key handler
  /// uses, so the payload is the exact same plain Fountain text whichever gesture asks for it.
  /// Hands focus back to the editor afterwards, same as `applyBlockType`.
  void copySelection() {
    final selection = _composer.selection;
    if (selection == null) {
      return;
    }

    ocptCopySelectionToClipboard(document: _document, selection: selection);
    _focusNode.requestFocus();
  }

  /// Handle the right-click context menu's Cut entry: the same copy as [copySelection],
  /// followed by deleting the selection, mirroring the Ctrl+X key handler.
  void cutSelection() {
    final selection = _composer.selection;
    if (selection == null) {
      return;
    }

    ocptCopySelectionToClipboard(document: _document, selection: selection);
    _editor.execute(const [DeleteSelectionRequest(TextAffinity.downstream)]);
    _focusNode.requestFocus();
  }

  /// Handle the right-click context menu's Paste entry: [ocptPasteFountainClipboardContent], the
  /// same
  /// Fountain-aware paste the Ctrl+V key handler uses.
  void paste() {
    unawaited(
      ocptPasteFountainClipboardContent(editor: _editor, document: _document, composer: _composer),
    );
    _focusNode.requestFocus();
  }

  /// Handle the right-click context menu's Select all entry: expands the selection across the whole
  /// document, mirroring super_editor's own `CommonEditorOperations.selectAll`. A no-op on an empty
  /// document (which [_document] never actually is once the menu can open, but this mirrors that
  /// operation's own defensive guard).
  void selectAll() {
    if (_document.isEmpty) {
      return;
    }

    _editor.execute([
      ChangeSelectionRequest(
        DocumentSelection(
          base: DocumentPosition(
            nodeId: _document.first.id,
            nodePosition: _document.first.beginningPosition,
          ),
          extent: DocumentPosition(
            nodeId: _document.last.id,
            nodePosition: _document.last.endPosition,
          ),
        ),
        SelectionChangeType.expandSelection,
        SelectionReason.userInteraction,
      ),
    ]);
    _focusNode.requestFocus();
  }
}
