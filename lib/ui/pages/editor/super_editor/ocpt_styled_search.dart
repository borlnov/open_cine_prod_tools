// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_text_search.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/ocpt_editor_search.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/ocpt_styled_editor_controller.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_note.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_replace_node_text_request.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_search_match_styler.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_notes.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_search_match.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_search_notes.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_inline_runs.dart';
import 'package:super_editor/super_editor.dart';

/// The `ChangeSelectionRequest` reason the styled editor gives a selection it moves **itself** to
/// navigate — a scene jump from the scene list, a find match — rather than one the user placed.
///
/// super_editor scrolls the caret into view on the next frame after any selection change whose
/// reason is `SelectionReason.userInteraction`, with a minimal reveal that stops at the viewport's
/// edge. Tagged that way, a navigation would be yanked back to the edge by that reveal just as its
/// own `Scrollable.ensureVisible` started placing the target a third of the way down. Any other
/// string skips the reveal, and this one says what actually happened.
const String ocptProgrammaticNavigationSelectionReason = "ocptProgrammaticNavigation";

/// The styled editor's find/replace handling: owns the active query, the current-match index and
/// the [OcptSearchMatchStyler] painting the highlight, and computes, navigates to and replaces
/// matches over the document it is handed.
///
/// The document and the editor are resolved through callbacks at call time, since the styled
/// editor replaces both whenever its text is rebuilt from outside.
final class OcptStyledSearch {
  /// This helper's half of the find/replace bar's highlight, handed to `SuperEditor` as a custom
  /// style phase; never rebuilt, so `markDirty()` calls survive across a build rather than
  /// resetting the highlight every frame.
  final OcptSearchMatchStyler styler;

  /// Resolves the document the matches are computed over.
  final MutableDocument Function() _documentOf;

  /// Resolves the editor executing the selection and replace requests.
  final Editor Function() _editorOf;

  /// The key bound to the document layout, used to resolve a node's on-screen component.
  final GlobalKey _documentLayoutKey;

  /// Whether the owning widget is still mounted.
  final bool Function() _isMounted;

  /// The notes of the document, whose text is searched too and whose cards show the matches.
  final OcptStyledNotes _notes;

  /// Called with the total match count every time the matches are recomputed.
  final void Function(int count) _onMatchCountReported;

  /// The find/replace query [update] last set, or null while there is no active search —
  /// `editor_page.dart` sets this to null whenever the bar is closed, a different mode is active,
  /// or a version is being previewed.
  OcptEditorSearchQuery? _query;

  /// The current-match index [update] last set, among the matches [orderedSearchMatches] computes
  /// for [query]; null while there is none.
  int? _currentMatchIndex;

  /// Get the active find/replace query, or null while there is no active search.
  OcptEditorSearchQuery? get query => _query;

  /// Tell whether the owning widget is still mounted.
  bool get mounted => _isMounted();

  /// Get the document the matches are computed over.
  MutableDocument get _document => _documentOf();

  /// Get the editor executing the selection and replace requests.
  Editor get _editor => _editorOf();

  /// Create an [OcptStyledSearch].
  OcptStyledSearch({
    required MutableDocument Function() documentOf,
    required Editor Function() editorOf,
    required GlobalKey documentLayoutKey,
    required bool Function() isMounted,
    required OcptStyledNotes notes,
    required void Function(int count) onMatchCountReported,
  }) : styler = OcptSearchMatchStyler(),
       _documentOf = documentOf,
       _editorOf = editorOf,
       _documentLayoutKey = documentLayoutKey,
       _isMounted = isMounted,
       _notes = notes,
       _onMatchCountReported = onMatchCountReported;

