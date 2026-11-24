// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

/// An authoring note (`[[text]]`) held by a node of the styled editor as an inline placeholder of
/// its `AttributedText`, one position of the document drawn as a small marker, instead of as
/// bracketed text.
///
/// The Fountain source of a note is always [expansion], the text between the brackets being
/// [text]. A note is equal to another when both its [id] and its [text] are: the id is minted when
/// the note is created and never reused, so it follows the note through the edits of its text and
/// tells it apart from another note holding the same words.
final class OcptFountainNote extends Equatable {
  /// The characters opening a note in the Fountain source.
  static const String opening = "[[";

  /// The characters closing a note in the Fountain source.
  static const String closing = "]]";

  /// The stable identifier of the note, minted at its creation.
  final String id;

  /// The text of the note, without its brackets.
  final String text;

  /// Get the Fountain source of the note: its [text] between its brackets.
  String get expansion => "$opening$text$closing";

  /// Class constructor.
  const OcptFountainNote({required this.id, required this.text});

  /// Create a note holding [text], under an identifier no other note has.
  factory OcptFountainNote.create(String text) =>
      OcptFountainNote(id: const Uuid().v4(), text: text);

  /// Create a note with the same [id] as this one, holding [text] instead.
  OcptFountainNote withText(String text) => OcptFountainNote(id: id, text: text);

  /// Get the note as a string, for the logs and the test failures.
  @override
  String toString() => "OcptFountainNote($id, $text)";

  /// Get the properties the equality of the note reads.
  @override
  List<Object?> get props => [id, text];
}
