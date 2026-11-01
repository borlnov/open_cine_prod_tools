// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/types/ocpt_shot_difficulty_axis.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_editable_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/events/shot_list_base_event.dart';

/// The events of `OcptShotListInspectorBloc`, about shot editing, scenario coverage and cast.
sealed class OcptShotListInspectorEvent extends OcptShotListEvent {
  /// Class constructor
  const OcptShotListInspectorEvent();
}

/// Records the raw text just typed into [field] of shot [shotId], dispatched by the inspector on
/// every keystroke.
///
/// The typed value becomes visible immediately as a pending edit in
/// `OcptShotListInspectorState.pendingFieldEdits`, and (re)starts the field-edit autosave debounce
/// that eventually writes it, unless something flushes it sooner (selecting another shot or
/// sequence, leaving the workspace, or the mode itself leaving the widget tree).
class OcptShotListShotFieldChangedEvent extends OcptShotListInspectorEvent {
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

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, shotId, field, rawValue];
}

/// Sets one difficulty axis of shot [shotId] to [value] (0-5), dispatched by the inspector's
/// difficulty dots.
///
/// Written immediately: clicking a dot is a single discrete action, not typing, so it never goes
/// through the field-edit debounce.
class OcptShotListShotDifficultyChangedEvent extends OcptShotListInspectorEvent {
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

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, shotId, axis, value];
}

/// Attaches role [roleId] to shot [shotId] if it isn't already attached, detaches it otherwise,
/// dispatched by the inspector's character chips.
///
/// Written immediately: toggling a chip is a single discrete action, not typing, so it never goes
/// through the field-edit debounce.
class OcptShotListShotCharacterToggledEvent extends OcptShotListInspectorEvent {
  /// The id of the shot whose character list changed.
  final String shotId;

  /// The id of the role toggled.
  final String roleId;

  /// Class constructor
  const OcptShotListShotCharacterToggledEvent({required this.shotId, required this.roleId});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, shotId, roleId];
}

/// Requests attaching a character typed into the inspector's `＋ Add` field to shot [shotId],
/// dispatched once the field is submitted.
///
/// [characterName] resolves to a live role of that name, or **creates** a hand-added silent role
/// linked to the shot's own episode (decision 1), through
/// `OcptShotListService.resolveOrCreateRoleId` — the resolution the roleId-native
/// `OcptShotListService.attachCharacter` no longer performs on its own. Written immediately, like
/// every other character change.
class OcptShotListCharacterAddRequestedEvent extends OcptShotListInspectorEvent {
  /// The id of the shot the character is added to.
  final String shotId;

  /// The character's typed name, not necessarily normalised yet.
  final String characterName;

  /// Class constructor
  const OcptShotListCharacterAddRequestedEvent({required this.shotId, required this.characterName});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, shotId, characterName];
}

/// Records a click on a word of the selected shot's scenario coverage.
///
/// One event backs the whole three-state interaction, the bloc rather than the widget deciding
/// what a click means: with no range open, a click on already-covered text removes the range
/// covering it and a click anywhere else opens a range on that word; with a range open, the click
/// closes it, wherever it lands — a range may span several blocks, and clicking the opening word
/// again records a one-word range.
class OcptShotListCoverageWordClickedEvent extends OcptShotListInspectorEvent {
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

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, shotId, wordStartOffset, wordEndOffset];
}

/// Requests removing every scenario coverage range of shot [shotId], dispatched by the inspector's
/// `Clear all` action. Written immediately, like every other coverage change.
class OcptShotListCoverageClearRequestedEvent extends OcptShotListInspectorEvent {
  /// The id of the shot whose coverage ranges are all removed.
  final String shotId;

  /// Class constructor
  const OcptShotListCoverageClearRequestedEvent({required this.shotId});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, shotId];
}