  /// Get every current match of [query], in document order (node order, then offset within the
  /// node) — the single computation [recompute], [replaceCurrentMatch] and
  /// [replaceAllMatches] all go through, so none of them can drift from what the highlight
  /// actually shows.
  ///
  /// The matches in the text of a note come where the marker of the note stands in its node, in
  /// the order of the text of the note: the marker hides that text, but it is shown in the card
  /// of the note.
  ///
  /// Only [ParagraphNode]s are searched, which title-page field nodes are too (see
  /// `OcptWysiwygCodec`): they sit on screen and are ordinarily editable
  /// (`ocptTitlePageGuardRequestHandler` permits ordinary text edits inside a field, only guarding
  /// against merging or deleting the node itself), so a search that skipped them would miss text
  /// the user can plainly see and type into. This is also why the styled mode's own match count
  /// changes with the page-simulation toggle: the title sheet, and every field on it, only exists
  /// at all while page simulation is on (see `_decode`'s own doc comment).
  List<OcptStyledSearchMatch> orderedSearchMatches(OcptEditorSearchQuery query) {
    final matches = <OcptStyledSearchMatch>[];
    for (final node in _document) {
      if (node is! ParagraphNode) {
        continue;
      }

      final nodeMatches =
          <OcptStyledSearchMatch>[
            for (final match in query.matchesIn(node.text.toPlainText()))
              OcptStyledSearchMatch(nodeId: node.id, match: match, anchor: match.start),
            for (final placeholder in node.text.placeholders.entries)
              if (placeholder.value case final OcptFountainNote note)
                for (final match in query.matchesIn(note.text))
                  OcptStyledSearchMatch(
                    nodeId: node.id,
                    noteId: note.id,
                    match: match,
                    anchor: placeholder.key,
                  ),
          ]..sort(
            (a, b) =>
                a.anchor != b.anchor ? a.anchor - b.anchor : a.orderInAnchor - b.orderInAnchor,
          );
      matches.addAll(nodeMatches);
    }
    return matches;
  }

  /// Recompute every match of [query] over the live document's own display text, feed them to
  /// [styler], report the total count to `OcptStyledScreenplayEditor.styledController`, and — only
  /// when [navigateToCurrent] is true — places the selection on `currentMatchIndex`'s match and
  /// scroll it into view (see
  /// [navigateTo]'s own doc comment on why that never takes keyboard focus).
  void recompute({required bool navigateToCurrent}) {
    final query = _query;
    if (query == null) {
      styler.updateMatches(matchesByNodeId: const {}, currentMatchNodeId: null, currentMatch: null);
      _notes
        ..setMatches(const {})
        ..clearQuietSelection();
      _onMatchCountReported(0);
      return;
    }

    final orderedMatches = orderedSearchMatches(query);
    final matchesByNodeId = <String, List<OcptTextMatch>>{};
    for (final entry in orderedMatches) {
      if (!entry.isInNote) {
        (matchesByNodeId[entry.nodeId] ??= []).add(entry.match);
      }
    }

    _onMatchCountReported(orderedMatches.length);

    final currentIndex = _currentMatchIndex;
    final current =
        currentIndex != null && currentIndex >= 0 && currentIndex < orderedMatches.length
        ? orderedMatches[currentIndex]
        : null;

    final currentInText = current != null && !current.isInNote ? current : null;
    styler.updateMatches(
      matchesByNodeId: matchesByNodeId,
      currentMatchNodeId: currentInText?.nodeId,
      currentMatch: currentInText?.match,
    );
    _notes.setMatches(OcptStyledSearchNotes.matchesByNote(orderedMatches, current));

    if (!navigateToCurrent) {
      return;
    }

    if (current != null && current.isInNote) {
      navigateToNote(current.nodeId, current.noteId!);
    } else {
      _notes.clearQuietSelection();
      if (current != null) {
        navigateTo(current.nodeId, current.match);
      }
    }
  }

  /// Select [match] inside the node [nodeId] and scroll it into view, the styled mode's own
  /// counterpart to the state's own jump handling — **deliberately never calls
  /// `_focusNode.requestFocus()`**: the find field must keep the keyboard focus while the user
  /// types a query or presses Next/Previous. `build`'s `selectionPolicies` already sets
  /// `clearSelectionWhenEditorLosesFocus: false` on this exact editor for that reason, so the
  /// selection placed here survives staying unfocused.
  ///
  /// The scroll itself runs in a post-frame callback, unlike the state's own jump handling's own
  /// synchronous call: unlike a scene jump (always triggered from an already-built frame), this can
  /// run from [OcptStyledEditorController.attach] inside `initState`, before the document layout —
  /// and with it, [_documentLayoutKey]'s own component lookup — exists for this build at all.
  void navigateTo(String nodeId, OcptTextMatch match) {
    if (!mounted || _document.getNodeById(nodeId) == null) {
      return;
    }

    _editor.execute([
      ChangeSelectionRequest(
        DocumentSelection(
          base: DocumentPosition(
            nodeId: nodeId,
            nodePosition: TextNodePosition(offset: match.start),
          ),
          extent: DocumentPosition(
            nodeId: nodeId,
            nodePosition: TextNodePosition(offset: match.end),
          ),
        ),
        SelectionChangeType.expandSelection,
        ocptProgrammaticNavigationSelectionReason,
      ),
    ]);

    _scrollToNode(nodeId);
  }

