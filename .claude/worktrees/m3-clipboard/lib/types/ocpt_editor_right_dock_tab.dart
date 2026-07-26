// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// A tab of the editor's right dock.
///
/// Exactly one of these is active at a time, or none while the dock is closed; see
/// `OcptEditorState.rightDockTab`. The toolbar exposes one button per tab, acting as its selector:
/// clicking the button of an inactive (or closed) tab opens the dock on it, clicking the button
/// of the tab already active closes the dock.
enum OcptEditorRightDockTab {
  /// The formatted screenplay preview, only offered in the raw editing mode: the styled mode's
  /// own layout already is the formatted screenplay.
  preview,

  /// The read-only Fountain syntax guide, offered in both editing modes.
  syntax,
}
