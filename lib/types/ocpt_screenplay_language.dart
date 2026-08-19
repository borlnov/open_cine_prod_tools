// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The language a project's screenplays are **written** in, stored in
/// `project_info.screenplayLanguage`.
///
/// This is not the UI language: the two are different things, and the whole reason this column
/// exists rather than reusing `LocalesManager`'s own setting is that they routinely disagree. A
/// screenplay written in French stays French on a colleague's machine running the app in English —
/// the text does not translate itself because the menus did — and it is this value, never the UI's
/// own locale, that the spell-checker reads to know which dictionary a screenplay's prose is
/// checked against.
enum OcptScreenplayLanguage {
  /// French, checked against the bundled `fr` hunspell dictionary.
  fr,

  /// English (UK), checked against the bundled `en_GB` hunspell dictionary.
  enGb,
}
