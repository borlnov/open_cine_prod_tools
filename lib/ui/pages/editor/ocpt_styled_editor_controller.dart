// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/types/ocpt_inline_style.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/ocpt_editor_search.dart';
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
  /// (`editor_page.dart`) is what turns that into a fresh `OcptEditorSearchCurrentMatchSelectedEvent`,
  /// mirroring the raw mode's own `_requestRawReplace`.
  int? replaceCurrentMatch(String replacement);

  /// Replaces every current match with [replacement] in one grouped edit.
  void replaceAllMatches(String replacement);

  /// Applies [rangesByNodeId] — the bloc's own answer, keyed by node id — to this delegate's own
  /// spelling styler, mirroring [updateSearch]'s own direction of travel. Ranges for a node id this
  /// delegate's live document no longer holds, or that no longer fit that node's *current* text
  /// length, are dropped rather than fed to the styler
  /// (`docs/architecture/screenplay.md`).
  void updateSpellCheckRanges(Map<String, List<SpellRange>> rangesByNodeId);

  /// Whether there is a gesture of the writer's left for [undo] to take back.
  bool get canUndo;

  /// Whether there is an undone gesture left for [redo] to put back *and* it can still be put
  /// back — no edit having been made since it was undone.
  bool get canRedo;

  /// Takes back the writer's last gesture, plus everything the editor derived from it; does
  /// nothing when [canUndo] is false.
  void undo();

  /// Puts back the last undone gesture; does nothing when [canRedo] is false.
  void redo();
}

/// The app-level bridge between the editor toolbar and the live styled screenplay editor: the
/// toolbar only ever talks to this controller (read the caret's block type / active inline
/// styles, request a block-type change or an inline-style toggle), never to `package:super_editor`
/// directly, which keeps the toolbar widget engine-agnostic.
///
/// A single instance is owned by the editor page and handed to both the toolbar and the styled
/// editor widget. It is [isAttached] only while a live styled editor exists to
/// [attach]/[updateReadState] it — in particular, never while the editor is in raw mode — which is
/// what lets the toolbar hide its format controls exactly when there is nothing to apply them to.
class OcptStyledEditorController extends ChangeNotifier {
  /// The delegate currently attached (the styled editor's own state), or null while detached (raw
  /// mode, or before the very first attach).
  OcptStyledEditorControllerDelegate? _delegate;

  /// The block type of the caret's current node, mirrored from the live styled editor by
  /// [updateReadState].
  FountainLineType _currentBlockType = FountainLineType.action;

  /// The inline styles active at the caret (or across the whole selection), mirrored from the live
  /// styled editor by [updateReadState].
  Set<OcptInlineStyle> _activeInlineStyles = const {};

  /// The find/replace query last handed to [updateSearch], remembered here (rather than only
  /// forwarded) so a delegate that attaches *after* the query was set — a raw → styled mode switch
  /// while the bar is already open — still gets it immediately at [attach] time, instead of
  /// waiting for the page's own next reactive sync to happen to call [updateSearch] again.
  OcptEditorSearchQuery? _searchQuery;

  /// The current-match index last handed to [updateSearch], remembered for the same reason as
  /// [_searchQuery].
  int? _searchCurrentMatchIndex;

  /// The match count the attached delegate last reported through [reportSearchMatchCount]; `0`
  /// while detached.
  int _searchMatchCount = 0;

  /// The misspelled ranges by node id [updateSpellCheckRanges] last set, remembered here for the
  /// same reason [_searchQuery] is: a delegate attaching after this was set (a raw → styled mode
  /// switch while the ranges are already known) must receive them immediately at [attach] time,
  /// rather than waiting for the page's next reactive sync.
  Map<String, List<SpellRange>> _spellCheckRangesByNodeId = const {};

  /// The checkable node texts the attached delegate last reported through [reportSpellCheckTexts];
  /// empty while detached, since there is nothing to check without a live document to read them
  /// from.
  Map<String, String> _spellCheckTextsByNodeId = const {};

  /// Whether the attached delegate had anything left to undo when it last called
  /// [updateReadState]; false while detached.
  bool _canUndo = false;

  /// Whether the attached delegate had anything left to redo when it last called
  /// [updateReadState]; false while detached.
  bool _canRedo = false;

  /// The match count the toolbar/page should currently show for the styled mode's own search.
  int get searchMatchCount => _searchMatchCount;

  /// The checkable node texts the page should currently forward into a fresh spell-check request —
  /// `editor_page.dart` reads this from its own controller-listener wiring (the equivalent of
  /// `_onStyledEditorControllerChanged`) and dispatches a fresh bloc event whenever it actually
  /// changed, mirroring [searchMatchCount]'s own pattern.
  Map<String, String> get spellCheckTextsByNodeId => _spellCheckTextsByNodeId;

