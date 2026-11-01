// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';

/// The editor's live find/replace state — one search, kept in the bloc rather than in either
/// editing surface, which is what lets it survive a raw ⇄ styled mode toggle.
class OcptEditorSearchState extends Equatable {
  /// Whether the find/replace bar is open at all.
  final bool isOpen;

  /// Whether the replace row is unfolded under the find row.
  final bool isReplaceRowOpen;

  /// The text currently searched for.
  final String query;

  /// The text a match is replaced by.
  final String replacement;

  /// Whether the search is case-sensitive.
  final bool isCaseSensitive;

  /// Whether the search only matches whole words.
  final bool isWholeWord;

  /// The number of matches the mounted editing surface last reported.
  ///
  /// Computed over what that surface actually shows — the raw source text, or a styled node's
  /// display text — so the count can legitimately differ between the two modes for a query
  /// holding markup (a forcing marker, a `#N#` tag, `*`/`_` emphasis): a search shows what the
  /// user can see, not the underlying Fountain source the styled mode never displays.
  final int matchCount;

  /// The 0-based index, among [matchCount] matches, of the current one; null while there is none.
  final int? currentMatchIndex;

  /// The id of the last request to (re)focus and select the find field, bumped on every "open".
  ///
  /// The same idiom as `OcptEditorJumpRequest.id`: the bar remembers the last one it applied, so
  /// re-opening an already-open bar (or unfolding its replace row through Ctrl+H) still refocuses
  /// the find field even though [isOpen] itself doesn't change value.
  final int focusRequestId;

  /// Class constructor
  const OcptEditorSearchState({
    required this.isOpen,
    required this.isReplaceRowOpen,
    required this.query,
    required this.replacement,
    required this.isCaseSensitive,
    required this.isWholeWord,
    required this.matchCount,
    required this.currentMatchIndex,
    required this.focusRequestId,
  });

  /// Init class constructor
  const OcptEditorSearchState.init()
    : isOpen = false,
      isReplaceRowOpen = false,
      query = "",
      replacement = "",
      isCaseSensitive = false,
      isWholeWord = false,
      matchCount = 0,
      currentMatchIndex = null,
      focusRequestId = 0;

  /// Returns a copy of this state with the given fields replaced.
  ///
  /// [currentMatchIndex] only goes back to null through [forceCurrentMatchIndexValue] — the
  /// "there is no match" state a plain `int?` field can't tell apart from "leave it as it is" on
  /// its own.
  OcptEditorSearchState copyWith({
    bool? isOpen,
    bool? isReplaceRowOpen,
    String? query,
    String? replacement,
    bool? isCaseSensitive,
    bool? isWholeWord,
    int? matchCount,
    int? currentMatchIndex,
    bool forceCurrentMatchIndexValue = false,
    int? focusRequestId,
  }) => OcptEditorSearchState(
    isOpen: isOpen ?? this.isOpen,
    isReplaceRowOpen: isReplaceRowOpen ?? this.isReplaceRowOpen,
    query: query ?? this.query,
    replacement: replacement ?? this.replacement,
    isCaseSensitive: isCaseSensitive ?? this.isCaseSensitive,
    isWholeWord: isWholeWord ?? this.isWholeWord,
    matchCount: matchCount ?? this.matchCount,
    currentMatchIndex:
        currentMatchIndex ?? (forceCurrentMatchIndexValue ? null : this.currentMatchIndex),
    focusRequestId: focusRequestId ?? this.focusRequestId,
  );

  /// Object properties
  @override
  List<Object?> get props => [
    isOpen,
    isReplaceRowOpen,
    query,
    replacement,
    isCaseSensitive,
    isWholeWord,
    matchCount,
    currentMatchIndex,
    focusRequestId,
  ];
}
