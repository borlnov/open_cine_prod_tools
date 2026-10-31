// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';

/// Whether a block of this kind is **working time** — the time of the day it sits on that a
/// convocation's own band is read off (ADR 0018) — and, separately, whether that work is
/// **filming**, which is what says whether the band may be called a PAT (*prêt à tourner*) band at
/// all.
///
/// Four kinds are: [OcptShootingBlockKind.shot] and [OcptShootingBlockKind.hold] — a production
/// scheduling ahead of its own découpage still owes its cast a band — and
/// [OcptShootingBlockKind.audition] and [OcptShootingBlockKind.rehearsal], for the very same
/// reason one step earlier: a candidate seen for a part, or an actor working a sequence, is owed
/// their band exactly as a cast member is on a shooting day. Every other kind is time around the
/// work and never opens or closes a band.
///
/// Written here, on the enum, rather than in whichever reader needs it first: "does this block
/// count as work" and "is that work filming" are questions about the kind itself, and a second
/// reader deciding either again is how a printed call sheet and the convocations panel come to
/// disagree about somebody's band.
extension OcptShootingBlockKindShootingTime on OcptShootingBlockKind {
  /// Whether a block of this kind is working time. See the extension's doc comment.
  ///
  /// A `switch` with no `default`: an eleventh kind must be placed on one side or the other here
  /// rather than silently counting as time around the work.
  bool get isShootingTime => switch (this) {
    OcptShootingBlockKind.shot => true,
    OcptShootingBlockKind.hold => true,
    OcptShootingBlockKind.audition => true,
    OcptShootingBlockKind.rehearsal => true,
    OcptShootingBlockKind.preparation => false,
    OcptShootingBlockKind.hairMakeUp => false,
    OcptShootingBlockKind.meal => false,
    OcptShootingBlockKind.pause => false,
    OcptShootingBlockKind.travel => false,
    OcptShootingBlockKind.wrap => false,
  };

  /// Whether a block of this kind is **filming** — a take is made, or is going to be. True for
  /// [OcptShootingBlockKind.shot] and for [OcptShootingBlockKind.hold], which reserves the time of
  /// a sequence the shot list cannot yet describe and is filmed all the same; false for everything
  /// else, [OcptShootingBlockKind.audition] and [OcptShootingBlockKind.rehearsal] included.
  ///
  /// **This is what a band may be called `PAT` on.** *Prêt à tourner* is the hour a performer must
  /// be costumed, made up and on set, ready for a take — it presupposes a take. A day of auditions
  /// or of rehearsals has none, so a band read off those alone is a **presence** band and says so:
  /// no convention of the trade stretches the word to mean "on site", and a casting day goes out as
  /// a convocation giving the hour and the length of the passage.
  ///
  /// Deliberately **not** the same question as [isShootingTime], which asks whether the block is
  /// work at all: an audition is work — the candidate is owed a band over it — and is not filming.
  ///
  /// A `switch` with no `default`, for [isShootingTime]'s own reason.
  bool get isFilming => switch (this) {
    OcptShootingBlockKind.shot => true,
    OcptShootingBlockKind.hold => true,
    OcptShootingBlockKind.audition => false,
    OcptShootingBlockKind.rehearsal => false,
    OcptShootingBlockKind.preparation => false,
    OcptShootingBlockKind.hairMakeUp => false,
    OcptShootingBlockKind.meal => false,
    OcptShootingBlockKind.pause => false,
    OcptShootingBlockKind.travel => false,
    OcptShootingBlockKind.wrap => false,
  };
}
