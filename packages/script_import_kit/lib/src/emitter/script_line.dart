// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/fountain_kit.dart';
import 'package:meta/meta.dart';

/// One typed line of a screenplay being converted to Fountain: the
/// intermediate every reader in this package produces and
/// `ScriptFountainEmitter` renders.
///
/// A [ScriptLine] says what the reader *meant* — this is a scene heading,
/// this is a character cue — and nothing about how Fountain writes it: the
/// forcing markers, the blank lines and the emphasis markup are all the
/// emitter's business, decided from the line's neighbours. That split is
/// what lets a second reader be added behind the same emitter without
/// re-deriving one rule of the Fountain syntax.
@immutable
class ScriptLine {
  /// Creates a [ScriptLine].
  const ScriptLine({
    required this.type,
    required this.runs,
    this.sceneNumber,
    this.isDualDialogue = false,
    this.continuesBlock = false,
  });

  /// Creates a [ScriptLine] whose text carries no inline emphasis at all,
  /// which is what most of a screenplay's lines are.
  ScriptLine.plain({
    required this.type,
    required String text,
    this.sceneNumber,
    this.isDualDialogue = false,
    this.continuesBlock = false,
  }) : runs = [FountainStyledRun(text: text)];

  /// What this line is: a scene heading, a character cue, dialogue…
  ///
  /// [FountainLineType.blank] is never used: a blank source line is not a
  /// line of screenplay, it is what the emitter writes *between* two
  /// blocks (see [continuesBlock]).
  final FountainLineType type;

  /// The line's text, cut into runs of uniform inline emphasis.
  ///
  /// A line with no emphasis at all is a single plain run; the emitter
  /// merges adjacent runs sharing a style itself, so a reader is free to
  /// emit one run per source element without thinking about it.
  final List<FountainStyledRun> runs;

  /// The scene number the source gave this heading (`4A` for `#4A#`), or
  /// `null` when it gave none. Only ever set on a
  /// [FountainLineType.sceneHeading] line.
  final String? sceneNumber;

  /// Whether this cue introduces dialogue spoken simultaneously with the
  /// dialogue block just before it (Fountain's trailing `^`). Only ever set
  /// on a [FountainLineType.character] line.
  final bool isDualDialogue;

  /// Whether this line belongs to the same block as the line before it, so
  /// that no blank line is written between the two.
  ///
  /// This is how a paragraph the source broke across several lines (a Celtx
  /// `<br>`) stays one block. It is not needed inside a dialogue block: the
  /// emitter never separates a parenthetical or a dialogue line from the cue
  /// it belongs to, whatever this flag says.
  final bool continuesBlock;

  /// The line's text with every run concatenated and no emphasis markup.
  String get plainText => runs.map((run) => run.text).join();
}
