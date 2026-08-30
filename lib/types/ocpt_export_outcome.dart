// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';

/// What a single-file export produced through `OcptExportManager`'s write funnel
/// (`_writeToPickedLocation`).
///
/// Every export method used to return the written path directly, null meaning a cancelled dialog
/// or a failed write. On mobile there is no "save as" dialog to pick a path from at all —
/// `file_selector`'s `getSaveLocation` has no Android or iOS implementation — so the bytes are
/// instead handed to the OS share sheet, which is [OcptExportShared] rather than
/// [OcptExportSaved]. A null return still means "cancelled or failed"; once a result comes back,
/// it is always one of these two.
sealed class OcptExportOutcome {
  /// Class constructor
  const OcptExportOutcome();

  /// The path the file was written to, only non-null for [OcptExportSaved].
  String? get savedPath => switch (this) {
    OcptExportSaved(:final path) => path,
    OcptExportShared() => null,
  };

  /// Whether the bytes were handed to the OS share sheet rather than a picked save location.
  bool get wasShared => this is OcptExportShared;
}

/// The bytes were written to [path], picked through the native "save as" dialog.
final class OcptExportSaved extends OcptExportOutcome with Equatable {
  /// The path the file was written to.
  final String path;

  /// Class constructor
  const OcptExportSaved(this.path);

  /// Object properties
  @override
  List<Object?> get props => [path];
}

/// The bytes were handed to the OS share sheet instead of a picked save location.
final class OcptExportShared extends OcptExportOutcome with Equatable {
  /// Class constructor
  const OcptExportShared();

  /// Object properties
  @override
  List<Object?> get props => const [];
}
