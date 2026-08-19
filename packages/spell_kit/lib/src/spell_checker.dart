// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:collection';

import 'package:spell_kit/src/hunspell_affix_file.dart';
import 'package:spell_kit/src/hunspell_affix_rule_index.dart';
import 'package:spell_kit/src/hunspell_dictionary.dart';
import 'package:spell_kit/src/spell_range.dart';
import 'package:spell_kit/src/spell_tokenizer.dart';

/// The maximum number of `BREAK` splits tried while resolving one word, a
/// guard against a pathological input (a word made mostly of separators)
/// recursing without bound.
const int _maxBreakDepth = 5;

/// The default size of [SpellChecker]'s memo: an LRU of the last-seen
/// distinct words, well past a feature film's own vocabulary.
const int _defaultMemoCapacity = 20000;

/// The case shape of a typed word, used to decide which case-folded forms
/// are worth trying against the dictionary.
enum _WordCase {
  /// No letter in the word is uppercase.
  allLower,

  /// The first letter is uppercase and every other letter is lowercase.
  titleCase,

  /// Every cased letter in the word is uppercase.
  allCaps,

  /// Anything else, most notably an interior capital (`MacGuffin`).
  mixed,
}

/// One case-folded form of a typed word tried against the dictionary, and
/// whether it is the word exactly as typed.
class _CaseCandidate {
  /// Creates a [_CaseCandidate].
  const _CaseCandidate({required this.form, required this.isExactTyped});

  /// The form to look up.
  final String form;

  /// Whether [form] equals the word exactly as the writer typed it. A
  /// `KEEPCASE`-flagged entry may only be matched by such a candidate.
  final bool isExactTyped;
}

/// The outcome of a successful dictionary lookup (bare, single-affix, or
/// cross-product): the flags of the entry that ultimately matched, needed
/// to honour `KEEPCASE`.
class _LookupResult {
  /// Creates a [_LookupResult].
  const _LookupResult(this.flags);

  /// The matched entry's raw, concatenated flag string.
  final String flags;
}

/// Checks whether a word is known to a [SpellDictionary].
///
/// A [SpellChecker] is built once per loaded dictionary and reused for
/// every check: it owns a bounded memo of recent lookups (an LRU of the
/// last ~20 000 distinct words) and a rule index (suffix rules bucketed by
/// the last character of their `append`, prefix rules by the first), so
/// that a lookup considers a few dozen candidate rules instead of every
/// rule the dictionary declares.
class SpellChecker {
  /// Creates a [SpellChecker] over [dictionary].
  SpellChecker(this.dictionary, {int memoCapacity = _defaultMemoCapacity})
    : ruleIndex = HunspellAffixRuleIndex(dictionary.affixFile),
      _memoCapacity = memoCapacity;

  /// The dictionary this checker looks words up in.
  final SpellDictionary dictionary;

  /// The index narrowing which affix rules a lookup tries (§2.3's first
  /// performance rule). Exposed so a test can assert its shape without
  /// having to time anything.
  final HunspellAffixRuleIndex ruleIndex;

  /// The bound on [_memo]'s size.
  final int _memoCapacity;

  /// The memo of recent [isKnown] results, keyed by the word exactly as it
  /// was typed. Iteration (and re-insertion) order is insertion order,
  /// which is what makes evicting `_memo.keys.first` an LRU eviction rather
  /// than a FIFO one: every read moves its entry back to the end.
  final LinkedHashMap<String, bool> _memo = LinkedHashMap();

  /// The learned and ignored words pushed in by the caller, split by
  /// whether they carry an interior capital (see [setExtraWords]).
  Set<String> _extraWordsExact = const {};

  /// The lowercased form of every extra word with no interior capital.
  Set<String> _extraWordsCaseInsensitive = const {};

  /// Sets the learned and ignored words a caller wants treated as known in
  /// addition to the dictionary itself.
  ///
  /// A word with no interior capital (`Marie`, `marie`) matches
  /// case-insensitively; a word with an interior capital (`MacGuffin`)
  /// matches only that exact casing. Calling this clears the memo: the
  /// extra-word set changing can turn a previously-unknown word known, or
  /// (once a word is un-learned) the other way round.
  void setExtraWords(Set<String> words) {
    _extraWordsExact = {
      for (final word in words)
        if (_hasInteriorCapital(word)) word,
    };
    _extraWordsCaseInsensitive = {
      for (final word in words)
        if (!_hasInteriorCapital(word)) word.toLowerCase(),
    };
    _memo.clear();
  }

