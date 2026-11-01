// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/types/ocpt_screenplay_language.dart';
import 'package:spell_kit/spell_kit.dart';

/// What `OcptEditorSpellCheckBloc` remembers between two checks so that a keystroke costs one
/// block's check rather than the whole screenplay's.
///
/// This is mutable on purpose, and `OcptEditorSpellCheckState` carries the one instance through
/// every copy without ever putting it in its `props`: a cache is filled by the same answer that
/// emits the ranges, so comparing it would make a state differ from itself, and an emit that only
/// changed what the bloc remembers would rebuild the editor for nothing.
class OcptEditorSpellCheckCaches {
  /// The (text, ranges) last checked per raw-mode block index — see
  /// `OcptEditorSpellCheckBloc`'s raw pass for what an index addresses. `ranges` are relative to that
  /// block's own source substring, not document-absolute: the pass re-translates by the block's
  /// *current* `startOffset` every time regardless of whether this entry's text changed, which is
  /// what lets an edit to an *earlier*, unrelated block shift a later one's absolute offset without
  /// invalidating this cache entry — only the block's own text does that.
  final Map<int, ({String text, List<SpellRange> ranges})> raw;

  /// The (language, visibility, manager generation) combination [raw] was last built under.
  ({OcptScreenplayLanguage? language, bool isVisible, int generation})? rawKey;

  /// The (text, ranges) last checked per styled-mode node id, the styled mode's own counterpart to
  /// [raw]. Node ids are already a stable key on their own — unlike the raw path's positional block
  /// index, a node id doesn't shift when an *earlier* node's own text changes — so no "re-translate by
  /// current offset" step is needed: a styled `SpellRange` is already relative to its own node's
  /// display text, exactly the addressing `SpellingAndGrammarStyler` wants.
  final Map<String, ({String text, List<SpellRange> ranges})> styled;

  /// The (language, visibility, manager generation) combination [styled] was last built under.
  ({OcptScreenplayLanguage? language, bool isVisible, int generation})? styledKey;

  /// The checkable node texts the styled editor last reported, remembered so a word ignored or
  /// learned can re-issue a styled-mode check over them without waiting for the styled editor to
  /// report anything fresh — nothing about the document changed, only the manager's word sets did,
  /// and the styled editor itself has no reason to notice that on its own.
  Map<String, String> lastStyledTexts;

  /// The learned-word set last pushed into the spell-check manager, assigned alongside every call of
  /// `OcptSpellCheckManager.setLearnedWords`. A settings-page change compares its freshly re-read
  /// set against this one with `setEquals` rather than pushing unconditionally: it runs on *every*
  /// settings-page change, including a currency edit that has nothing to do with the dictionary, and
  /// re-checking the whole screenplay on every one of those would be exactly the wasted debounce tick
  /// the incremental pass exists to avoid.
  Set<String> pushedLearnedWords;

  /// Class constructor
  OcptEditorSpellCheckCaches()
    : raw = {},
      styled = {},
      lastStyledTexts = const {},
      pushedLearnedWords = const {};

  /// Forgets both caches and their keys: a document built from a different Fountain source than the
  /// one they describe, where a stale entry could coincidentally match a new block's or node's text.
  void clear() {
    raw.clear();
    rawKey = null;
    styled.clear();
    styledKey = null;
  }
}
