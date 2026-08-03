// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// Where a location's filming permit ("autorisation de tournage") stands: whether the production
/// may legally shoot there yet.
enum OcptPermitStatus {
  /// No permit is needed for this location (e.g. private property with the owner's consent already
  /// captured elsewhere).
  notNeeded,

  /// A permit is needed and has not been requested yet.
  toRequest,

  /// The request has been sent and is awaiting an answer.
  requested,

  /// The permit was granted: the location may be shot at.
  granted,

  /// The permit was refused: the location cannot be used as planned.
  refused,
}