  /// Whether [dispose] was already called, checked by a pending [_notifySafely] deferral before it
  /// finally calls `notifyListeners()`: a post-frame callback can otherwise easily outlive this
  /// controller (for example in a widget test that tears its tree down, disposing this controller,
  /// before the next frame that would have run the callback ever gets pumped), and
  /// `ChangeNotifier.notifyListeners()` asserts when called after [dispose].
  bool _disposed = false;

  /// Whether a live styled editor is currently attached; false in raw mode.
  bool get isAttached => _delegate != null;

  /// The block type the toolbar's dropdown should currently show.
  FountainLineType get currentBlockType => _currentBlockType;

  /// The inline styles the toolbar's B/I/U toggles should currently show as selected.
  Set<OcptInlineStyle> get activeInlineStyles => _activeInlineStyles;

  /// Whether the live styled editor currently has anything to undo — what an `Undo` affordance
  /// reads to decide whether to appear at all. False while detached (raw mode), where the raw
  /// field's own `UndoHistoryController` is what answers the same question.
  bool get canUndo => _canUndo;

  /// Whether the live styled editor currently has anything to redo, in the sense that it can
  /// still be redone *correctly*: the attached delegate refuses a redo whose transactions a later
  /// edit has overtaken, and this mirrors that same predicate rather than recomputing one of its
  /// own. False while detached (raw mode).
  bool get canRedo => _canRedo;

  /// Requests that the writer's last gesture be taken back, forwarded to the attached delegate; a
  /// no-op while detached (raw mode).
  void undo() {
    _delegate?.undo();
  }

  /// Requests that the last undone gesture be put back, forwarded to the attached delegate (which
  /// refuses it when [canRedo] is false); a no-op while detached (raw mode).
  void redo() {
    _delegate?.redo();
  }

  /// Requests that the caret's current block become [type], forwarded to the attached delegate; a
  /// no-op while detached (raw mode).
  void setBlockType(FountainLineType type) {
    _delegate?.applyBlockType(type);
  }

  /// Requests that [style] be toggled on the current selection, forwarded to the attached
  /// delegate; a no-op while detached (raw mode).
  void toggleInlineStyle(OcptInlineStyle style) {
    _delegate?.applyToggleInlineStyle(style);
  }

  /// Records the find/replace bar's current [query]/[currentMatchIndex] and forwards them to the
  /// attached delegate (which highlights every match, places the selection on the current one and
  /// scrolls it into view — deliberately without taking keyboard focus, since the find field is
  /// what must keep it), or simply remembers them while detached (raw mode) for the next [attach]
  /// to pick up.
  ///
  /// `editor_page.dart` only calls this when the navigation target actually changed (the same
  /// dedup its raw-mode counterpart applies to `_navigateToMatch`) — every keystroke made *inside*
  /// the styled document while the bar stays open is instead picked up reactively by the attached
  /// delegate itself, since only it has live access to each node's current text.
  void updateSearch({required OcptEditorSearchQuery? query, required int? currentMatchIndex}) {
    _searchQuery = query;
    _searchCurrentMatchIndex = currentMatchIndex;
    _delegate?.updateSearch(query: query, currentMatchIndex: currentMatchIndex);
  }

  /// Requests that the current match (the one the last [updateSearch] call pointed at) be
  /// replaced by [replacement], forwarded to the attached delegate; returns null while detached
  /// (raw mode). See [OcptStyledEditorControllerDelegate.replaceCurrentMatch]'s own doc comment
  /// for what the returned index means.
  int? replaceCurrentMatch(String replacement) => _delegate?.replaceCurrentMatch(replacement);

  /// Requests that every current match be replaced by [replacement], forwarded to the attached
  /// delegate; a no-op while detached (raw mode).
  void replaceAllMatches(String replacement) {
    _delegate?.replaceAllMatches(replacement);
  }

  /// Records the misspelled ranges [rangesByNodeId] (keyed by node id) and forwards them to the
  /// attached delegate, or simply remembers them while detached (raw mode) for the next [attach] to
  /// pick up — the styled mode's own counterpart to [updateSearch], for the identical reason: a raw
  /// → styled mode switch while the ranges are already known must not wait for the page's next
  /// reactive sync.
  void updateSpellCheckRanges(Map<String, List<SpellRange>> rangesByNodeId) {
    _spellCheckRangesByNodeId = rangesByNodeId;
    _delegate?.updateSpellCheckRanges(rangesByNodeId);
  }

  /// Pushes a fresh set of checkable node texts from the attached delegate — the styled mode's own
  /// half of "each mode matches what it shows" (`docs/architecture/screenplay.md`), and
  /// the mirror image of [updateSpellCheckRanges]'s direction of travel.
  ///
  /// Notifies listeners only when the set actually changed from what was last reported, mirroring
  /// [reportSearchMatchCount]'s own dedup: the delegate calls this after every settle pass
  /// regardless of whether the checkable subset actually moved, and a stray notification for an
  /// unchanged set must never be mistaken by the page for a fresh one worth re-checking.
  void reportSpellCheckTexts(Map<String, String> textsByNodeId) {
    if (mapEquals(_spellCheckTextsByNodeId, textsByNodeId)) {
      return;
    }
    _spellCheckTextsByNodeId = textsByNodeId;
    _notifySafely();
  }

