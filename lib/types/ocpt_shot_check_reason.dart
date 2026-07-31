// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// Why a shot's `needsCheck` flag was set: a stable, language-neutral reason code rather than a
/// ready-to-display string.
///
/// Persisting a localised string into `shots.checkReason` would carry whichever language the user
/// who last saved the project happened to be running into every other user's session, and the
/// services that set this flag have no `Tr`/`BuildContext` to localise with in the first place. A
/// reason code is localised at render time instead, by the panel that shows it.
enum OcptShotCheckReason {
  /// The screenplay text under one of the shot's coverage ranges changed since it was recorded.
  coveredTextChanged,

  /// A coverage range no longer fit inside its scene after the scene's bounds moved, and was
  /// clamped back inside it.
  coverageOutOfBounds,

  /// The scene this shot belonged to was removed from the screenplay: the shot is now orphaned.
  sceneDeleted,
}
