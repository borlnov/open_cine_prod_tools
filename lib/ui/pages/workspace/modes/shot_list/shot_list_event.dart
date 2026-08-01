// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_xlsx_labels.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_difficulty_axis.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_column.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_right_dock_tab.dart';

/// The events handled by `OcptShotListBloc`.
sealed class OcptShotListEvent extends BlocEventForMixin {
  /// Class constructor
  const OcptShotListEvent();
}

/// Requests loading the current project's shot list, together with the persisted dock fractions,
/// visible columns and last right dock tab.
///
/// This is dispatched once by the bloc's own constructor; it isn't meant to be sent by widgets.
class OcptShotListLoadRequestedEvent extends OcptShotListEvent {
  /// Class constructor
  const OcptShotListLoadRequestedEvent();
}

/// Selects the sequence [sequenceId], expanding it in the left dock and showing its shots in the
/// centre table.
///
/// Selecting a sequence other than the one already selected clears the selected shot: the table
/// now shows a different sequence's shots, none of which the previous selection belonged to.
class OcptShotListSequenceSelectedEvent extends OcptShotListEvent {
  /// The `OcptShotSequence.id` of the sequence to select.
  final String sequenceId;

  /// Class constructor
  const OcptShotListSequenceSelectedEvent({required this.sequenceId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, sequenceId];
}

/// Selects the shot [shotId], dispatched by a table row and by a shot entry of the left dock.
///
/// Selecting a shot also selects the sequence holding it (so clicking a shot in the left dock's
/// tree switches the centre table too) and opens the right dock on its inspector tab, matching
/// the mock-up's "clicking a row opens the inspector" behaviour.
class OcptShotListShotSelectedEvent extends OcptShotListEvent {
  /// The id of the shot to select.
  final String shotId;

  /// Class constructor
  const OcptShotListShotSelectedEvent({required this.shotId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, shotId];
}

/// Requests creating a new shot at the end of the selected sequence, then selecting it.
///
/// Does nothing while no sequence is selected, or while the selected one is the orphan group: a
/// shot only ever exists inside a real screenplay scene, and the orphan group is where shots go
/// when their scene disappears, never where new ones are authored.
class OcptShotListShotCreationRequestedEvent extends OcptShotListEvent {
  /// Class constructor
  const OcptShotListShotCreationRequestedEvent();
}

/// Toggles the visibility of the left (sequences) dock.
class OcptShotListSequencePanelToggledEvent extends OcptShotListEvent {
  /// Class constructor
  const OcptShotListSequencePanelToggledEvent();
}

/// Selects a tab of the right dock, dispatched by the dock's own tab row.
///
/// Follows the screenplay editor's toggle semantics exactly: selecting the tab already active
/// closes the dock, any other tab opens (or switches) it. Either way [tab] becomes
/// `OcptShotListState.lastRightDockTab`, the tab [OcptShotListRightDockToggledEvent] reopens the
/// dock on, and is persisted.
class OcptShotListRightDockTabSelectedEvent extends OcptShotListEvent {
  /// The tab whose label was clicked.
  final OcptShotListRightDockTab tab;

  /// Class constructor
  const OcptShotListRightDockTabSelectedEvent({required this.tab});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, tab];
}

/// Toggles the right dock as a whole, dispatched by the workspace toolbar's right dock toggle: an
/// open dock closes, a closed one reopens on `OcptShotListState.lastRightDockTab`.
class OcptShotListRightDockToggledEvent extends OcptShotListEvent {
  /// Class constructor
  const OcptShotListRightDockToggledEvent();
}

/// Closes the right dock via its own × close button, whichever tab is currently active.
class OcptShotListRightDockClosedEvent extends OcptShotListEvent {
  /// Class constructor
  const OcptShotListRightDockClosedEvent();
}

/// Requests updating the mode's dock width fractions, persisting whichever of [left]/[right] is
/// given.
///
/// Dispatched once per drag gesture, on `onHorizontalDragEnd`, never per frame, exactly like the
/// screenplay editor's own equivalent.
class OcptShotListDockFractionsChangedEvent extends OcptShotListEvent {
  /// The new left (sequences) dock fraction, or null to leave it unchanged.
  final double? left;

  /// The new right (inspector) dock fraction, or null to leave it unchanged.
  final double? right;

  /// Class constructor
  const OcptShotListDockFractionsChangedEvent({this.left, this.right});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, left, right];
}

