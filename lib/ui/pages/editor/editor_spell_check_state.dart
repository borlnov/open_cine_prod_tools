// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_spell_check_caches.dart';
import 'package:spell_kit/spell_kit.dart';

/// The state of `OcptEditorSpellCheckBloc`: the underlines of both editing surfaces.
///
/// Whether spell-checking is wanted at all (the machine-wide switch and the project's language) is
/// the mode's: both are read when the editor loads and move with a toggle or the project settings,
/// like the other display preferences, and this bloc reads them off the mode's state.
class OcptEditorSpellCheckState extends BlocStateForMixin<OcptEditorSpellCheckState> {
  /// The misspelled ranges found in the raw mode's Fountain source text, document-absolute (the
  /// very offsets its `OcptEditorSearchTextController` paints in).
  ///
  /// Empty while spell-checking is off (either switch), while a project version is being previewed,
  /// or before the first pass has answered, or while the raw editing surface isn't the one mounted
  /// (the raw pass only runs in raw mode, so nothing here would paint anyway).
  final List<SpellRange> rawSpellCheckRanges;

  /// The misspelled ranges found in the styled mode's checkable node texts, keyed by node id, each
  /// relative to that node's own display text — the exact addressing `SpellingAndGrammarStyler`
  /// wants, reported by the bloc's own debounced pass over whatever
  /// `OcptStyledEditorController.reportSpellCheckTexts` last handed it.
  ///
  /// Empty under the same three conditions [rawSpellCheckRanges] is, mirrored. A node id this holds
  /// that no longer exists in the live document (a full rebuild since the ranges were computed) is
  /// simply ignored by the styled editor rather than reaching the styler.
  final Map<String, List<SpellRange>> styledSpellCheckRanges;

  /// What the bloc remembers between two checks, shared by every copy of the state and left out of
  /// [props] on purpose: see [OcptEditorSpellCheckCaches].
  final OcptEditorSpellCheckCaches caches;

  /// Class constructor
  const OcptEditorSpellCheckState({
    required this.rawSpellCheckRanges,
    required this.styledSpellCheckRanges,
    required this.caches,
  });

  /// Init class constructor
  OcptEditorSpellCheckState.init()
    : rawSpellCheckRanges = const [],
      styledSpellCheckRanges = const {},
      caches = OcptEditorSpellCheckCaches();

  /// {@macro act_flutter_utility.BlocStateForMixin.copyWith}
  ///
  /// [rawSpellCheckRanges] and [styledSpellCheckRanges] need no clear flag despite legitimately going
  /// back to empty: `const []`/`const {}` are themselves values, passed explicitly by the caller
  /// wanting that. [caches] is never replaced: the copy shares it.
  @override
  OcptEditorSpellCheckState copyWith({
    List<SpellRange>? rawSpellCheckRanges,
    Map<String, List<SpellRange>>? styledSpellCheckRanges,
  }) => OcptEditorSpellCheckState(
    rawSpellCheckRanges: rawSpellCheckRanges ?? this.rawSpellCheckRanges,
    styledSpellCheckRanges: styledSpellCheckRanges ?? this.styledSpellCheckRanges,
    caches: caches,
  );

  /// Copies this state with both surfaces' misspelled ranges emptied.
  OcptEditorSpellCheckState copyWithRangesCleared() =>
      copyWith(rawSpellCheckRanges: const [], styledSpellCheckRanges: const {});

  /// Copies this state with the misspelled [ranges] found in the raw mode's source text.
  OcptEditorSpellCheckState copyWithRawRanges({required List<SpellRange> ranges}) =>
      copyWith(rawSpellCheckRanges: ranges);

  /// Copies this state with the misspelled [ranges] found in the styled mode's node texts, keyed by
  /// node id.
  OcptEditorSpellCheckState copyWithStyledRanges({required Map<String, List<SpellRange>> ranges}) =>
      copyWith(styledSpellCheckRanges: ranges);

  /// {@macro act_flutter_utility.BlocStateForMixin.props}
  @override
  List<Object?> get props => [...super.props, rawSpellCheckRanges, styledSpellCheckRanges];
}