  /// Pushes a fresh match count from the attached delegate, the search half of [updateReadState]:
  /// called every time the delegate recomputes its matches (an explicit navigation, or a live
  /// document edit while the bar is open), listened to directly by the page (not routed through a
  /// bloc round trip) so it can turn a genuine change into a fresh
  /// `OcptEditorSearchMatchesReportedEvent`.
  void reportSearchMatchCount(int matchCount) {
    if (_searchMatchCount == matchCount) {
      return;
    }
    _searchMatchCount = matchCount;
    _notifySafely();
  }

  /// Attaches [delegate] as the live styled editor backing this controller, making [isAttached]
  /// true and letting the toolbar's format controls appear.
  ///
  /// Immediately pushes whatever [_searchQuery]/[_searchCurrentMatchIndex] and
  /// [_spellCheckRangesByNodeId] this controller already held onto the fresh delegate: a mode
  /// switch into styled mode while the find/replace bar is already open, or while the previous
  /// styled editor already had misspellings underlined, must show them right away rather than
  /// waiting for the page's own next reactive sync (see [updateSearch]'s own doc comment on why
  /// that sync doesn't fire on every possible occasion). The fresh delegate reports its own
  /// checkable node texts back on its own, in its `initState`, so nothing needs pushing the other
  /// way here.
  void attach(OcptStyledEditorControllerDelegate delegate) {
    _delegate = delegate;
    delegate.updateSearch(query: _searchQuery, currentMatchIndex: _searchCurrentMatchIndex);
    delegate.updateSpellCheckRanges(_spellCheckRangesByNodeId);
    _notifySafely();
  }

  /// Detaches [delegate], making [isAttached] false again (the toolbar's format controls hide) —
  /// a no-op if [delegate] isn't the currently attached one, guarding against a stale detach call
  /// after a rebuild already swapped in a different delegate.
  void detach(OcptStyledEditorControllerDelegate delegate) {
    if (!identical(_delegate, delegate)) {
      return;
    }
    _delegate = null;
    _searchMatchCount = 0;
    _spellCheckTextsByNodeId = const {};
    _canUndo = false;
    _canRedo = false;
    _notifySafely();
  }

  /// Pushes a fresh read-side snapshot from the attached delegate: the caret's current block type,
  /// the set of inline styles active at the caret/selection, and whether that editor has anything
  /// left to undo or redo. Listeners are only notified when one of those four actually changed,
  /// avoiding redundant toolbar rebuilds on every keystroke that doesn't move the caret across a
  /// style boundary.
  void updateReadState({
    required FountainLineType currentBlockType,
    required Set<OcptInlineStyle> activeInlineStyles,
    required bool canUndo,
    required bool canRedo,
  }) {
    if (_currentBlockType == currentBlockType &&
        setEquals(_activeInlineStyles, activeInlineStyles) &&
        _canUndo == canUndo &&
        _canRedo == canRedo) {
      return;
    }
    _currentBlockType = currentBlockType;
    _activeInlineStyles = activeInlineStyles;
    _canUndo = canUndo;
    _canRedo = canRedo;
    _notifySafely();
  }

  /// Notifies listeners immediately, unless the framework is currently in the middle of building
  /// the widget tree, in which case the notification is deferred to right after the current frame.
  ///
  /// [attach]/[detach]/[updateReadState] can all be triggered from the styled editor's
  /// `initState`/`didUpdateWidget`/`dispose`, which run synchronously as part of an ancestor's own
  /// build (for example, right after a mode toggle mounts the styled editor for the first time, in
  /// the very same frame the toolbar's `ListenableBuilder` for this same controller already
  /// rebuilt, earlier in that frame, showing the still-detached state). Calling
  /// `notifyListeners()` straight away in that situation reaches back into that already-built
  /// listener and trips Flutter's "setState()/markNeedsBuild() called during build" guard;
  /// deferring it there keeps every notification safely outside any build phase, at the cost of a
  /// harmless single-frame delay. Every other caller of [attach]/[detach]/[updateReadState] (user
  /// interaction callbacks: a keyboard shortcut, a toolbar button press) runs outside a build
  /// phase already, so it notifies immediately, with no delay at all.
  void _notifySafely() {
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!_disposed) {
          notifyListeners();
        }
      });
    } else {
      notifyListeners();
    }
  }

  /// Marks this controller disposed (see [_disposed]) before the inherited `ChangeNotifier`
  /// teardown, so a [_notifySafely] deferral still pending at that point knows not to call
  /// `notifyListeners()` once it finally runs.
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
