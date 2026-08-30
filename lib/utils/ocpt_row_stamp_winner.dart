// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// Whether an incoming `(version, deviceId)` pair wins the per-column merge over the column's own
/// local stamp — `docs/adr/0010-sync-ready-data-model-prerequisites.md`'s Lamport ordering: the
/// higher `version` wins outright, and [incomingDeviceId]/[localDeviceId] break a tie
/// lexicographically. [localVersion] and [localDeviceId] are both null when the column carries no
/// local stamp at all — a brand-new row arriving from another replica, say — in which case the
/// incoming stamp always wins, there being nothing to compare it against.
///
/// This is a pure function of the two stamps being compared, never of which side happens to be
/// "local" on a given replica: applying the very same rule to the very same pair of stamps on two
/// different replicas is what makes them converge on the same winner (`OcptMergeService`).
bool ocptIncomingStampWins({
  required int incomingVersion,
  required String incomingDeviceId,
  required int? localVersion,
  required String? localDeviceId,
}) {
  if (localVersion == null || localDeviceId == null) {
    return true;
  }

  if (incomingVersion != localVersion) {
    return incomingVersion > localVersion;
  }

  return incomingDeviceId.compareTo(localDeviceId) > 0;
}