  /// Whether [word] is known: an extra word, a dictionary word (bare,
  /// under one affix, or under a prefix+suffix cross product), a `BREAK`
  /// split whose non-empty parts are all known, or a `COMPOUNDRULE` match.
  bool isKnown(String word) {
    // The memo is keyed on the word exactly as it was typed, not on its
    // `ICONV`-folded form: folding runs one pass per `ICONV` rule (the
    // French file declares 42 of them), which would otherwise be paid on
    // every cache hit and swamp the lookup the memo exists to avoid.
    // Folding is deterministic, so answering from the typed word is the
    // same answer, arrived at without the scan.
    final cached = _readMemo(word);
    if (cached != null) {
      return cached;
    }
    final result = _isKnownAtDepth(_applyIconv(word), 0);
    _writeMemo(word, result);
    return result;
  }

  /// Tokenizes [text] and returns the range of every token [isKnown] finds
  /// unknown.
  List<SpellRange> misspellingsIn(
    String text, {
    SpellTokenizerOptions options = const SpellTokenizerOptions(),
  }) {
    final ranges = <SpellRange>[];
    for (final token in spellTokensIn(text, options: options)) {
      if (!isKnown(token.text)) {
        ranges.add(token.range);
      }
    }
    return ranges;
  }

  /// The shared recursive core of [isKnown]: tried at [depth] so that
  /// `BREAK` splitting (which recurses into this same function) can be
  /// bounded by [_maxBreakDepth]. Not memoized itself — only the top-level
  /// [isKnown] call is.
  bool _isKnownAtDepth(String word, int depth) {
    if (_isExtraWordKnown(word)) {
      return true;
    }
    if (_lookupWithCaseFolding(word)) {
      return true;
    }
    if (depth < _maxBreakDepth && _matchesBreakPatterns(word, depth)) {
      return true;
    }
    return _matchesCompoundRules(word);
  }

  /// Applies [HunspellAffixFile.iconvRules] to [word], the folding step
  /// hunspell always performs before any lookup.
  String _applyIconv(String word) {
    var result = word;
    for (final rule in dictionary.affixFile.iconvRules) {
      result = result.replaceAll(rule.from, rule.to);
    }
    return result;
  }

  /// Reads [word] from the memo, moving it to the most-recently-used end
  /// if present. Returns `null` on a miss (never confusable with a cached
  /// `false`, since [Map.remove] itself returns `null` only on a miss).
  bool? _readMemo(String word) {
    final value = _memo.remove(word);
    if (value != null) {
      _memo[word] = value;
    }
    return value;
  }

  /// Writes [word]'s [result] into the memo, evicting the least-recently
  /// used entry if the memo has grown past [_memoCapacity].
  void _writeMemo(String word, bool result) {
    _memo.remove(word);
    _memo[word] = result;
    if (_memo.length > _memoCapacity) {
      _memo.remove(_memo.keys.first);
    }
  }

  /// Whether [word] has an uppercase letter anywhere after its first
  /// character.
  bool _hasInteriorCapital(String word) =>
      word.length > 1 && word.substring(1) != word.substring(1).toLowerCase();

  /// Whether [word] matches one of the extra (learned/ignored) words, per
  /// [setExtraWords]'s casing rule.
  ///
  /// The interior-capital test belongs to the word as it was *stored* — it
  /// is what [setExtraWords] sorted the two sets by — never to the word as
  /// it was typed: a learned `Marie` has to cover `MARIE` in a shouted
  /// line, and asking whether `MARIE` itself carries an interior capital
  /// would refuse exactly that.
  bool _isExtraWordKnown(String word) =>
      _extraWordsExact.contains(word) ||
      _extraWordsCaseInsensitive.contains(word.toLowerCase());

