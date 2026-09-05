<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# Changelog

## 0.1.0

- Initial release: the domain-blind sync wire format shared by the app and the relay.
- `OcptChangesetEnvelope`, `OcptSequenceNumber`, `OcptStoredChangeset`, `OcptSnapshotDescriptor`,
  `OcptSyncError`/`OcptSyncErrorCode`, and the `OcptLamportStamp` ordering rule, each with a
  hand-written JSON codec and value equality.
- Format-version discipline on `OcptChangesetEnvelope` and `OcptSnapshotDescriptor`: a newer
  format is refused, an older one accepted.
