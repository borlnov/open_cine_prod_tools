// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/types/ocpt_editor_right_dock_tab.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/events/editor_base_event.dart';

/// The events about the docks, the editing mode and the display preferences.
sealed class OcptEditorWorkspaceEvent extends OcptEditorEvent {
  /// Class constructor
  const OcptEditorWorkspaceEvent();
}

/// Toggle the visibility of the scene panel.
class OcptEditorScenePanelToggledEvent extends OcptEditorWorkspaceEvent {
  /// Class constructor
  const OcptEditorScenePanelToggledEvent();
}

/// Select a tab of the right dock, dispatched by the toolbar's preview/syntax buttons and by the
/// dock's own tab row.
///
/// Implements decision 3's toggle semantics: if [tab] is already the dock's active tab, the dock
/// closes; otherwise the dock opens (or switches) to show [tab]. Either way, [tab] becomes
/// `OcptEditorState.lastRightDockTab`, the tab [OcptEditorRightDockToggledEvent] reopens the dock
/// on. This is also an explicit user action on the dock, so it clears
/// `OcptEditorState.autoClosedRightDockTab` — a dock the user just acted on by hand must never be
/// silently reopened by a later mode switch.
class OcptEditorRightDockTabSelectedEvent extends OcptEditorWorkspaceEvent {
  /// The tab the toolbar button pressed represents.
  final OcptEditorRightDockTab tab;

  /// Class constructor
  const OcptEditorRightDockTabSelectedEvent({required this.tab});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, tab];
}

/// Toggle the right dock as a whole, dispatched by the workspace toolbar's right dock toggle.
///
/// An open dock closes, whichever tab it shows; a closed one reopens on
/// `OcptEditorState.lastRightDockTab`, so the dock always comes back where the user left it.
/// Just like [OcptEditorRightDockTabSelectedEvent], this is an explicit user action, so it also
/// clears `OcptEditorState.autoClosedRightDockTab`.
class OcptEditorRightDockToggledEvent extends OcptEditorWorkspaceEvent {
  /// Class constructor
  const OcptEditorRightDockToggledEvent();
}

/// Close the right dock via its own × close button, whichever tab is currently active.
///
/// Just like [OcptEditorRightDockTabSelectedEvent], this is an explicit user action, so it also
/// clears `OcptEditorState.autoClosedRightDockTab`.
class OcptEditorRightDockClosedEvent extends OcptEditorWorkspaceEvent {
  /// Class constructor
  const OcptEditorRightDockClosedEvent();
}

/// Request updating the editor's dock width fractions, persisting whichever of [left]/[right] is
/// given.
///
/// Dispatched once per drag gesture, on `onHorizontalDragEnd`, never per frame: the live drag
/// itself only moves `OcptWorkspaceDockLayoutController`'s in-memory fractions, which is what
/// keeps a drag from emitting a bloc state (and rebuilding the editing subtrees) on every frame.
class OcptEditorDockFractionsChangedEvent extends OcptEditorWorkspaceEvent {
  /// The new left (scenes) dock fraction, or null to leave it unchanged.
  final double? left;

  /// The new right (preview / syntax) dock fraction, or null to leave it unchanged.
  final double? right;

  /// Class constructor
  const OcptEditorDockFractionsChangedEvent({this.left, this.right});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, left, right];
}

/// Request restoring both dock fractions to their defaults ("Reset panel layout").
class OcptEditorDockLayoutResetEvent extends OcptEditorWorkspaceEvent {
  /// Class constructor
  const OcptEditorDockLayoutResetEvent();
}

/// Toggle the editing mode between the styled block editor and the raw text source.
///
/// The new mode is persisted through `OcptPropertiesManager.editorMode`, so it's restored the
/// next time the editor is opened.
class OcptEditorModeToggledEvent extends OcptEditorWorkspaceEvent {
  /// Class constructor
  const OcptEditorModeToggledEvent();
}

/// Toggle the "Word-like" page simulation on or off.
///
/// The new value is persisted through `OcptPropertiesManager.isPageSimulationEnabled`, so it's
/// restored the next time the editor is opened.
class OcptEditorPageSimulationToggledEvent extends OcptEditorWorkspaceEvent {
  /// Class constructor
  const OcptEditorPageSimulationToggledEvent();
}

/// Toggle whether the styled editor shows every scene heading's number in its left gutter.
///
/// The new value is persisted through `OcptPropertiesManager.styledSceneNumbersVisible`, so it's
/// restored the next time the editor is opened.
class OcptEditorStyledSceneNumbersToggledEvent extends OcptEditorWorkspaceEvent {
  /// Class constructor
  const OcptEditorStyledSceneNumbersToggledEvent();
}

/// Toggle whether this machine shows the spell-check underlines, in either editing mode (the `⋮`
/// menu's "Spell check" entry, directly below "Scene numbers").
///
/// The new value is persisted through `OcptPropertiesManager.spellCheckVisible`, so it's restored
/// the next time the editor opens, and re-drives `OcptSpellCheckManager.useLanguage` (this is one
/// of the two on/off switches of `docs/architecture/screenplay.md` — the other is
/// the project's own screenplay language). Switching off also clears
/// `OcptEditorState.rawSpellCheckRanges` at once, rather than waiting for a debounce tick that
/// isn't coming: with the switch off, nothing is ever checked again until it flips back on.
class OcptEditorSpellCheckToggledEvent extends OcptEditorWorkspaceEvent {
  /// Class constructor
  const OcptEditorSpellCheckToggledEvent();
}

/// Request updating the editor's page setup (page size and margins).
///
/// [pageSetup] is persisted (format per-project, margins app-wide) and applied live to the
/// preview and the styled page editor.
class OcptEditorPageSetupChangedEvent extends OcptEditorWorkspaceEvent {
  /// The new page setup to apply and persist.
  final OcptPageSetup pageSetup;

  /// Class constructor
  const OcptEditorPageSetupChangedEvent({required this.pageSetup});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, pageSetup];
}
