// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// One of the shot inspector's typed fields, whose edits go through the shot list bloc's 2 s
/// autosave debounce (`OcptShotListState.pendingFieldEdits`) rather than being written
/// immediately like a difficulty dot or a character chip, which are each a single discrete action
/// rather than typing.
///
/// Only the fields the shot list itself owns are listed: a shot's `shootingDay`, `plannedTakes`
/// and status are scheduling data, edited from the shooting schedule mode rather than here.
///
/// Every case maps onto one `OcptShotListService.updateShot` argument of the same name, except
/// [estimatedDuration], which is parsed from its typed text through `ocptParseShotDuration`
/// (`lib/ui/utils/ocpt_shot_list_labels.dart`) into `estimatedDurationMs` rather than being stored
/// verbatim. It being unparseable rejects the edit (the shot list bloc leaves the stored value
/// untouched) rather than writing anything.
enum OcptShotListEditableField {
  /// Maps to `updateShot`'s `shotSize`.
  shotSize,

  /// Maps to `updateShot`'s `framing`.
  framing,

  /// Maps to `updateShot`'s `cameraMove`.
  cameraMove,

  /// Maps to `updateShot`'s `lens`.
  lens,

  /// Maps to `updateShot`'s `recordingFormat`.
  recordingFormat,

  /// Maps to `updateShot`'s `estimatedDurationMs`, parsed from `m:ss` (or a bare seconds count)
  /// through `ocptParseShotDuration`.
  estimatedDuration,

  /// Maps to `updateShot`'s `sound`.
  sound,

  /// Maps to `updateShot`'s `notes`.
  notes,

  /// Maps to `updateShot`'s `locationNotes`.
  locationNotes,
}
