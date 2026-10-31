// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';

/// Converts a [OcptSnapshotReason] to and from the text stored in the
/// `screenplay_snapshots.reason` column.
class OcptSnapshotReasonConverter extends TypeConverter<OcptSnapshotReason, String> {
  /// Class constructor
  const OcptSnapshotReasonConverter();

  /// {@macro drift.TypeConverter.fromSql}
  @override
  OcptSnapshotReason fromSql(String fromDb) => OcptSnapshotReason.values.byName(fromDb);

  /// {@macro drift.TypeConverter.toSql}
  @override
  String toSql(OcptSnapshotReason value) => value.name;
}
