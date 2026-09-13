// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';

/// A relay's own delivery cursor: how far a replica has read the changeset log.
///
/// It is monotonic and totally ordered, which is all a "read since" call needs to hand back the
/// next page and all a replica needs to remember where it left off. It is deliberately **not** a
/// merge primitive: `docs/adr/0010-sync-ready-data-model-prerequisites.md` is explicit that a
/// relay's counter cannot decide which of two column edits wins, because a set relay and a prep
/// relay both assign their own sequence numbers on the same day. Which edit wins a merge is
/// decided by a Lamport stamp instead — see the ordering exposed for `(version, deviceId)`
/// pairs — never by comparing two [OcptSequenceNumber]s from different relays.
class OcptSequenceNumber extends Equatable implements Comparable<OcptSequenceNumber> {
  /// Creates a sequence number wrapping [value], the relay-assigned position in its log.
  const OcptSequenceNumber(this.value) : assert(value >= 0, 'a sequence number cannot be negative');

  /// Parses a sequence number from the plain integer stored on the wire.
  factory OcptSequenceNumber.fromJson(int json) => OcptSequenceNumber(json);

  /// The position before any changeset has ever been read: no relay has assigned sequence number
  /// zero to a real changeset, so this is a safe "nothing read yet" starting cursor.
  static const zero = OcptSequenceNumber(0);

  /// The relay-assigned position this cursor names.
  final int value;

  /// The next position in the same log, one past this one.
  OcptSequenceNumber next() => OcptSequenceNumber(value + 1);

  /// True when this position comes strictly before [other] in the same log.
  bool operator <(OcptSequenceNumber other) => value < other.value;

  /// True when this position comes before or at [other] in the same log.
  bool operator <=(OcptSequenceNumber other) => value <= other.value;

  /// True when this position comes strictly after [other] in the same log.
  bool operator >(OcptSequenceNumber other) => value > other.value;

  /// True when this position comes after or at [other] in the same log.
  bool operator >=(OcptSequenceNumber other) => value >= other.value;

  @override
  int compareTo(OcptSequenceNumber other) => value.compareTo(other.value);

  /// The plain integer this sequence number is written as on the wire.
  int toJson() => value;

  @override
  List<Object?> get props => [value];

  @override
  String toString() => 'OcptSequenceNumber($value)';
}