  /// Classifies [word]'s case shape.
  _WordCase _classifyCase(String word) {
    final hasUpper = word != word.toLowerCase();
    final hasLower = word != word.toUpperCase();
    if (!hasUpper) {
      return _WordCase.allLower;
    }
    if (!hasLower) {
      return _WordCase.allCaps;
    }
    final rest = word.substring(1);
    final isTitleCase =
        word[0] == word[0].toUpperCase() && rest == rest.toLowerCase();
    return isTitleCase ? _WordCase.titleCase : _WordCase.mixed;
  }

  /// Capitalizes [word]'s first letter and lowercases the rest.
  String _titleCase(String word) =>
      word[0].toUpperCase() + word.substring(1).toLowerCase();

  /// The case-folded forms of [word] worth trying against the dictionary,
  /// in order: the word exactly as typed always comes first, followed by
  /// the folds its case shape allows — a lowercase entry matches its
  /// title-case and all-caps typed forms, and a title-case entry matches
  /// only an all-caps typed form (never a lowercase one).
  List<_CaseCandidate> _caseFoldCandidates(String word) {
    final candidates = [_CaseCandidate(form: word, isExactTyped: true)];
    switch (_classifyCase(word)) {
      case _WordCase.allCaps:
        candidates.add(
          _CaseCandidate(form: word.toLowerCase(), isExactTyped: false),
        );
        candidates.add(
          _CaseCandidate(form: _titleCase(word), isExactTyped: false),
        );
      case _WordCase.titleCase:
        candidates.add(
          _CaseCandidate(form: word.toLowerCase(), isExactTyped: false),
        );
      case _WordCase.allLower:
      case _WordCase.mixed:
      // No case beyond the word exactly as typed is worth trying: a
      // lowercase word cannot be folded any further, and a mixed-case
      // word (an interior capital) matches only its exact spelling.
    }
    return candidates;
  }

  /// Tries every case-folded form of [word] against the dictionary,
  /// refusing a `KEEPCASE` entry unless the matching form was the word
  /// exactly as typed.
  bool _lookupWithCaseFolding(String word) {
    for (final candidate in _caseFoldCandidates(word)) {
      final result = _lookupExactSuffixPrefixCross(candidate.form);
      if (result == null) {
        continue;
      }
      final isKeepCase = dictionary.affixFile.containsFlag(
        result.flags,
        dictionary.affixFile.keepCaseFlag,
      );
      if (isKeepCase && !candidate.isExactTyped) {
        continue;
      }
      return true;
    }
    return false;
  }

  /// Whether [flags] carries [dictionary]'s `FORBIDDENWORD` flag.
  bool _isForbidden(String flags) => dictionary.affixFile.containsFlag(
    flags,
    dictionary.affixFile.forbiddenWordFlag,
  );

  /// Whether [flags] carries [dictionary]'s `NEEDAFFIX` flag.
  bool _isNeedAffix(String flags) => dictionary.affixFile.containsFlag(
    flags,
    dictionary.affixFile.needAffixFlag,
  );

  /// Whether [flags] carries [dictionary]'s `ONLYINCOMPOUND` flag.
  bool _isOnlyInCompound(String flags) => dictionary.affixFile.containsFlag(
    flags,
    dictionary.affixFile.onlyInCompoundFlag,
  );

  /// Whether an entry carrying [flags] may be known as a bare word (no
  /// affix, no compound).
  bool _isUsableBareEntry(String flags) =>
      !_isForbidden(flags) && !_isNeedAffix(flags) && !_isOnlyInCompound(flags);

  /// Whether an entry carrying [flags] may be used as the stem under an
  /// affix. `NEEDAFFIX` is allowed here — it is the whole point of the
  /// flag — but `ONLYINCOMPOUND` is not: that flag restricts an entry to
  /// `COMPOUNDRULE` pieces alone.
  bool _isUsableAffixStem(String flags) =>
      !_isForbidden(flags) && !_isOnlyInCompound(flags);

  /// Whether [rule] carries the circumfix flag as one of its continuation
  /// flags, meaning it may only be used paired with its circumfix partner
  /// in a cross product, never alone.
  bool _needsCircumfix(HunspellAffixRule rule) => dictionary.affixFile
      .containsFlag(rule.continuationFlags, dictionary.affixFile.circumfixFlag);

