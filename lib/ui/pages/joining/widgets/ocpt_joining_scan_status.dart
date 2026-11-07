// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The status `OcptJoiningScanFrame`'s own border colour reflects, driven by the Rejoindre page
/// off `OcptJoiningBloc`'s state and whether the last submission it reacted to came from the
/// scanner tab at all — a manual-entry failure must not paint the camera frame red.
enum OcptJoiningScanStatus {
  /// No scan has affected the frame yet, or its outcome isn't tied to it — the theme's own
  /// outline colour.
  idle,

  /// The last scanned code did not lead to a successful join — `theme.colorScheme.error`.
  error,

  /// The last scanned code was decoded and handed to the bloc — the same green
  /// `OcptSpecificColors.shotStatusShot` already marks a shot as done with, matching the app's own
  /// "no green/amber Material role, use the shared semantic colour" reasoning (see that class's
  /// own doc comment).
  success,
}
