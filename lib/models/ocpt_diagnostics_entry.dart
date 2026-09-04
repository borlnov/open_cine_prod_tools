// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';

/// Which subsystem recorded an [OcptDiagnosticsEntry] — lets `OcptDiagnosticsLogList` filter
/// `OcptDiagnosticsManager`'s own buffer down to only what a given screen cares about (the
/// hosting panel shows every category, the Rejoindre screen only [join] and [sync]).
enum OcptDiagnosticsCategory {
  /// `OcptRelayHostManager`'s own start/stop/online/failed lifecycle.
  hosting,

  /// `OcptSyncSession`'s own status transitions.
  sync,

  /// `OcptJoiningBloc`'s own step-by-step progress.
  join,

  /// `OcptRelayServer`'s own request-level events, forwarded through `OcptRelayHostManager`'s
  /// `onEvent` sink while this replica is hosting.
  relayServer,

  /// A change to the connected-peers presence roster.
  presence,
}

/// How severe an [OcptDiagnosticsEntry] is — tints the line `OcptDiagnosticsLogList` draws it on.
enum OcptDiagnosticsLevel {
  /// An ordinary, expected event.
  info,

  /// Something worth a second look, but not a failure on its own.
  warning,

  /// A failure.
  error,
}

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

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptDiagnosticsEntry(time: $time, category: $category, level: $level, message: $message)";

  /// Object properties
  @override
  List<Object?> get props => [time, category, level, message];
}
