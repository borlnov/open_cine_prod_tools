// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_dart_result/act_dart_result.dart';

/// The outcome of building an XLSX workbook in memory.
///
/// The status of the [ResultWithStatus] every `Ocpt…XlsxExportService.generate` answers.
enum OcptXlsxExportStatus with MixinResultStatus {
  /// The workbook was built and encoded.
  ok(isSuccess: true, canBeRetried: false),

  /// The workbook was filled but the spreadsheet library could not encode it.
  encodingFailed(isSuccess: false, canBeRetried: false);

  /// {@macro act_dart_result.MixinResultStatus.isSuccess}
  @override
  final bool isSuccess;

  /// {@macro act_dart_result.MixinResultStatus.canBeRetried}
  @override
  final bool canBeRetried;

  /// Class constructor
  const OcptXlsxExportStatus({required this.isSuccess, required this.canBeRetried});
}
