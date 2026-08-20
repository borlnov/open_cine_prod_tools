// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// Where one person stands in the casting of one part: the status of a `role_candidates` row.
///
/// The five values are a casting director's own vocabulary, not a workflow the app enforces: a
/// candidate may go from [seen] straight to [retained], come back from [declined] to [shortlisted]
/// because somebody else fell through, and nothing here refuses any of it. The **one** rule the app
/// does hold is about [retained], and it lives in `OcptRoleCandidatesService` rather than here: a
/// role has at most one retained candidate at a time, and that row is what writes `roles.personId`.
enum OcptRoleCandidateStatus {
  /// This person was seen for the part, and nothing more has been said yet.
  seen,

  /// This person is kept in the running: a short list of the candidates still being thought about.
  shortlisted,

  /// This person is the one cast in the part. At most one candidate of a role holds this status,
  /// and holding it is exactly what wrote `roles.personId` — see `OcptRoleCandidatesService`.
  retained,

  /// This person turned the part down.
  declined,

  /// This person cannot take the part: another shoot, a date, a reason of their own.
  unavailable,
}
