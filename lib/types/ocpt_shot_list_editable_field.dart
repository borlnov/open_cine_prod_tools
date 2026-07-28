// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// One of the shot inspector's typed fields, whose edits go through the shot list bloc's 2 s
/// autosave debounce (`OcptShotListState.pendingFieldEdits`) rather than being written
/// immediately like a status change, a difficulty dot or a character chip, which are each a
/// single discrete action rather than typing.
///
/// Every case maps onto one `OcptShotListService.updateShot` argument of the same name, except
/// [estimatedDuration] and [plannedTakes], which are parsed from their typed text before being
/// written rather than stored verbatim: [estimatedDuration] through `ocptParseShotDuration`
/// (`lib/ui/utils/ocpt_shot_list_labels.dart`) into `estimatedDurationMs`, [plannedTakes] as a
/// plain non-negative integer into `plannedTakes`. Either one being unparseable rejects the edit
/// (the shot list bloc leaves the stored value untouched) rather than writing anything.
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

  /// Maps to `updateShot`'s `shootingDay`; a blank typed value is stored as null rather than an
  /// empty string.
  shootingDay,

  /// Maps to `updateShot`'s `estimatedDurationMs`, parsed from `m:ss` (or a bare seconds count)
  /// through `ocptParseShotDuration`.
  estimatedDuration,

  /// Maps to `updateShot`'s `plannedTakes`, parsed as a non-negative integer (a blank typed value
  /// is stored as null).
  plannedTakes,

  /// Maps to `updateShot`'s `sound`.
  sound,

  /// Maps to `updateShot`'s `notes`.
  notes,

  /// Maps to `updateShot`'s `locationNotes`.
  locationNotes,
}