  /// Reconstructs the stem a `SFX` [rule] would have been applied to in
  /// order to produce surface form [form], or `null` if [rule] does not
  /// apply (the form does not end with its `append`, or removing it would
  /// leave nothing of the original word and `FULLSTRIP` is not declared).
  String? _undoSuffix(String form, HunspellAffixRule rule) {
    if (!form.endsWith(rule.append)) {
      return null;
    }
    final beforeAppend = form.length - rule.append.length;
    if (beforeAppend == 0 && !dictionary.affixFile.fullStrip) {
      return null;
    }
    return form.substring(0, beforeAppend) + rule.strip;
  }

  /// Reconstructs the stem a `PFX` [rule] would have been applied to in
  /// order to produce surface form [form], the mirror of [_undoSuffix].
  String? _undoPrefix(String form, HunspellAffixRule rule) {
    if (!form.startsWith(rule.append)) {
      return null;
    }
    final afterAppend = rule.append.length;
    if (afterAppend == form.length && !dictionary.affixFile.fullStrip) {
      return null;
    }
    return rule.strip + form.substring(afterAppend);
  }

  /// Tries [form] as an exact dictionary hit, then under one suffix, then
  /// under one prefix, then under a prefix+suffix cross product (honouring
  /// continuation classes and `CIRCUMFIX` in the cross-product step).
  /// Returns the matched entry's flags, or `null` if none of the four
  /// apply.
  _LookupResult? _lookupExactSuffixPrefixCross(String form) {
    final exactFlags = dictionary.entries[form];
    if (exactFlags != null && _isUsableBareEntry(exactFlags)) {
      return _LookupResult(exactFlags);
    }

    for (final rule in ruleIndex.suffixRulesFor(form)) {
      if (_needsCircumfix(rule)) {
        continue;
      }
      final stem = _undoSuffix(form, rule);
      if (stem == null || !rule.condition.matchesEnd(stem)) {
        continue;
      }
      final stemFlags = dictionary.entries[stem];
      if (stemFlags == null || !_isUsableAffixStem(stemFlags)) {
        continue;
      }
      if (dictionary.affixFile.containsFlag(stemFlags, rule.flag)) {
        return _LookupResult(stemFlags);
      }
    }

    for (final rule in ruleIndex.prefixRulesFor(form)) {
      if (_needsCircumfix(rule)) {
        continue;
      }
      final stem = _undoPrefix(form, rule);
      if (stem == null || !rule.condition.matchesStart(stem)) {
        continue;
      }
      final stemFlags = dictionary.entries[stem];
      if (stemFlags == null || !_isUsableAffixStem(stemFlags)) {
        continue;
      }
      if (dictionary.affixFile.containsFlag(stemFlags, rule.flag)) {
        return _LookupResult(stemFlags);
      }
    }

    for (final prefixRule in ruleIndex.prefixRulesFor(form)) {
      if (!prefixRule.crossProduct || !form.startsWith(prefixRule.append)) {
        continue;
      }
      for (final suffixRule in ruleIndex.suffixRulesFor(form)) {
        if (!suffixRule.crossProduct || !form.endsWith(suffixRule.append)) {
          continue;
        }
        if (_needsCircumfix(prefixRule) != _needsCircumfix(suffixRule)) {
          continue;
        }
        final middleStart = prefixRule.append.length;
        final middleEnd = form.length - suffixRule.append.length;
        if (middleStart > middleEnd) {
          continue;
        }
        final stem =
            prefixRule.strip +
            form.substring(middleStart, middleEnd) +
            suffixRule.strip;
        if (!prefixRule.condition.matchesStart(stem) ||
            !suffixRule.condition.matchesEnd(stem)) {
          continue;
        }
        final stemFlags = dictionary.entries[stem];
        if (stemFlags == null || !_isUsableAffixStem(stemFlags)) {
          continue;
        }
        final prefixSatisfied =
            dictionary.affixFile.containsFlag(stemFlags, prefixRule.flag) ||
            dictionary.affixFile.containsFlag(
              suffixRule.continuationFlags,
              prefixRule.flag,
            );
        final suffixSatisfied =
            dictionary.affixFile.containsFlag(stemFlags, suffixRule.flag) ||
            dictionary.affixFile.containsFlag(
              prefixRule.continuationFlags,
              suffixRule.flag,
            );
        if (prefixSatisfied && suffixSatisfied) {
          return _LookupResult(stemFlags);
        }
      }
    }

    return null;
  }

