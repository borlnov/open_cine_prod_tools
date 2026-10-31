// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// Why the breakdown mode's selection last moved (`OcptBreakdownState.selectionCause`).
///
/// The selection is the selected scene and the selected target. A view reads the cause to know how
/// much of what it holds was scoped to the selection that has just gone: a tag range open in the
/// script is dropped when the centre leaves the script or when the whole read is replaced, whereas
/// it survives the user selecting another scene or another target.
enum OcptBreakdownSelectionCause {
  /// Nothing has moved the selection yet.
  none,

  /// A scene was selected from the left dock or from a target's occurrences, which leaves the
  /// selected target and the right dock alone.
  scene,

  /// A scene heading of the script was clicked: the scene is selected, the selected target is
  /// dropped and the right dock opens on its `Inspector` tab.
  sceneHeading,

  /// A target was selected, with the scene the click happened in, and the right dock opens on its
  /// `Inspector` tab.
  target,

  /// The selected target was cleared, which brings the scene's own sheet back.
  targetCleared,

  /// A first click of the script opened a tag anchor in another scene, which selects that scene.
  anchorScene,

  /// The centre moved to the recap, or was asked for again (the header's `Script`/`Recap` switch,
  /// or a search typed from the script): the script sheet a tag range belongs to is left.
  centreView,

  /// The mode read everything again and cleared its selection: on entry, when a version preview
  /// was entered or left, or when a version was restored.
  load,
}
