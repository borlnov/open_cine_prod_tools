// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// One entry of the Fountain syntax guide: a single notation a writer may
/// want to look up (a block type, an inline convention, or the title page).
///
/// Every value has exactly one row in `ocptFountainSyntaxEntries`
/// (`lib/models/ocpt_fountain_syntax_entry.dart`), which pairs it with its
/// [OcptFountainSyntaxSection], its Fountain source snippet and, where
/// applicable, the `FountainLineType` it maps to.
enum OcptFountainSyntaxTopic {
  /// A scene heading, for example `INT. KITCHEN - DAY`.
  sceneHeading,

  /// A scene heading's explicit scene number, marked with a trailing
  /// `#N#` tag.
  sceneNumber,

  /// Action/description text, the default when nothing more specific
  /// applies.
  action,

  /// A character cue introducing a line of dialogue.
  character,

  /// A parenthetical direction inside a dialogue block.
  parenthetical,

  /// A line of spoken dialogue.
  dialogue,

  /// Two dialogue blocks meant to be read side by side, the second cue
  /// marked with a trailing `^`.
  dualDialogue,

  /// A transition, for example `CUT TO:`.
  transition,

  /// Centered text, framed with `>` and `<`.
  centeredText,

  /// A lyrics line, marked with a leading `~`.
  lyrics,

  /// A forced page break.
  pageBreak,

  /// An organizational section heading, marked with leading `#` characters.
  section,

  /// A synopsis line, marked with a leading `=`.
  synopsis,

  /// An authoring note for the reader, enclosed in `[[` and `]]`.
  note,

  /// A boneyard comment excluded from the printed screenplay, enclosed in
  /// `/*` and `*/`.
  boneyard,

  /// Inline bold, italic and underline emphasis.
  emphasis,

  /// The title page, a block of `key: value` lines at the start of the
  /// document.
  titlePage,
}

/// A group of related [OcptFountainSyntaxTopic]s in the syntax guide.
///
/// The guide lists its sections in the order this enum declares them.
enum OcptFountainSyntaxSection {
  /// The screenplay's structural building blocks: scene headings, action,
  /// dialogue and its variants, transitions and the other block types a
  /// writer assembles a scene from.
  structure,

  /// Elements that organize the document without appearing in the printed
  /// screenplay body as a scene element: sections, synopses, notes and the
  /// boneyard.
  organisation,

  /// Inline text formatting.
  formatting,

  /// The title page.
  titlePage,
}
