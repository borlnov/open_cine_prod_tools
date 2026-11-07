// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The coarse phase of a join currently in flight, shown by the Rejoindre screen's own blocking
/// modal while `OcptJoiningState.isJoining` is true — nothing on the join path reports incremental
/// progress within a phase, so this is the whole of what the modal has to show.
enum OcptJoinStep {
  /// Resolving where the new project lands (the desktop destination picker, or the application's
  /// own documents directory on mobile) and opening the relay transport.
  connecting,

  /// Fetching and materialising the relay's latest snapshot as a new project on disk
  /// (`OcptSyncManager.joinFromRelay`).
  downloading,

  /// Opening the freshly written project (`OcptProjectsManager.openProject`).
  opening,
}
