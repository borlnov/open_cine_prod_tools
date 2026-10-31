// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/models/ocpt_diagnostics_entry.dart';

/// How severe an [OcptDiagnosticsEntry] is — tints the line `OcptDiagnosticsLogList` draws it on.
enum OcptDiagnosticsLevel {
  /// An ordinary, expected event.
  info,

  /// Something worth a second look, but not a failure on its own.
  warning,

  /// A failure.
  error,
}
