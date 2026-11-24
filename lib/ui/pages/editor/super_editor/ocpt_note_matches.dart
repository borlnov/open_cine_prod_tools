// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_text_search.dart';

/// The matches of the find/replace query inside the text of one note, which the card of the note
/// highlights and the marker of the note hints at.
final class OcptNoteMatches extends Equatable {
  /// The matches in the text of the note, in the order of the text.
  final List<OcptTextMatch> ranges;

  /// The current match, one of [ranges], or null when the current match is not in this note.
  final OcptTextMatch? current;

  /// Tell whether the current match of the search is one of this note.
  bool get hasCurrent => current != null;

  /// Class constructor.
  const OcptNoteMatches({required this.ranges, this.current});

  /// Get the properties the equality of the matches reads.
  @override
  List<Object?> get props => [ranges, current];
}
