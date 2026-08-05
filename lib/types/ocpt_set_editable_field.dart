// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// One of the typed, free-text fields of a set ("décor") on the location sheet, whose edits go
/// through the resources bloc's 2 s autosave debounce
/// (`OcptResourcesState.pendingSetFieldEdits`) rather than being written immediately.
///
/// A set has its own enum rather than sharing `OcptLocationField`'s because its rows are keyed by
/// the set's id, not the location's: several sets of one location are on screen at once, each
/// editable, and a single map keyed by the location would make two of them the same pending edit.
///
/// Every case maps onto one `OcptLocationsService.updateSet` argument of the same name. Which
/// scenes are shot in a set is not one of them: picking a scene is a menu pick, written
/// immediately. Neither is its code, which is the app's own — `OcptLocationsService.createSet`
/// mints it and nothing rewrites it, so `OcptResourcesCodeReadOut` reads it out instead.
enum OcptSetField {
  /// Maps to `updateSet`'s `name`.
  name,

  /// Maps to `updateSet`'s `notes`.
  notes,
}
