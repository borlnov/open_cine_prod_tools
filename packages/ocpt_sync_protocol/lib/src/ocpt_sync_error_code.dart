// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// Every reason a relay's routes refuse a request.
///
/// Domain-blind by construction: none of these names a table, a column or a project's own data —
/// only the shape of the failure at the protocol boundary.
enum OcptSyncErrorCode {
  /// The bearer token presented does not match the one held for this project.
  badToken,

  /// The request names a project the relay has never heard of, and carried no enrolment secret
  /// to create one.
  unknownProject,

  /// The request assumed a sequence position the relay's log has since moved past.
  sequenceConflict,

  /// The request body could not be parsed as this protocol's wire format.
  malformed,

  /// The request declares a protocol or snapshot format newer than this relay knows how to read.
  unsupportedFormat,
}
