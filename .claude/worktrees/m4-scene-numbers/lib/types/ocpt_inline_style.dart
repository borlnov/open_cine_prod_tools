// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// An inline text formatting the styled screenplay editor can toggle on a selection or at the
/// caret, independent of a block's Fountain line type.
enum OcptInlineStyle {
  /// Bold text, serialized as `**text**`.
  bold,

  /// Italic text, serialized as `*text*`.
  italic,

  /// Underlined text, serialized as `_text_`.
  underline,
}
