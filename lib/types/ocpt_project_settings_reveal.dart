// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The section `OcptProjectSettingsPage` scrolls to the moment it opens, handed to it as the
/// project settings route's `extra`.
///
/// A caller sending the user there *for a reason* names that reason here, exactly as a mode sending
/// the user to another mode attaches an `OcptWorkspaceRevealRequest`: the settings page stacks four
/// cards, and landing at the top of it after clicking a button that promised one of them says less
/// than nothing. Opening the page plainly (the toolbar's own settings action, the episode
/// selector's `Manage episodes…`) passes null and scrolls nowhere.
enum OcptProjectSettingsReveal {
  /// The `Episodes` card, what the screenplay mode's `Add an episode…` button asks for.
  episodes,
}
