// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/utils/ocpt_row_stamp_diff.dart';
import 'package:open_cine_prod_tools/utils/ocpt_row_stamp_version.dart';

/// Resolves the device id a domain service's own writes stamp with, once per write rather than
/// baked in at construction: `OcptPropertiesManager.loadOrCreateDeviceId` is the only
/// implementation the app ships, injected into a service exactly the way it already takes every
/// other collaborator — a constructor parameter, defaulting to nothing so a caller can never
/// forget to wire it — and a test hands in a fixed id instead.
typedef OcptDeviceIdGetter = Future<String> Function();

/// Writes a row into a synchronised table and stamps exactly the columns it actually changed, from
/// inside an already-open transaction.
///
/// This is the row-stamping machinery of `docs/adr/0010-sync-ready-data-model-prerequisites.md`,
/// factored out of `OcptProjectVersionsService.restoreVersion` — its restore was the first writer
/// of a `row_field_versions` stamp, and the changeset engine of
/// `docs/plans/collaboration-and-sync.md` (M3) is what will make an ordinary domain-service write
/// the second: both need the very same three things, "what changed", "what version does that
/// change carry" and "batch the stamps rather than writing one row at a time", so this is where
/// they live once. Everything in [ocptChangedColumnNames] and [ocptNextRowStampVersion] — the pure
/// halves of the same rule — is deliberately kept out of this class, in `lib/utils/`, so they can
/// be tested with no database at all.
///
/// `version` is a **device-local Lamport clock**, one per instance rather than one per stamped
/// column: [seed] reads the highest version this device has ever recorded anywhere in
/// `row_field_versions`, and every column any [writeAndStamp] call touches during this instance's
/// lifetime is stamped with that same next tick, computed once and reused — never a fresh bump per
/// column. Because the clock starts at or above every version already on record, that one tick is
/// still strictly above the prior version of every column it lands on, so the per-column ordering a
/// merge relies on is unaffected; what changes is that a device's own stamps now strictly increase
/// transaction over transaction, which is exactly what lets the changeset engine's outbox ask
/// "`deviceId == me AND version > relayWatermark`" and get back every local edit a relay hasn't
/// seen yet, in the order it happened.
///
/// One instance covers one transaction: [seed] it once, hand it to every table write that
/// transaction makes — [writeAndStamp] for a single row, or a caller's own loop that calls
/// [writeAndStamp] once per row — and [flush] it exactly once, at the end, after every write has
/// been recorded. A table no merge ever needs to see (`scenes`, derived from the screenplay text
/// and never synchronised) simply never receives a stamp: every stamping call in this class takes
/// the accumulator itself as an optional parameter or method, and the caller passes `null` to skip
/// it, exactly as [OcptRowFieldVersionRow]'s own class doc names `scenes` as the one exception.
class OcptRowStampService {
  /// The device id every stamp this instance writes carries: this replica's own.
  final String deviceId;

  /// The highest version tick this device has reached so far: what [seed] read off the whole
  /// project, raised further by any [raiseFloor] call, and by nothing else — a stamp this instance
  /// hands out reads it but never advances it further, since every one of them shares the single
  /// tick [_version] already reserved.
  int _clock;

  /// The one tick every stamp this instance writes shares, computed the first time [_stamp] is
  /// asked for one and memoized from then on: this is what makes every column touched by this
  /// transaction, however many [writeAndStamp] calls that takes, carry the same version.
  int? _version;

  /// The stamps written so far, waiting for [flush].
  final _pending = <OcptRowFieldVersionsTableCompanion>[];

  OcptRowStampService._({required this.deviceId, required int clock}) : _clock = clock;

  /// Seeds a new instance from the highest version [database] currently holds anywhere in
  /// `row_field_versions`, to be written by [deviceId].
  ///
  /// This alone is everything an ordinary domain-service write needs: the clock starts at or above
  /// every version the device has ever seen, local or merged-in. [raiseFloor] is the one extra step
  /// a restore owes on top, to fold a version payload's own carried stamps into that same clock
  /// before anything is written.
  static Future<OcptRowStampService> seed({
    required OcptProjectDatabase database,
    required String deviceId,
  }) async {
    final table = database.ocptRowFieldVersionsTable;
    final maxVersion = table.version.max();

    final row = await (database.selectOnly(table)..addColumns([maxVersion])).getSingleOrNull();

    return OcptRowStampService._(deviceId: deviceId, clock: row?.read(maxVersion) ?? 0);
  }

