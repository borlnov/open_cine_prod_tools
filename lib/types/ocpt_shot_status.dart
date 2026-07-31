// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The shooting status of a shot in a shot list.
///
/// Every row in `shots` carries one of these, so the shot table and the left dock's sequence
/// summaries can show at a glance how much of a sequence is left to shoot.
enum OcptShotStatus {
  /// The shot has not been filmed yet.
  toShoot,

  /// The shot has been filmed and accepted.
  shot,

  /// The shot was filmed but needs to be shot again.
  retake,
}
