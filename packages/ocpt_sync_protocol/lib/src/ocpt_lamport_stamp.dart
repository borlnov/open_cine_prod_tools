// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';

/// The pure ordering rule `docs/adr/0010-sync-ready-data-model-prerequisites.md` defines over a
/// per-column version stamp: a higher [version] wins, and two writes that raced to the same
/// counter value are broken by comparing [deviceId] lexicographically.
///
/// This is deliberately reduced to the two scalars the ordering actually reads. It carries no
/// table name, no row id and no column name — `ocpt_sync_protocol` is domain-blind by design, and
/// which row or column a stamp belongs to is entirely the app's concern. [version] is a
/// device-local Lamport counter, never a relay `OcptSequenceNumber`: a relay's own counter cannot
/// play this role once a set relay and a prep relay both assign sequence numbers on the same day.
class OcptLamportStamp extends Equatable implements Comparable<OcptLamportStamp> {
  /// Creates a stamp from the device-local Lamport counter [version] reached by [deviceId] at the
  /// moment of the write it describes.
  const OcptLamportStamp({required this.version, required this.deviceId});

  /// The device-local Lamport counter reached at the moment of the write this stamp describes.
  final int version;

  /// The device that made the write this stamp describes.
  final String deviceId;

  /// Orders this stamp against [other]: a higher [version] sorts after a lower one, and two equal
  /// versions are ordered by comparing [deviceId] lexicographically.
  @override
  int compareTo(OcptLamportStamp other) {
    final versionComparison = version.compareTo(other.version);
    if (versionComparison != 0) {
      return versionComparison;
    }
    return deviceId.compareTo(other.deviceId);
  }

  /// True when this stamp is the one a merge keeps over [other], per the ADR 0010 ordering:
  /// [compareTo] returning a strictly positive value.
  bool wins(OcptLamportStamp other) => compareTo(other) > 0;

  @override
  List<Object?> get props => [version, deviceId];

  @override
  String toString() => 'OcptLamportStamp(version: $version, deviceId: $deviceId)';
}
