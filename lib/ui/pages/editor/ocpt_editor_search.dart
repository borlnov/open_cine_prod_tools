// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:open_cine_prod_tools/utils/ocpt_text_search.dart';

/// The translucent accent wash painted behind every match, in both editing modes.
///
/// A fixed colour rather than a theme-derived one, for the same reason the rest of the styled
/// editor's page-simulation styling already is: the styled editor paints on white paper whatever
/// the app's theme, and a theme-derived colour can render invisible there. This alpha is low
/// enough to never hide the glyphs it sits under, over the white sheet or the dark studio surface
/// alike.
const Color ocptEditorSearchMatchColor = Color(0x406C5CE7);

/// The current match's own colour: the same hue as [ocptEditorSearchMatchColor], markedly
/// stronger so the current occurrence reads apart from the rest.
const Color ocptEditorSearchCurrentMatchColor = Color(0x996C5CE7);

/// The wavy underline colour a misspelling is painted with in raw mode, in both editing modes'
/// spirit: a fixed, error-toned colour rather than a theme-derived one, so it reads the same
/// whether the surrounding text sits on the studio's dark background or the page-simulation's
/// white sheet — the same reasoning [ocptEditorSearchMatchColor]'s own doc comment gives for
/// staying fixed rather than theme-derived.
const Color ocptEditorSpellCheckErrorColor = Color(0xFFE05252);

/// One editor find/replace query: the text searched for, plus its two options.
///
/// Equatable so `OcptEditorSearchState`'s own equality (and therefore the bloc's emit-skip on an
/// unchanged state) sees a query that didn't actually change as the same query.
class OcptEditorSearchQuery extends Equatable {
  /// The text searched for.
  final String query;

  /// Whether the search is case-sensitive.
  final bool isCaseSensitive;

  /// Whether the search only matches whole words.
  final bool isWholeWord;

  /// Class constructor
  const OcptEditorSearchQuery({
    required this.query,
    required this.isCaseSensitive,
    required this.isWholeWord,
  });

  /// This query's matches in [text], through `ocptFindTextMatches` — the one thing every caller
  /// (the raw controller's highlight, the page's replace/replace-all, the bloc test doubles) goes
  /// through, so none of them can drift from the matcher's own rules.
  List<OcptTextMatch> matchesIn(String text) => ocptFindTextMatches(
    text: text,
    query: query,
    isCaseSensitive: isCaseSensitive,
    isWholeWord: isWholeWord,
  );

  /// Object properties
  @override
  List<Object?> get props => [query, isCaseSensitive, isWholeWord];
}
