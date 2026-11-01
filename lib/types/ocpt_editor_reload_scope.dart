// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The parts of the screenplay editor's shared data that a view can ask the mode to read again
/// (`OcptEditorBloc.reload`).
///
/// The mode reads them with an exhaustive `switch` over this enum. No view writes the screenplay
/// behind the mode's back today (an import goes through the mode's own event), so nothing asks yet:
/// the scope exists because the shared mode contract needs one, and so that a view which writes the
/// text one day cannot do it without the mode reading it back.
enum OcptEditorReloadScope {
  /// The screenplay's stored text, and the document parsed from it.
  screenplay,
}
