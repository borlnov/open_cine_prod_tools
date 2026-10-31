// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// What one cell of a *Day Out of Days* says about a role on a day.
///
/// Five values for **four codes plus their collision**, and every one of them is *derived* from the
/// schedule alone — which is the whole rule this document is built on. The two codes a standard
/// *Day Out of Days* also carries, `T` (travel) and `R` (rehearsal), are deliberately absent: no
/// field of this app says either, and the one column that could once have carried travel was the
/// presence override schema v17 dropped. Printing a `T` nobody entered would be this app inventing
/// a paid day; if a production ever needs one, it comes back as a **typed** fact with a table of
/// its own, never as a code guessed here.
enum OcptDayOutOfDaysCode {
  /// The role's own **first** convoked day of the printed range, and not also its last (`SW`).
  startWork,

  /// A day the role is convoked on, between its first and its last (`W`).
  work,

  /// The role's own **last** convoked day of the printed range, and not also its first (`WF`).
  workFinish,

  /// The role's own first **and** last convoked day, being convoked on exactly one day of the
  /// printed range (`SWF`).
  ///
  /// Not a fifth kind of information, and not the `T`/`R` this document refuses to guess: it is the
  /// one cell on which [startWork] and [workFinish] fall together, and it is derived from exactly
  /// the same reading as either of them. Printing a bare `SW` there would say the role starts and
  /// never finishes — a claim about the plan that the plan does not make.
  startWorkFinish,

  /// A day **between** the role's own first and last convoked days on which it is not convoked at
  /// all (`H`) — the days a production still owes an actor because it has not released them.
  hold,
}
