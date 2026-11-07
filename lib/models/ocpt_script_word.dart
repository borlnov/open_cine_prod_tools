// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/ocpt_script_word_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_script_word_layout.dart';

/// A single clickable word of a [OcptScriptWordBlock], as a scene's text is laid out for the
/// word-level click gesture the app uses to designate a passage.
///
/// [startOffset] and [endOffset] are, like every offset in this file, scene-relative (relative to
/// the owning [OcptScriptWordLayout.sceneText], itself already sliced out of the screenplay's
/// whole text): [endOffset] is exclusive, so `sceneText.substring(startOffset, endOffset)` always
/// yields back [text].
class OcptScriptWord extends Equatable {
  /// This word's exact source text, punctuation included (a word is a whitespace-delimited run of
  /// non-whitespace characters, so trailing punctuation stays attached to it).
  final String text;

  /// The scene-relative character offset, in the owning [OcptScriptWordLayout.sceneText], at
  /// which this word starts.
  final int startOffset;

  /// The scene-relative character offset, in the owning [OcptScriptWordLayout.sceneText], one
  /// past this word's last character.
  final int endOffset;

  /// Class constructor
  const OcptScriptWord({required this.text, required this.startOffset, required this.endOffset});

  /// Get a string representation of the object, useful for debugging and logging.
  @override
  String toString() =>
      "OcptScriptWord(text: $text, startOffset: $startOffset, endOffset: $endOffset)";

  /// List the fields that decide equality.
  @override
  List<Object?> get props => [text, startOffset, endOffset];
}