  /// Raises this device's clock to at least the version each of [floorStamps] carries, through
  /// [ocptMergedRowStampFloor].
  ///
  /// This is what a restore uses to fold the version's own stamps in as a floor, never as a value
  /// written verbatim: the version being restored may itself carry a stamp above what the working
  /// copy holds — a device that pushed a change, then had that very version restored to it — and
  /// [writeAndStamp] must still leave every column it touches strictly above that stamp, not merely
  /// above the working copy's own. See `OcptProjectVersionsService._applyPayload`. Calling this
  /// after [_version] has already been reserved would leave stamps already handed out behind the
  /// raised clock, so a caller folds every floor in before its first [writeAndStamp] call — exactly
  /// how `_applyPayload` uses it, right after [seed] and before any restore write.
  void raiseFloor(Iterable<OcptRowFieldVersionRow> floorStamps) {
    for (final stamp in floorStamps) {
      _clock = ocptMergedRowStampFloor(_clock, stamp.version);
    }
  }

  /// Writes [next] into [table] of [database], in place of [current] — or as a fresh row when
  /// [current] is `null` — and, when [stamps] is given, stamps exactly the columns that changed
  /// under [rowId].
  ///
  /// [current] being `null` means every column [next] carries is new, so every one of them is
  /// stamped; otherwise only the columns [ocptChangedColumnNames] finds different are written and
  /// stamped, and a call whose [next] would change nothing writes and stamps nothing at all — which
  /// is also how a tombstone-in-place is expressed: a caller passes the leftover row as [current]
  /// and its own tombstoned copy as [next], and only the tombstone column (or whichever few columns
  /// that copy actually flips) ends up written and stamped.
  ///
  /// [stamps] is `null` for a table no merge ever needs to see (`scenes`): the row is still written,
  /// simply with nothing recorded about it in `row_field_versions`.
  static Future<void> writeAndStamp<D extends DataClass>({
    required OcptProjectDatabase database,
    required TableInfo<Table, D> table,
    required String rowId,
    required D? current,
    required D next,
    required OcptRowStampService? stamps,
  }) async {
    if (current == null) {
      await database.into(table).insert(_fullyPresentCompanion(next));
      stamps?._stamp(table: table, rowId: rowId, columnNames: next.toJson().keys);
      return;
    }

    final changedColumnNames = ocptChangedColumnNames(from: current.toJson(), to: next.toJson());
    if (changedColumnNames.isEmpty) {
      return;
    }

    await database.into(table).insertOnConflictUpdate(_fullyPresentCompanion(next));
    stamps?._stamp(table: table, rowId: rowId, columnNames: changedColumnNames);
  }

  /// Stamps [columnNames] of the row [rowId] of [table] as written, now, by [deviceId] — every one
  /// of them carrying [_version], this instance's single shared tick.
  void _stamp({
    required TableInfo<Table, DataClass> table,
    required String rowId,
    required Iterable<String> columnNames,
  }) {
    final version = _version ??= ocptNextRowStampVersion(_clock);

    for (final columnName in columnNames) {
      _pending.add(
        OcptRowFieldVersionsTableCompanion.insert(
          targetTableName: table.actualTableName,
          rowId: rowId,
          columnName: columnName,
          version: version,
          deviceId: deviceId,
        ),
      );
    }
  }

  /// Writes every stamp handed out since this instance was seeded into [database].
  Future<void> flush(OcptProjectDatabase database) async {
    if (_pending.isEmpty) {
      return;
    }

    await database.batch(
      (batch) => batch.insertAllOnConflictUpdate(database.ocptRowFieldVersionsTable, _pending),
    );
  }

  /// [row] seen as an `UpdateCompanion` with every column marked present — even the null ones —
  /// which every generated row class provides as `toCompanion(false)` but which, like the
  /// `Insertable` cast it replaces, [DataClass] itself doesn't declare, so calling it generically
  /// still needs a dynamic invocation.
  ///
  /// This is what [writeAndStamp] writes through rather than [row] itself: `insertOnConflictUpdate`
  /// reads a plain `DataClass`'s null columns as *absent*, not as `null` — its own doc comment
  /// says as much, "columns from the old row that are not present on entity are unchanged" — so a
  /// column [row] means to clear would silently keep whatever the row being replaced already held.
  /// A companion built with `toCompanion(false)` has no such ambiguity: every column is `Value(x)`,
  /// `Value(null)` included, never `Value.absent()`. The same holds for a fresh insert, so a column
  /// [row] leaves null is written as `NULL`, never left for a column default to fill in behind its
  /// back.
  static UpdateCompanion<D> _fullyPresentCompanion<D extends DataClass>(D row) =>
      (row as dynamic).toCompanion(false) as UpdateCompanion<D>;
}
