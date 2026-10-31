// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/src/parser/fountain_line_classifier.dart';

/// The structural role of a single source line, as determined by
/// [FountainLineClassifier].
enum FountainLineType {
  /// A line with no content (or only whitespace that does not carry the
  /// "preserved blank dialogue line" meaning described in the Fountain
  /// spec).
  blank,

  /// A forced page break, `===`.
  pageBreak,

  /// An organizational section heading, `# text` through `###### text`.
  section,

  /// A synopsis line, `= text`.
  synopsis,

  /// A scene heading, for example `INT. KITCHEN - DAY`.
  sceneHeading,

  /// A transition, for example `CUT TO:`.
  transition,

  /// Centered text, `> text <`.
  centeredText,

  /// A lyrics line, `~ text`.
  lyrics,

  /// A character cue introducing dialogue.
  character,

  /// A parenthetical direction inside a dialogue block.
  parenthetical,

  /// A line of spoken dialogue.
  dialogue,

  /// A line of action/description text; the default when nothing more
  /// specific applies.
  action,
}
