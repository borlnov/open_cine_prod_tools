// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// A production mode the workspace shell can host, selected through its bottom mode switcher.
///
/// Declared in the order the mode switcher displays them — the four implemented modes first,
/// the two empty ones last; see `OcptPropertiesManager.workspaceMode` for how the last one used
/// is persisted (by name, so this order is free to change without breaking a stored preference).
enum OcptWorkspaceMode {
  /// The Fountain screenplay editor, the app's founding feature.
  screenplay,

  /// The script breakdown pass (dépouillement): reading the script once and tagging what the
  /// shoot must provide.
  breakdown,

  /// The shot list (découpage technique), the second mode to get real content.
  shotList,

  /// The address book, cast, locations and physical elements catalogue.
  resources,

  /// The shooting schedule. Not implemented yet: selecting it shows an empty state.
  schedule,

  /// The budget tracker. Not implemented yet: selecting it shows an empty state.
  budget;

  /// Whether this mode has real content today, rather than the shared "coming in a future
  /// version" empty state.
  bool get isImplemented =>
      this == OcptWorkspaceMode.screenplay ||
      this == OcptWorkspaceMode.breakdown ||
      this == OcptWorkspaceMode.shotList ||
      this == OcptWorkspaceMode.resources;
}
