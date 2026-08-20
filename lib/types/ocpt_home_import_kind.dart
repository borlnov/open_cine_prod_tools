// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// What the home page's `Import…` modal (`OcptHomeImportDialog`) was asked to bring in.
///
/// The two things that can come in from outside a project: a whole one somebody sent, or a
/// screenplay to start a new one from. The dialog's own pick, resolved by `OcptHomeBloc` into the
/// two very different flows each one runs.
enum OcptHomeImportKind {
  /// A portable project package (`.ocptz`), unpacked into a project of its own.
  project,

  /// A `.fountain` file, seeding a brand new project with its text.
  screenplay,
}
