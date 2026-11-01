// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/types/ocpt_inline_style.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/ocpt_editor_search.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/ocpt_styled_editor_controller.dart';
import 'package:spell_kit/spell_kit.dart';

/// Internal wiring contract between [OcptStyledEditorController] and whichever widget state
/// currently owns a live styled editor: **not** a public extension point, just the interface that
/// lets the controller live in this page-level file (no `package:super_editor` import) while the
/// widget state that actually knows how to apply a change lives in the `super_editor/` directory.
///
/// Dart's privacy is per-file, so this can't be a leading-underscore name if the implementing
/// class lives in a different file; only [OcptStyledEditorController] is meant to call these
/// methods, and only the styled editor's own state is meant to implement them.
abstract class OcptStyledEditorControllerDelegate {
  /// Whether there is a gesture of the writer's left for [undo] to take back.
  bool get canUndo;

  /// Whether there is an undone gesture left for [redo] to put back *and* it can still be put
  /// back — no edit having been made since it was undone.
  bool get canRedo;

  /// Applies a manual block-type change (dropdown selection) to the currently selected block.
  void applyBlockType(FountainLineType type);

  /// Toggles [style] on the current selection (or the composer's pending style, if collapsed).
  void applyToggleInlineStyle(OcptInlineStyle style);

  /// Replaces the find/replace query and current-match index the delegate highlights/navigates
  /// to, mirroring [OcptStyledEditorController.updateSearch]'s own doc comment. `null`/`null`
  /// means "no active search" (the bar is closed, a different mode is active, or a version is
  /// being previewed).
  void updateSearch({required OcptEditorSearchQuery? query, required int? currentMatchIndex});

  /// Replaces the current match (the one [updateSearch] last pointed at) with [replacement],
  /// returning the index, among the matches left afterwards, of the first one starting at or past
  /// the end of what was just written (wrapping to `0`, or `null` if none remain) — the caller
  /// (`editor_page.dart`) is what turns that into a fresh
  /// `OcptEditorSearchCurrentMatchSelectedEvent`, mirroring the raw mode's own
  /// `_requestRawReplace`.
  int? replaceCurrentMatch(String replacement);

  /// Replaces every current match with [replacement] in one grouped edit.
  void replaceAllMatches(String replacement);

  /// Applies [rangesByNodeId] — the bloc's own answer, keyed by node id — to this delegate's own
  /// spelling styler, mirroring [updateSearch]'s own direction of travel. Ranges for a node id this
  /// delegate's live document no longer holds, or that no longer fit that node's *current* text
  /// length, are dropped rather than fed to the styler
  /// (`docs/architecture/screenplay.md`).
  void updateSpellCheckRanges(Map<String, List<SpellRange>> rangesByNodeId);

  /// Takes back the writer's last gesture, plus everything the editor derived from it; does
  /// nothing when [canUndo] is false.
  void undo();

  /// Puts back the last undone gesture; does nothing when [canRedo] is false.
  void redo();
}
