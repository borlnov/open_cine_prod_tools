// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// Where one person stands in the casting of one part: the status of a `role_candidates` row.
///
/// The eight values are a casting director's own vocabulary, not a workflow the app enforces: a
/// candidate may go from [spotted] straight to [retained], come back from [declined] to
/// [shortlisted] because somebody else fell through, and nothing here refuses any of it. The
/// declaration order is the **chronology** they usually run in, and the `⋮` menu offers them in it
/// — reading a list in the order a casting normally happens is what makes it scannable — but that
/// order is a reading convenience and nothing more.
///
/// The **one** rule the app does hold is about [retained], and it lives in
/// `OcptRoleCandidatesService` rather than here: a role has at most one retained candidate at a
/// time, and that row is what writes `roles.personId`.
///
/// The three "no" values are three **different facts**, deliberately not folded into one: [declined]
/// and [unavailable] are the person's own answer, [notRetained] is the production's. A casting
/// director re-reading a part months later needs to know which of the three it was.
enum OcptRoleCandidateStatus {
  /// This person's application has arrived, or somebody contacted them. Nothing has been decided —
  /// not even whether to meet them.
  spotted,

  /// This person's application has been read and they are going to be met at a casting session.
  toMeet,

  /// This person was seen for the part, and nothing more has been said yet.
  seen,

  /// This person is kept in the running: a short list of the candidates still being thought about,
  /// drawn up **after** seeing them — [toMeet] is the other, earlier list.
  shortlisted,

  /// This person is the one cast in the part. At most one candidate of a role holds this status,
  /// and holding it is exactly what wrote `roles.personId` — see `OcptRoleCandidatesService`.
  retained,

  /// The production has decided not to take this person for the part. The mirror of [retained], and
  /// **not** the same fact as [declined]: this one is our answer, that one is theirs.
  notRetained,

  /// This person turned the part down.
  declined,

  /// This person cannot take the part: another shoot, a date, a reason of their own.
  unavailable,
}

/// Whether a candidacy in this status is still a **lead** for the part — somebody the production
/// could yet end up casting.
///
/// The three closed statuses are the three ways a candidacy ends without becoming the casting:
/// [OcptRoleCandidateStatus.notRetained], [OcptRoleCandidateStatus.declined] and
/// [OcptRoleCandidateStatus.unavailable]. [OcptRoleCandidateStatus.retained] is **open**: it is not
/// a dead end, it is the answer — a role holding one reads as cast long before this getter is
/// consulted (`OcptRoleCastingProgress`).
///
/// Written here, on the enum, rather than in whichever reader needs it first: "is this person still
/// a possibility" is a question about the status itself, and a second reader deciding it again is
/// how two counts of the same casting come to disagree.
extension OcptRoleCandidateStatusLead on OcptRoleCandidateStatus {
  /// Whether this status leaves the candidacy in the running. See the extension's doc comment.
  ///
  /// A `switch` with no `default`: a ninth status must be placed on one side or the other here
  /// rather than silently counting as a lead.
  bool get isStillALead => switch (this) {
    OcptRoleCandidateStatus.spotted => true,
    OcptRoleCandidateStatus.toMeet => true,
    OcptRoleCandidateStatus.seen => true,
    OcptRoleCandidateStatus.shortlisted => true,
    OcptRoleCandidateStatus.retained => true,
    OcptRoleCandidateStatus.notRetained => false,
    OcptRoleCandidateStatus.declined => false,
    OcptRoleCandidateStatus.unavailable => false,
  };
}
