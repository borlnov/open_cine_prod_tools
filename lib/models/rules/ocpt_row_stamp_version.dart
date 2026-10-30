// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The tick a device's Lamport clock advances to for its next transaction, given the highest tick
/// [currentClock] has reached so far — or `null` when the clock has never ticked.
///
/// `version` (`docs/adr/0010-sync-ready-data-model-prerequisites.md`) is a **device-local Lamport
/// clock**, not a per-column counter: `OcptRowStampService` keeps one clock per instance (one
/// instance per transaction), seeded to the highest version the device has ever seen across the
/// whole `row_field_versions` table, and every column a transaction stamps carries this same next
/// tick. Because the clock is seeded at or above every version already on record, that tick is
/// strictly above the prior version of every column it touches, whatever that column's own history
/// — which is what lets `deviceId == me AND version > watermark` name exactly the transactions a
/// relay hasn't seen yet, in the order they happened. `null` reads as "never ticked", which starts
/// the clock at 1 rather than 0: a version of 0 would tie with nothing, since no stamp is ever
/// written below 1.
int ocptNextRowStampVersion(int? currentClock) => (currentClock ?? 0) + 1;

/// The clock tick a device must not fall behind, given the tick [knownClock] it has reached so far
/// (or `null` when it has none) and [incomingVersion], a version carried in from elsewhere that the
/// clock must not undercut either.
///
/// This is a plain Lamport-clock merge: receiving a stamp from another replica — or, for a restore,
/// folding a version payload's own carried stamps back in — must never leave the local clock behind
/// what it has just observed, or the next transaction could hand out a tick that ties with, or
/// falls under, a version already written somewhere. See `OcptRowStampService.raiseFloor`.
int ocptMergedRowStampFloor(int? knownClock, int incomingVersion) =>
    knownClock == null || knownClock < incomingVersion ? incomingVersion : knownClock;
