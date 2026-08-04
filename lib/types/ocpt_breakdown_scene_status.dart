// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// How far the breakdown pass has got on one scene, held by hand rather than deduced.
///
/// A scene's tagged-element count cannot answer this on its own: a scene may legitimately need
/// nothing at all and still have been read and broken down, and a scene with three tags may be
/// only half-read. So the person doing the pass marks it themselves.
enum OcptBreakdownSceneStatus {
  /// The scene has not been broken down yet.
  toDo,

  /// The scene is being broken down.
  inProgress,

  /// The scene's breakdown is complete.
  done,
}
