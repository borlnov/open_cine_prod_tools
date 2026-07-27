// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// A tab of the editor's right dock.
///
/// Exactly one of these is active at a time, or none while the dock is closed; see
/// `OcptEditorState.rightDockTab`. [preview] and [syntax] are also reachable from the workspace
/// toolbar's own buttons, which double as their selector: clicking the button of an inactive (or
/// closed) tab opens the dock on it, clicking the button of the tab already active closes the
/// dock. [inspector] and [metadata] have no toolbar button (the toolbar already carries two
/// tab-opening buttons and does not grow more): the dock's own tab row is their only selector, and
/// selecting them never closes the dock the way the toolbar buttons' own tab does.
enum OcptEditorRightDockTab {
  /// The formatted screenplay preview, only offered in the raw editing mode: the styled mode's
  /// own layout already is the formatted screenplay.
  preview,

  /// The read-only Fountain syntax guide, offered in both editing modes.
  syntax,

  /// The scene under the caret: its heading, its speaking characters, its estimated duration and
  /// its page-eighths. Offered in both editing modes.
  inspector,

  /// The screenplay's title-page fields and script-wide statistics, read-only. Offered in both
  /// editing modes.
  metadata,
}
