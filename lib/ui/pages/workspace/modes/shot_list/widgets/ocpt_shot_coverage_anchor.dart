// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// A pending coverage range anchor, exactly as `OcptShotListInspectorState.pendingCoverageAnchor`
/// holds it: the first word clicked of a range currently being drawn.
typedef OcptShotCoverageAnchor = ({int wordStartOffset, int wordEndOffset});
