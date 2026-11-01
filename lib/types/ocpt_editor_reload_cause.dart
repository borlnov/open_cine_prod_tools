// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// What last moved the screenplay editor's `reloadEpoch` (`OcptEditorState.reloadCause`).
///
/// A view reads the cause to know how much of what it holds the new data invalidates: the
/// spell-check underlines of the previous screenplay are dropped by a whole load but kept, then
/// refreshed, when only the text was replaced, whereas the counters are recomputed at once for all of
/// them.
enum OcptEditorReloadCause {
  /// Nothing has moved the epoch yet.
  none,

  /// The mode read everything again: on entry, when a version preview was entered or left, when a
  /// version was restored.
  load,

  /// The screenplay's text was replaced as a whole by an action rather than typed: an import, a
  /// title page rewrite, or a read of the stored text.
  textReplaced,

  /// The page setup changed, which repaginates the screenplay.
  pageSetup,
}
