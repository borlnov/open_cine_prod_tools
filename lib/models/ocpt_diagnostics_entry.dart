// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/types/ocpt_diagnostics_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_diagnostics_level.dart';

/// One line of `OcptDiagnosticsManager`'s own ring buffer: a device-local diagnostics log entry
/// recording what the relay server (when hosting) and the sync client are doing on this device —
/// the in-app "Journaux (diagnostic)" section's own unit of content.
///
/// [message] is always short, ids/counts/states only, never a payload, a token or a secret — see
/// `OcptDiagnosticsManager`'s own doc comment for why.
class OcptDiagnosticsEntry extends Equatable {
  /// When this entry was recorded.
  final DateTime time;

  /// Which subsystem recorded this entry.
  final OcptDiagnosticsCategory category;

  /// How severe this entry is.
  final OcptDiagnosticsLevel level;

  /// This entry's own short, human-readable text.
  final String message;

  /// Class constructor
  const OcptDiagnosticsEntry({
    required this.time,
    required this.category,
    required this.level,
    required this.message,
  });

  /// Get a string representation of the object, useful for debugging and logging.
  @override
  String toString() =>
      "OcptDiagnosticsEntry(time: $time, category: $category, level: $level, message: $message)";

  /// List the fields that decide equality.
  @override
  List<Object?> get props => [time, category, level, message];
}
