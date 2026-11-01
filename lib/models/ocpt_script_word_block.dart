// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/models/ocpt_script_word.dart';
import 'package:open_cine_prod_tools/models/ocpt_script_word_layout.dart';

/// One non-blank source line of a scene, laid out into its clickable [words].
///
/// A block never spans more than one Fountain source line, but a designated *range* may well span
/// several blocks: the click interaction closes a range wherever the second click lands, so a
/// block is a unit of rendering and labelling, never a boundary the model enforces.
class OcptScriptWordBlock extends Equatable {
  /// This block's line's [FountainLineType], as classified by [OcptScriptWordLayout.of], shown
  /// as the block's label in the inspector.
  final FountainLineType type;

  /// This block's exact source line text.
  final String text;

  /// The scene-relative character offset, in the owning [OcptScriptWordLayout.sceneText], at
  /// which this block's line starts.
  final int startOffset;

  /// The scene-relative character offset, in the owning [OcptScriptWordLayout.sceneText], one
  /// past this block's line's last character (i.e. excluding the newline that follows it).
  final int endOffset;

  /// This block's words, in source order.
  final List<OcptScriptWord> words;

  /// Class constructor
  const OcptScriptWordBlock({
    required this.type,
    required this.text,
    required this.startOffset,
    required this.endOffset,
    required this.words,
  });

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptScriptWordBlock(type: $type, startOffset: $startOffset, endOffset: $endOffset, "
      "wordCount: ${words.length})";

  /// List the fields that decide equality.
  @override
  List<Object?> get props => [type, text, startOffset, endOffset, words];
}
