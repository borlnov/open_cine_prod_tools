// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The domain-blind sync wire format shared by the app and the relay
/// (`docs/adr/0009-offline-first-sync-through-a-domain-blind-relay.md`): changeset envelopes,
/// snapshot descriptors, sequence numbers, the Lamport ordering rule, and error shapes.
///
/// This library contains no table name and no domain type — see each file's own doc comment for
/// what that means for it. It has no Flutter dependency and no I/O of its own.
library;

export 'src/ocpt_changeset_envelope.dart';
export 'src/ocpt_lamport_stamp.dart';
export 'src/ocpt_sequence_number.dart';
export 'src/ocpt_snapshot_descriptor.dart';
export 'src/ocpt_stored_changeset.dart';
export 'src/ocpt_sync_error.dart';
export 'src/ocpt_sync_protocol_format_error.dart';
