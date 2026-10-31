// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/models/ocpt_diagnostics_entry.dart';

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
