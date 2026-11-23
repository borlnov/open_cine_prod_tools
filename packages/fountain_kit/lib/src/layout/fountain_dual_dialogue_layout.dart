// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:fountain_kit/src/layout/fountain_element_layout.dart';
import 'package:fountain_kit/src/parser/fountain_line_type.dart';

/// The column of a dual-dialogue pair a speech is set in.
enum FountainDualDialogueSide {
  /// The first speech of the pair, set in the left column.
  left,

  /// The second speech of the pair, the one whose cue carries `^`, set in the right column.
  right,
}

/// The layout boxes of one dual-dialogue pair: the two side-by-side columns, each holding the
/// boxes of a character cue, a parenthetical and a dialogue line.
///
/// Both columns have the same width; they differ by their starting position only. A
/// `FountainLayoutMetrics` holds one of these when the page is wide enough for two columns.
class FountainDualDialogueLayout extends Equatable {
  /// The layout box of the left column's character cue.
  final FountainElementLayout leftCharacter;

  /// The layout box of the left column's parentheticals.
  final FountainElementLayout leftParenthetical;

  /// The layout box of the left column's dialogue.
  final FountainElementLayout leftDialogue;

  /// The layout box of the right column's character cue.
  final FountainElementLayout rightCharacter;

  /// The layout box of the right column's parentheticals.
  final FountainElementLayout rightParenthetical;

  /// The layout box of the right column's dialogue.
  final FountainElementLayout rightDialogue;

  /// Class constructor.
  const FountainDualDialogueLayout({
    required this.leftCharacter,
    required this.leftParenthetical,
    required this.leftDialogue,
    required this.rightCharacter,
    required this.rightParenthetical,
    required this.rightDialogue,
  });

  /// Get the layout box a line of [lineType] is set in on [side], or null when a dual-dialogue
  /// column has no box for that type (only the character cue, the parenthetical and the dialogue
  /// are set in columns).
  FountainElementLayout? elementOf(FountainDualDialogueSide side, FountainLineType lineType) {
    final isLeft = side == FountainDualDialogueSide.left;
    return switch (lineType) {
      FountainLineType.character => isLeft ? leftCharacter : rightCharacter,
      FountainLineType.parenthetical => isLeft ? leftParenthetical : rightParenthetical,
      FountainLineType.dialogue => isLeft ? leftDialogue : rightDialogue,
      _ => null,
    };
  }

  /// Describe this [FountainDualDialogueLayout] for debugging and logging.
  @override
  String toString() => 'FountainDualDialogueLayout(left: $leftDialogue, right: $rightDialogue)';

  /// List the fields that decide equality.
  @override
  List<Object?> get props => [
    leftCharacter,
    leftParenthetical,
    leftDialogue,
    rightCharacter,
    rightParenthetical,
    rightDialogue,
  ];
}
