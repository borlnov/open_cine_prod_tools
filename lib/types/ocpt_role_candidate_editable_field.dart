// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// One of the candidates card's typed, free-text fields, whose edits go through the resources
/// bloc's 2 s autosave debounce (`OcptResourcesState.pendingCandidateFieldEdits`) rather than being
/// written immediately — mirroring `OcptRoleField`'s own split between typed and discrete fields.
///
/// The only case maps onto `OcptRoleCandidatesService.updateCandidate`'s `notes` argument. The
/// candidacy's other fields — its status and its audition date — are each a single discrete pick
/// (a menu entry, a date) rather than typing, so they are written immediately by their own bloc
/// events instead, exactly as a role's cast member and kind are.
enum OcptRoleCandidateField {
  /// Maps to `updateCandidate`'s `notes`.
  notes,
}
