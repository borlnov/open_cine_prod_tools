// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <benoit.rolandeau@allcircuits.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The way the screenplay editor displays and edits a script.
///
/// This preference is persisted, but the editor itself isn't built yet: it will consume this
/// enum once it lands.
enum OcptEditorMode {
  /// The editor renders the screenplay with its full script formatting (scene headings, action,
  /// dialogue, etc.) applied.
  styled,

  /// The editor exposes the raw underlying text of the screenplay, without formatting.
  raw,
}