/// Requests restoring both dock fractions to their defaults ("Reset panel layout").
class OcptShotListDockLayoutResetEvent extends OcptShotListEvent {
  /// Class constructor
  const OcptShotListDockLayoutResetEvent();
}

/// Shows or hides the optional table column [column], persisting the new set.
class OcptShotListColumnToggledEvent extends OcptShotListEvent {
  /// The optional column whose visibility is toggled.
  final OcptShotListColumn column;

  /// Class constructor
  const OcptShotListColumnToggledEvent({required this.column});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, column];
}

/// Dismisses the transient write error currently shown, if any.
class OcptShotListWriteErrorDismissedEvent extends OcptShotListEvent {
  /// Class constructor
  const OcptShotListWriteErrorDismissedEvent();
}

/// Requests exporting the whole shot list to an XLSX workbook, dispatched by the table's
/// `Export XLSX` button and by the mode's `⋮` menu alike.
///
/// Both localized payloads are resolved by the widget dispatching this, since the bloc has no
/// `BuildContext` of its own: [labels] is every string the sheet itself carries (see
/// `ocptShotListXlsxLabelsOf`), [fileTypeLabel] the label the native save dialog shows for the
/// `.xlsx` type. Any pending field edit is flushed first, so a value typed seconds before the
/// export is in the workbook rather than only on screen.
class OcptShotListXlsxExportRequestedEvent extends OcptShotListEvent {
  /// Every localized string the exported sheet holds.
  final OcptShotListXlsxLabels labels;

  /// The localized label of the `.xlsx` file type, shown by the native save dialog.
  final String fileTypeLabel;

  /// Class constructor
  const OcptShotListXlsxExportRequestedEvent({
    required this.labels,
    required this.fileTypeLabel,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, labels, fileTypeLabel];
}

/// Dismisses the transient export notice currently shown, if any.
class OcptShotListIoNoticeDismissedEvent extends OcptShotListEvent {
  /// Class constructor
  const OcptShotListIoNoticeDismissedEvent();
}

/// Requests leaving the workspace and going back to the projects list.
///
/// Flushes any pending field edit before closing the current project, so navigating back right
/// after typing never loses it.
class OcptShotListBackRequestedEvent extends OcptShotListEvent {
  /// Class constructor
  const OcptShotListBackRequestedEvent();
}

/// Records the raw text just typed into [field] of shot [shotId], dispatched by the inspector on
/// every keystroke.
///
/// The typed value becomes visible immediately as a pending edit in
/// `OcptShotListState.pendingFieldEdits`, and (re)starts the field-edit autosave debounce that
/// eventually writes it, unless something flushes it sooner (selecting another shot or sequence,
/// leaving the workspace, or the mode itself leaving the widget tree).
class OcptShotListShotFieldChangedEvent extends OcptShotListEvent {
  /// The id of the shot whose field was edited.
  final String shotId;

  /// The field edited.
  final OcptShotListEditableField field;

  /// The raw text now sitting in the field, exactly as typed.
  final String rawValue;

  /// Class constructor
  const OcptShotListShotFieldChangedEvent({
    required this.shotId,
    required this.field,
    required this.rawValue,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, shotId, field, rawValue];
}

/// Fired by the field-edit debounce timer `OcptShotListShotFieldChangedEvent` (re)starts, once it
/// elapses with no further edit. Not meant to be dispatched by a widget directly.
class OcptShotListFieldEditFlushRequestedEvent extends OcptShotListEvent {
  /// Class constructor
  const OcptShotListFieldEditFlushRequestedEvent();
}

/// Sets one difficulty axis of shot [shotId] to [value] (0-5), dispatched by the inspector's
/// difficulty dots.
///
/// Written immediately: clicking a dot is a single discrete action, not typing, so it never goes
/// through the field-edit debounce.
class OcptShotListShotDifficultyChangedEvent extends OcptShotListEvent {
  /// The id of the shot whose difficulty changed.
  final String shotId;

  /// The axis changed.
  final OcptShotDifficultyAxis axis;

  /// The new value of [axis], 0-5.
  final int value;

  /// Class constructor
  const OcptShotListShotDifficultyChangedEvent({
    required this.shotId,
    required this.axis,
    required this.value,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, shotId, axis, value];
}

/// Attaches [characterName] to shot [shotId] if it isn't already attached, detaches it otherwise,
/// dispatched by the inspector's character chips.
///
/// Written immediately: toggling a chip is a single discrete action, not typing, so it never goes
/// through the field-edit debounce.
class OcptShotListShotCharacterToggledEvent extends OcptShotListEvent {
  /// The id of the shot whose character list changed.
  final String shotId;

