// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// A tab of the resources mode's left dock, declared in the mock-up's own order: people, roles,
/// locations, elements.
enum OcptResourcesTab {
  /// The address book: one row per human involved in the production.
  people,

  /// The cast: the screenplay's speaking characters, reconciled against [people].
  roles,

  /// Every location and the sets inside it.
  locations,

  /// The physical elements catalogue (props, costumes, vehicles, equipment…).
  elements;

  /// Whether this tab shows real content today, rather than the shared "coming in a future
  /// version" placeholder line.
  ///
  /// [people] and [roles] ship this milestone; [locations] and [elements] follow in later
  /// milestones of the same step.
  bool get hasContent => this == OcptResourcesTab.people || this == OcptResourcesTab.roles;
}