  /// Select the note [noteId] held by the node [nodeId], its card (or its popover) showing its
  /// matches, and scroll its line into view. Like [navigateTo] it never takes the keyboard focus
  /// from the find field: the card is selected without its field taking it. The caret goes just
  /// after the note's marker, so the text of the previous match no longer shows selected.
  void navigateToNote(String nodeId, String noteId) {
    if (!mounted || _document.getNodeById(nodeId) == null) {
      return;
    }

    final entry = _notes.entryOf(noteId);
    if (entry != null) {
      _editor.execute([
        ChangeSelectionRequest(
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: entry.nodeId,
              nodePosition: TextNodePosition(offset: entry.offset + 1),
            ),
          ),
          SelectionChangeType.placeCaret,
          ocptProgrammaticNavigationSelectionReason,
        ),
      ]);
    }
    _notes.select(noteId, takesFocus: false);
    _scrollToNode(nodeId);
  }

  /// Replace the find/replace query and current-match index this widget highlights/navigates to,
  /// then immediately recomputes and (re-)navigates — see [recompute]'s own doc
  /// comment on when it does each.
  void update({required OcptEditorSearchQuery? query, required int? currentMatchIndex}) {
    _query = query;
    _currentMatchIndex = currentMatchIndex;
    recompute(navigateToCurrent: true);
  }

  /// Replace the current match (see `orderedMatches`) with [replacement] and return the
  /// index, among the fresh matches left afterwards, of the first one starting at or past the end
  /// of what was just written — never simply the match now sitting at the same index, which a
  /// replacement that itself still matches the query (`MARIE` → `MARIE-JEANNE`) would land back
  /// inside, compounding on every further `Replace` press (see
  /// `OcptStyledEditorControllerDelegate.replaceCurrentMatch`'s own doc comment). Returns null,
  /// doing nothing, while there is no current match, or once none remain after the edit.
  ///
  /// The comparison walks the fresh matches in document order (built once as a node-id → node-index
  /// map, `nodeIndexById`, rather than calling `Document.getNodeIndexById` per candidate): a match
  /// in a node past the edited one always counts as "after", whatever its own offset.
  int? replaceCurrentMatch(String replacement) {
    final query = _query;
    final currentIndex = _currentMatchIndex;
    if (query == null || currentIndex == null) {
      return null;
    }

    final matches = orderedSearchMatches(query);
    if (currentIndex < 0 || currentIndex >= matches.length) {
      return null;
    }

    final current = matches[currentIndex];
    final node = _document.getNodeById(current.nodeId);
    if (node is! ParagraphNode) {
      return null;
    }

    final noteId = current.noteId;
    var writtenEnd = current.match.start + replacement.length;
    if (noteId != null) {
      final note = _noteIn(node, noteId);
      final replaced = note == null
          ? null
          : OcptStyledSearchNotes.replacedText(
              note.text,
              [current.match],
              replacement,
              allowsBlankLines: OcptWysiwygInlineRuns.holdsOnlyNotes(node.text),
            );
      if (replaced == null) {
        // The note cannot hold the replacement: leave it as it is and go on to the next match.
        return (currentIndex + 1) % matches.length;
      }

      writtenEnd = current.match.start + replacement.length;
      _editor.execute([
        OcptReplaceNodeTextRequest(
          nodeId: node.id,
          text: OcptStyledSearchNotes.withNoteTexts(node.text, {noteId: replaced}),
        ),
      ]);
    } else {
      _editor.execute([
        OcptReplaceNodeTextRequest(
          nodeId: node.id,
          text: replaceMatchesInText(node.text, [current.match], replacement),
        ),
      ]);
    }

    final freshMatches = orderedSearchMatches(query);
    if (freshMatches.isEmpty) {
      return null;
    }

    final nodeIndexById = <String, int>{
      for (var i = 0; i < _document.nodeCount; i++) _document.getNodeAt(i)!.id: i,
    };
    final currentNodeIndex = nodeIndexById[current.nodeId] ?? 0;
    final nextIndex = freshMatches.indexWhere((entry) {
      final entryNodeIndex = nodeIndexById[entry.nodeId] ?? 0;
      if (entryNodeIndex != currentNodeIndex) {
        return entryNodeIndex > currentNodeIndex;
      }
      return noteId == null
          ? entry.isAtOrAfter(anchor: writtenEnd, orderInAnchor: -1)
          : entry.isAtOrAfter(anchor: current.anchor, orderInAnchor: writtenEnd);
    });
    return nextIndex == -1 ? 0 : nextIndex;
  }

  /// Replace every current match of [query] with [replacement], one
  /// [OcptReplaceNodeTextRequest] per node carrying at least one match, grouped into a single
  /// [Editor.execute] call, so one undo step for the text of the blocks and of their notes
  /// together. A note that cannot hold the replacement (it would hold a `]]`, a `/*` or a `*/`, or
  /// end with a `]`) is left as it is, the others being replaced. A no-op while there is no active
  /// search or it matches nothing.
  void replaceAllMatches(String replacement) {
    final query = _query;
    if (query == null) {
      return;
    }

    final matches = orderedSearchMatches(query);
    final requests = <EditRequest>[];
    for (final nodeId in {for (final entry in matches) entry.nodeId}) {
      final node = _document.getNodeById(nodeId);
      if (node is! ParagraphNode) {
        continue;
      }

      final nodeMatches = matches.where((entry) => entry.nodeId == nodeId).toList();
      final noteTexts = _replacedNoteTexts(node, nodeMatches, replacement);
      final textMatches = [
        for (final entry in nodeMatches)
          if (!entry.isInNote) entry.match,
      ];
      if (noteTexts.isEmpty && textMatches.isEmpty) {
        continue;
      }

      requests.add(
        OcptReplaceNodeTextRequest(
          nodeId: nodeId,
          text: replaceMatchesInText(
            OcptStyledSearchNotes.withNoteTexts(node.text, noteTexts),
            textMatches,
            replacement,
          ),
        ),
      );
    }

    if (requests.isNotEmpty) {
      _editor.execute(requests);
    }
  }

  /// Get the text each note of [node] holding a match of [matches] gets once they are replaced with
  /// [replacement], by note identifier, leaving out the note that cannot hold it.
  Map<String, String> _replacedNoteTexts(
    ParagraphNode node,
    List<OcptStyledSearchMatch> matches,
    String replacement,
  ) {
    final texts = <String, String>{};
    final allowsBlankLines = OcptWysiwygInlineRuns.holdsOnlyNotes(node.text);
    for (final noteId in {
      for (final entry in matches)
        if (entry.noteId != null) entry.noteId!,
    }) {
      final note = _noteIn(node, noteId);
      final replaced = note == null
          ? null
          : OcptStyledSearchNotes.replacedText(
              note.text,
              [
                for (final entry in matches)
                  if (entry.noteId == noteId) entry.match,
              ],
              replacement,
              allowsBlankLines: allowsBlankLines,
            );
      if (replaced != null) {
        texts[noteId] = replaced;
      }
    }
    return texts;
  }

  /// Find the note [noteId] among the placeholders of [node], or null when it holds none.
  OcptFountainNote? _noteIn(ParagraphNode node, String noteId) {
    for (final value in node.text.placeholders.values) {
      if (value is OcptFountainNote && value.id == noteId) {
        return value;
      }
    }
    return null;
  }

  /// Scroll the block [nodeId] into view once the frame is built, a third of the way down.
  void _scrollToNode(String nodeId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final component = (_documentLayoutKey.currentState as DocumentLayout?)?.getComponentByNodeId(
        nodeId,
      );
      if (component == null) {
        return;
      }
      final componentState = component as State;
      if (componentState.mounted) {
        unawaited(
          Scrollable.ensureVisible(
            componentState.context,
            alignment: 0.3,
            duration: const Duration(milliseconds: 200),
          ),
        );
      }
    });
  }

  /// Return a copy of [original] with every one of [matches] (assumed non-overlapping and in
  /// left-to-right order, exactly as `OcptEditorSearchQuery.matchesIn` returns them) replaced by
  /// [replacement], every untouched span keeping its original attributions (`copyText` carries
  /// them along; only the freshly-inserted [replacement] text itself carries none).
  static AttributedText replaceMatchesInText(
    AttributedText original,
    List<OcptTextMatch> matches,
    String replacement,
  ) {
    var result = original.copyText(0, 0);
    var cursor = 0;
    for (final match in matches) {
      result = result.copyAndAppend(original.copyText(cursor, match.start));
      if (replacement.isNotEmpty) {
        result = result.copyAndAppend(AttributedText(replacement));
      }
      cursor = match.end;
    }
    return result.copyAndAppend(original.copyText(cursor));
  }
}
