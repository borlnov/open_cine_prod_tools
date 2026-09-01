// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// A production mode the workspace shell can host, selected through its bottom mode switcher.
///
/// Declared in the order the mode switcher displays them — the order the work happens in (write,
/// break down, shoot-list, resource, schedule), [budget] last since it is the one that reads every
/// other mode's own figures rather than the one anybody starts from. Not persisted: opening a
/// project always starts on [OcptWorkspaceMode.screenplay] (`OcptWorkspaceBloc._onLoadRequested`),
/// and switching between a project's own episodes leaves whichever mode is active untouched.
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

  /// The shooting schedule: planning the shoot day by day.
  schedule,

  /// The budget tracker: the production's quote, cash journal, financing and revenue sharing.
  budget;

  /// Whether this mode has real content today, rather than the shared "coming in a future
  /// version" empty state.
  ///
  /// Every value answers true today; the getter is kept as an explicit list rather than collapsed
  /// to a bare `true` so a mode added ahead of its own content (the way [budget] itself once sat
  /// here) has a single, obvious place to be left out of again.
  bool get isImplemented =>
      this == OcptWorkspaceMode.screenplay ||
      this == OcptWorkspaceMode.breakdown ||
      this == OcptWorkspaceMode.shotList ||
      this == OcptWorkspaceMode.resources ||
      this == OcptWorkspaceMode.schedule ||
      this == OcptWorkspaceMode.budget;
}
