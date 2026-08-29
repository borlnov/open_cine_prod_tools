// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The version a fresh write of a `row_field_versions` column carries, given the highest version
/// [currentVersion] already known for that `(table, row, column)` — or `null` when none is.
///
/// A stamp says, per column, *whose* value wins a merge and *when* it was written, so a write has
/// to leave every column it changed carrying a version strictly above the one that column already
/// held: anything less and the next merge would treat the new value as older than an edit it was
/// meant to supersede — undoing it, minutes later, from a machine nobody touched. `null` reads as
/// "never stamped", which starts the column at version 1 rather than 0: a version of 0 would tie
/// with nothing, since no stamp is ever written below 1.
int ocptNextRowStampVersion(int? currentVersion) => (currentVersion ?? 0) + 1;

/// The floor a `(table, row, column)`'s version stamp must not fall below, given the version
/// [knownVersion] a writer already has on record for it (or `null` when it has none) and
/// [incomingVersion], a version carried in from elsewhere that the writer must not undercut either.
///
/// This is what lets a version's own stamps act as a **floor** rather than as the values written:
/// a restore raises the floor of every column its payload names to at least what that payload
/// carried, so a column whose payload stamp is somehow above the working copy's still ends up
/// strictly above both once [ocptNextRowStampVersion] bumps it — see
/// `OcptRowStampService.raiseFloor`. What this never does is read as a value to write as it
/// stands — that would undo the very ordering this schema depends on.
int ocptMergedRowStampFloor(int? knownVersion, int incomingVersion) =>
    knownVersion == null || knownVersion < incomingVersion ? incomingVersion : knownVersion;
