// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';

/// The state of `OcptEditorSearchBloc`: the editor's live find/replace state — one search, kept in a
/// bloc rather than in either editing surface, which is what lets it survive a raw ⇄ styled mode
/// toggle.
class OcptEditorSearchState extends BlocStateForMixin<OcptEditorSearchState> {
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

  /// {@macro act_flutter_utility.BlocStateForMixin.copyWith}
  ///
  /// [currentMatchIndex] only goes back to null through [forceCurrentMatchIndexValue] — the
  /// "there is no match" state a plain `int?` field can't tell apart from "leave it as it is" on
  /// its own.
  @override
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

  /// Copy this state with the bar opened, the replace row folded to [isReplaceRowOpen] and
  /// [focusRequestId] raised so the find field takes the focus.
  OcptEditorSearchState copyWithOpened({
    required bool isReplaceRowOpen,
    required int focusRequestId,
  }) => copyWith(isOpen: true, isReplaceRowOpen: isReplaceRowOpen, focusRequestId: focusRequestId);

  /// Copy this state with the bar closed and its highlight cleared.
  OcptEditorSearchState copyWithClosed() =>
      copyWith(isOpen: false, matchCount: 0, forceCurrentMatchIndexValue: true);

  /// Copy this state with the replace row folded or unfolded to [isReplaceRowOpen].
  OcptEditorSearchState copyWithReplaceRowToggled({required bool isReplaceRowOpen}) =>
      copyWith(isReplaceRowOpen: isReplaceRowOpen);

  /// Copy this state with the find field's new [query] and the current match back at the first.
  OcptEditorSearchState copyWithQuery({required String query}) =>
      copyWith(query: query, currentMatchIndex: 0);

  /// Copy this state with the replace field's new [replacement].
  OcptEditorSearchState copyWithReplacement({required String replacement}) =>
      copyWith(replacement: replacement);

  /// Copy this state with the "match case" option set to [isCaseSensitive].
  OcptEditorSearchState copyWithCaseSensitivity({required bool isCaseSensitive}) =>
      copyWith(isCaseSensitive: isCaseSensitive);

  /// Copy this state with the "whole word" option set to [isWholeWord].
  OcptEditorSearchState copyWithWholeWord({required bool isWholeWord}) =>
      copyWith(isWholeWord: isWholeWord);

  /// Copy this state with no match left: the count at zero and no current match.
  OcptEditorSearchState copyWithoutMatches() =>
      copyWith(matchCount: 0, forceCurrentMatchIndexValue: true);

  /// Copy this state with the [matchCount] the surface reported and the current match moved to
  /// [currentMatchIndex].
  OcptEditorSearchState copyWithMatches({
    required int matchCount,
    required int currentMatchIndex,
  }) => copyWith(matchCount: matchCount, currentMatchIndex: currentMatchIndex);

  /// Copy this state with the current match moved to [currentMatchIndex].
  OcptEditorSearchState copyWithCurrentMatch({required int currentMatchIndex}) =>
      copyWith(currentMatchIndex: currentMatchIndex);

  /// {@macro act_flutter_utility.BlocStateForMixin.props}
  @override
  List<Object?> get props => [
    ...super.props,
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
