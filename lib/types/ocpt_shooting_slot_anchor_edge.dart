// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// Which edge of a `shooting_slots` row is the one pinned down — the single hour that slot is
/// thought about, everything else being chained off it.
///
/// A slot used to be thought about forwards and only forwards: it owned a typed `startMinute` and
/// its blocks ran on from there. A production books a studio *until* 22:00, or plans backwards from
/// a sunset, just as often; saying either meant doing the subtraction by hand and redoing it every
/// time a block moved. The edge is what the app now asks for instead — see
/// `lib/utils/ocpt_shooting_day_timeline.dart` (ADR 0015, amended a second time).
///
/// Whichever edge is pinned, the chain itself still runs **forwards**: an [end]-anchored slot
/// starts at `end − Σ durations` and is then chained exactly as a [start]-anchored one is, which is
/// what makes adding a block to it pull its start earlier and leave its end where it was.
enum OcptShootingSlotAnchorEdge {
  /// The slot's **start** is the pinned edge: its first block begins at the anchored hour, and its
  /// end is wherever the chain lands.
  start,

  /// The slot's **end** is the pinned edge: its chain is laid out so its last block finishes at the
  /// anchored hour, and its start is wherever that puts it.
  end,
}
