// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';

/// What a single-file export produced through `OcptExportManager`'s write funnel
/// (`OcptExportWriteService.writeToPickedLocation`).
///
/// Every export method used to return the written path directly, null meaning a cancelled dialog
/// or a failed write. On mobile there is no "save as" dialog to pick a path from at all —
/// `file_selector`'s `getSaveLocation` has no Android or iOS implementation — so the bytes are
/// instead handed to the OS share sheet, which is [OcptExportShared] rather than
/// [OcptExportSaved]. A null return still means "cancelled or failed to write"; a workbook that
/// could not even be built comes back as [OcptExportFailed], which the caller words as a failed
/// export rather than a cancellation.
sealed class OcptExportOutcome {
  /// Get the path the file was written to, only non-null for [OcptExportSaved].
  String? get savedPath => switch (this) {
    OcptExportSaved(:final path) => path,
    OcptExportShared() => null,
    OcptExportFailed() => null,
  };

  /// Tell whether the bytes were handed to the OS share sheet rather than a picked save location.
  bool get wasShared => this is OcptExportShared;

  /// Class constructor
  const OcptExportOutcome();
}

/// The bytes were written to [path], picked through the native "save as" dialog.
final class OcptExportSaved extends OcptExportOutcome with Equatable {
  /// The path the file was written to.
  final String path;

  /// Class constructor
  const OcptExportSaved(this.path);

  /// List the fields that decide equality.
  @override
  List<Object?> get props => [path];
}

/// The bytes were handed to the OS share sheet instead of a picked save location.
final class OcptExportShared extends OcptExportOutcome with Equatable {
  /// Class constructor
  const OcptExportShared();

  /// List the fields that decide equality.
  @override
  List<Object?> get props => const [];
}

/// The export could not be built, so nothing was offered to the user: the XLSX exports answer it
/// when the workbook cannot be encoded.
final class OcptExportFailed extends OcptExportOutcome with Equatable {
  /// Class constructor
  const OcptExportFailed();

  /// List the fields that decide equality.
  @override
  List<Object?> get props => const [];
}