/// Clears the coverage anchor currently pending, dispatched by the coverage dialog's `Escape` (only
/// while an anchor is pending, so `Escape` still closes the dialog otherwise), a click on empty
/// space in the dialog's script area, or the dialog closing through its × or `Close` button — the
/// user changed their mind about the passage, not just about where it should end.
///
/// Only `OcptShotListInspectorState.pendingCoverageAnchor` is cleared: the shot's own coverage
/// ranges are untouched, exactly as the breakdown mode's own equivalent,
/// `OcptBreakdownTagRangeCancelledEvent`, leaves its target's tags untouched.
class OcptShotListCoverageAnchorCancelledEvent extends OcptShotListInspectorEvent {
  /// Class constructor
  const OcptShotListCoverageAnchorCancelledEvent();
}

/// Requests deleting role [roleId] for good, dispatched once the shared role alert banner's
/// orphaned variant has already been confirmed through `OcptConfirmDialog`, by the mode.
///
/// Written immediately through `OcptRoleIndexService.deleteRole`, whose cascade tombstones the
/// role's `shot_characters` and `breakdown_tags` rows alongside it: the banner disappears on its
/// own once the reloaded cast no longer holds the role at all.
class OcptShotListOrphanedRoleDeleteRequestedEvent extends OcptShotListInspectorEvent {
  /// The id of the orphaned role to delete.
  final String roleId;

  /// Class constructor
  const OcptShotListOrphanedRoleDeleteRequestedEvent({required this.roleId});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, roleId];
}

/// Requests keeping orphaned role [roleId] as a hand-added silent role, dispatched by the shared
/// role alert banner's orphaned variant's `Keep as silent` action — not destructive, so reached
/// with no confirmation dialog, exactly as the resources mode's own equivalent isn't.
class OcptShotListOrphanedRoleKeptEvent extends OcptShotListInspectorEvent {
  /// The id of the orphaned role to keep.
  final String roleId;

  /// Class constructor
  const OcptShotListOrphanedRoleKeptEvent({required this.roleId});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, roleId];
}

/// Requests merging role [sourceRoleId] into role [targetRoleId], dispatched once the shared role
/// alert banner's merge affordance — either variant — has already been confirmed through
/// `OcptConfirmDialog`, by the mode.
///
/// Written immediately through `OcptRoleIndexService.mergeRole`: the banner disappears on its own
/// once the reloaded cast no longer holds [sourceRoleId], or is no longer orphaned/collided.
class OcptShotListRoleMergeRequestedEvent extends OcptShotListInspectorEvent {
  /// The id of the role merged away.
  final String sourceRoleId;

  /// The id of the role [sourceRoleId] is merged into.
  final String targetRoleId;

  /// Class constructor
  const OcptShotListRoleMergeRequestedEvent({
    required this.sourceRoleId,
    required this.targetRoleId,
  });

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, sourceRoleId, targetRoleId];
}

/// Requests clearing shot [shotId]'s `needsCheck` flag and re-stamping every one of its scenario
/// coverage ranges' digests to the screenplay's current text, dispatched by the inspector's
/// `Needs checking` callout's `Mark as checked` button.
class OcptShotListShotMarkedAsCheckedEvent extends OcptShotListInspectorEvent {
  /// The id of the shot marked as checked.
  final String shotId;

  /// Class constructor
  const OcptShotListShotMarkedAsCheckedEvent({required this.shotId});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, shotId];
}

/// Requests writing every typed shot field still sitting in the inspector's autosave debounce,
/// dispatched by the bloc itself once the delay since the last keystroke has elapsed. Not meant to
/// be dispatched by a widget directly.
class OcptShotListInspectorFieldEditFlushRequestedEvent extends OcptShotListInspectorEvent {
  /// Class constructor
  const OcptShotListInspectorFieldEditFlushRequestedEvent();
}

/// Dismisses the transient write error the inspector currently shows, if any.
class OcptShotListInspectorWriteErrorDismissedEvent extends OcptShotListInspectorEvent {
  /// Class constructor
  const OcptShotListInspectorWriteErrorDismissedEvent();
}
