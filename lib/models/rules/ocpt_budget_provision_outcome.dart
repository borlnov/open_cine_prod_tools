// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// What provisioning would do to one quote line.
enum OcptBudgetProvisionOutcome {
  /// No line carries this nature's key on the target account: one is created.
  created,

  /// A line carries it, still holds exactly what the provisioning last wrote, and that no longer
  /// matches the current figure: it is updated.
  updated,

  /// A line carries it and already holds the current figure: nothing is written.
  unchanged,

  /// A line carries it but no longer holds what the provisioning last wrote — somebody edited it by
  /// hand. **It is reported and left exactly as it is**, never overwritten.
  skippedEdited,
}