  /// The character toggled, not necessarily normalised yet (the bloc normalises it the same way
  /// `OcptShotListService.attachCharacter` does before comparing or writing it).
  final String characterName;

  /// Class constructor
  const OcptShotListShotCharacterToggledEvent({required this.shotId, required this.characterName});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, shotId, characterName];
}

/// Requests deleting shot [shotId], dispatched once the inspector's own confirmation dialog has
/// already confirmed it. Renumbers the remaining shots of its group and clears the selection if
/// [shotId] was the selected shot (the sequence stays selected).
class OcptShotListShotDeletionRequestedEvent extends OcptShotListEvent {
  /// The id of the shot to delete.
  final String shotId;

  /// Class constructor
  const OcptShotListShotDeletionRequestedEvent({required this.shotId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, shotId];
}
/// Records a click on a word of the selected shot's scenario coverage.
///
/// One event backs the whole three-state interaction, the bloc rather than the widget deciding
/// what a click means: with no range open, a click on already-covered text removes the range
/// covering it and a click anywhere else opens a range on that word; with a range open, the click
/// closes it, wherever it lands — a range may span several blocks, and clicking the opening word
/// again records a one-word range.
class OcptShotListCoverageWordClickedEvent extends OcptShotListEvent {
  /// The id of the shot whose coverage was clicked.
  final String shotId;

  /// The scene-relative offset at which the clicked word starts.
  final int wordStartOffset;

  /// The scene-relative offset one past the clicked word's last character.
  final int wordEndOffset;

  /// Class constructor
  const OcptShotListCoverageWordClickedEvent({
    required this.shotId,
    required this.wordStartOffset,
    required this.wordEndOffset,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, shotId, wordStartOffset, wordEndOffset];
}

/// Requests removing every scenario coverage range of shot [shotId], dispatched by the inspector's
/// `Clear all` action. Written immediately, like every other coverage change.
class OcptShotListCoverageClearRequestedEvent extends OcptShotListEvent {
  /// The id of the shot whose coverage ranges are all removed.
  final String shotId;

  /// Class constructor
  const OcptShotListCoverageClearRequestedEvent({required this.shotId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, shotId];
}

/// Requests detaching [characterName] from every shot of the screenplay it is still attached to,
/// dispatched by the deleted-character banner's `Remove from every shot` button.
///
/// Written immediately, like every other character change: the banner disappears on its own once
/// the reloaded snapshot no longer has any shot carrying the name.
class OcptShotListRemovedCharacterDroppedEvent extends OcptShotListEvent {
  /// The character to detach from every shot, normalised the same way the shots' own characters
  /// are (the bloc hands it to `OcptShotListService.removeCharacterFromEveryShot`, which
  /// normalises it again anyway).
  final String characterName;

  /// Class constructor
  const OcptShotListRemovedCharacterDroppedEvent({required this.characterName});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, characterName];
}

/// Requests replacing [characterName] with [replacementName] on every shot of the screenplay it is
/// still attached to, dispatched by the deleted-character banner's replacement chips.
///
/// A shot that already carries [replacementName] simply drops [characterName] rather than gaining
/// a duplicate — see `OcptShotListService.replaceCharacterEverywhere`.
class OcptShotListRemovedCharacterReplacedEvent extends OcptShotListEvent {
  /// The character no longer speaking anywhere in the screenplay.
  final String characterName;

  /// The still-speaking character taking its place on every shot.
  final String replacementName;

  /// Class constructor
  const OcptShotListRemovedCharacterReplacedEvent({
    required this.characterName,
    required this.replacementName,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, characterName, replacementName];
}

/// Requests clearing shot [shotId]'s `needsCheck` flag and re-stamping every one of its scenario
/// coverage ranges' digests to the screenplay's current text, dispatched by the inspector's
/// `Needs checking` callout's `Mark as checked` button.
class OcptShotListShotMarkedAsCheckedEvent extends OcptShotListEvent {
  /// The id of the shot marked as checked.
  final String shotId;

  /// Class constructor
  const OcptShotListShotMarkedAsCheckedEvent({required this.shotId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, shotId];
}