  /// Tries every `BREAK` pattern against [word]: an unanchored pattern
  /// splits the word and requires every non-empty part to be known; an
  /// anchored pattern strips a single leading or trailing occurrence and
  /// requires the remainder to be known.
  bool _matchesBreakPatterns(String word, int depth) {
    for (final pattern in dictionary.affixFile.breakPatterns) {
      if (pattern.text.isEmpty) {
        continue;
      }
      if (pattern.anchoredStart) {
        if (!word.startsWith(pattern.text)) {
          continue;
        }
        final remainder = word.substring(pattern.text.length);
        if (remainder.isNotEmpty && _isKnownAtDepth(remainder, depth + 1)) {
          return true;
        }
      } else if (pattern.anchoredEnd) {
        if (!word.endsWith(pattern.text)) {
          continue;
        }
        final remainder = word.substring(
          0,
          word.length - pattern.text.length,
        );
        if (remainder.isNotEmpty && _isKnownAtDepth(remainder, depth + 1)) {
          return true;
        }
      } else {
        if (!word.contains(pattern.text)) {
          continue;
        }
        final parts = word.split(pattern.text);
        if (parts.length < 2) {
          continue;
        }
        final nonEmptyParts = parts.where((part) => part.isNotEmpty);
        if (nonEmptyParts.isEmpty) {
          continue;
        }
        if (nonEmptyParts.every(
          (part) => _isKnownAtDepth(part, depth + 1),
        )) {
          return true;
        }
      }
    }
    return false;
  }

  /// Whether [word] can be split into consecutive dictionary pieces
  /// matching one of the `COMPOUNDRULE` patterns.
  bool _matchesCompoundRules(String word) => dictionary.affixFile.compoundRules
      .any((rule) => _matchesCompoundRule(word, 0, rule.elements, 0));

  /// Whether [word], starting at [pos], matches [elements] from
  /// [elementIndex] onward.
  bool _matchesCompoundRule(
    String word,
    int pos,
    List<HunspellCompoundRuleElement> elements,
    int elementIndex,
  ) {
    if (elementIndex == elements.length) {
      return pos == word.length;
    }
    final element = elements[elementIndex];
    switch (element.quantifier) {
      case HunspellCompoundRuleQuantifier.one:
        return _tryConsumeCompoundPiece(
          word,
          pos,
          element.flag,
          (next) =>
              _matchesCompoundRule(word, next, elements, elementIndex + 1),
        );
      case HunspellCompoundRuleQuantifier.zeroOrOne:
        if (_matchesCompoundRule(word, pos, elements, elementIndex + 1)) {
          return true;
        }
        return _tryConsumeCompoundPiece(
          word,
          pos,
          element.flag,
          (next) =>
              _matchesCompoundRule(word, next, elements, elementIndex + 1),
        );
      case HunspellCompoundRuleQuantifier.zeroOrMore:
        if (_matchesCompoundRule(word, pos, elements, elementIndex + 1)) {
          return true;
        }
        return _tryConsumeCompoundPiece(
          word,
          pos,
          element.flag,
          (next) => _matchesCompoundRule(word, next, elements, elementIndex),
        );
    }
  }

  /// Tries every dictionary piece of at least [HunspellAffixFile.compoundMin]
  /// characters starting at [pos] that carries [flag], calling
  /// [continueWith] with the position just past it; returns `true` on the
  /// first piece for which [continueWith] itself returns `true`.
  bool _tryConsumeCompoundPiece(
    String word,
    int pos,
    String flag,
    bool Function(int next) continueWith,
  ) {
    final minLength = dictionary.affixFile.compoundMin;
    for (var length = minLength; pos + length <= word.length; length++) {
      final piece = word.substring(pos, pos + length);
      final flags = dictionary.entries[piece];
      if (flags == null || _isForbidden(flags)) {
        continue;
      }
      if (!dictionary.affixFile.containsFlag(flags, flag)) {
        continue;
      }
      if (continueWith(pos + length)) {
        return true;
      }
    }
    return false;
  }
}
