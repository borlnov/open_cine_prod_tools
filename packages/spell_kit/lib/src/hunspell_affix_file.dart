// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The quantifier a [HunspellCompoundRuleElement] carries, mirroring a
/// (tiny) regular-expression alphabet over dictionary-entry flags.
enum HunspellCompoundRuleQuantifier {
  /// The element must be matched by exactly one compound piece.
  one,

  /// The element may be matched by zero or more compound pieces, each
  /// carrying the element's flag (hunspell's `*`).
  zeroOrMore,

  /// The element may be matched by zero or one compound piece carrying the
  /// element's flag (hunspell's `?`).
  zeroOrOne,
}

/// One element of a [HunspellCompoundRule]'s pattern: a flag a compound
/// piece must carry, and how many consecutive pieces may carry it.
class HunspellCompoundRuleElement {
  /// Creates a [HunspellCompoundRuleElement].
  const HunspellCompoundRuleElement({
    required this.flag,
    required this.quantifier,
  });

  /// The flag a compound piece must carry to satisfy this element.
  final String flag;

  /// How many consecutive pieces this element accepts.
  final HunspellCompoundRuleQuantifier quantifier;
}

/// A parsed `COMPOUNDRULE` pattern: a sequence of
/// [HunspellCompoundRuleElement]s a word must be splittable into, each
/// piece drawn from the dictionary and carrying the matching element's
/// flag.
class HunspellCompoundRule {
  /// Creates a [HunspellCompoundRule].
  const HunspellCompoundRule(this.elements);

  /// The pattern's elements, in the order they must be matched.
  final List<HunspellCompoundRuleElement> elements;
}

/// A parsed `BREAK` pattern: text that splits a word into parts that must
/// each be independently known, or a leading/trailing occurrence that may
/// simply be stripped off.
class HunspellBreakPattern {
  /// Creates a [HunspellBreakPattern].
  const HunspellBreakPattern({
    required this.text,
    required this.anchoredStart,
    required this.anchoredEnd,
  });

  /// The literal text of the pattern, with its `^`/`$` anchor (if any)
  /// already stripped off.
  final String text;

  /// Whether the pattern is anchored to the start of the word (hunspell's
  /// `^p`), meaning a leading occurrence of [text] may be stripped off.
  final bool anchoredStart;

  /// Whether the pattern is anchored to the end of the word (hunspell's
  /// `p$`), meaning a trailing occurrence of [text] may be stripped off.
  final bool anchoredEnd;
}

/// A parsed `REP` line: a substitution the suggester tries when a word is
/// unknown, in the language's own idiom of common typos.
class HunspellRepRule {
  /// Creates a [HunspellRepRule].
  const HunspellRepRule({
    required this.from,
    required this.to,
    required this.anchoredStart,
    required this.anchoredEnd,
  });

  /// The text to replace (hunspell's `_` already translated to a space,
  /// and its `^`/`$` anchor, if any, already stripped off).
  final String from;

  /// The replacement text (hunspell's `_` already translated to a space).
  final String to;

  /// Whether the rule only applies at the start of the word (hunspell's
  /// `^from`).
  final bool anchoredStart;

  /// Whether the rule only applies at the end of the word (hunspell's
  /// `from$`).
  final bool anchoredEnd;
}

/// A parsed `ICONV`/`OCONV` line: a character (or short sequence)
/// substitution applied wholesale, not anchored to a position.
class HunspellConvRule {
  /// Creates a [HunspellConvRule].
  const HunspellConvRule({required this.from, required this.to});

  /// The text to replace.
  final String from;

  /// The replacement text.
  final String to;
}

/// A single atom of a compiled [HunspellAffixCondition]: either a literal
/// character (hunspell's `.` standing for "any character" even mid
/// condition), or a `[abc]`/`[^abc]` class.
class _HunspellConditionAtom {
  /// Creates an atom matching exactly [literal], or any character at all
  /// if [literal] is `.`.
  const _HunspellConditionAtom.literal(String literal)
    : _literal = literal,
      _members = null,
      _negated = false;

  /// Creates an atom matching membership of [members] (or its complement,
  /// if [negated]).
  const _HunspellConditionAtom.charClass({
    required Set<String> members,
    required bool negated,
  }) : _literal = null,
       _members = members,
       _negated = negated;

  /// The literal character this atom matches, or `null` for a class atom.
  final String? _literal;

  /// The class this atom tests membership of, or `null` for a literal atom.
  final Set<String>? _members;

  /// Whether [_members] is negated (a `[^...]` class).
  final bool _negated;

  /// Whether this atom matches the single character [char].
  bool matches(String char) {
    final members = _members;
    if (members != null) {
      final isMember = members.contains(char);
      return _negated ? !isMember : isMember;
    }
    return _literal == '.' || _literal == char;
  }
}

/// A compiled `PFX`/`SFX` rule condition: a sequence of atoms that must
/// match, in order, at the start or the end of a candidate stem.
///
/// Hunspell's bare `.` condition is not "match any single character": as
/// the whole condition it means "unconditional", matching a stem of any
/// length, including an empty one (which only arises under `FULLSTRIP`).
/// That case is compiled to a matcher with no atoms at all, kept apart from
/// a `.` that merely appears *inside* a longer condition (where it does
/// mean "any one character" at that position, like every other atom).
class HunspellAffixCondition {
  /// Creates a [HunspellAffixCondition]. Prefer [HunspellAffixCondition.parse].
  const HunspellAffixCondition._(this._atoms);

  /// Parses a hunspell condition string, for example `.`, `e` or
  /// `[^aeiou]y`.
  factory HunspellAffixCondition.parse(String condition) {
    if (condition == '.') {
      return const HunspellAffixCondition._(null);
    }
    final atoms = <_HunspellConditionAtom>[];
    var index = 0;
    while (index < condition.length) {
      if (condition[index] == '[') {
        final close = condition.indexOf(']', index);
        final end = close == -1 ? condition.length : close;
        var body = condition.substring(index + 1, end);
        final negated = body.startsWith('^');
        if (negated) {
          body = body.substring(1);
        }
        atoms.add(
          _HunspellConditionAtom.charClass(
            members: body.runes.map(String.fromCharCode).toSet(),
            negated: negated,
          ),
        );
        index = end + 1;
      } else {
        atoms.add(_HunspellConditionAtom.literal(condition[index]));
        index++;
      }
    }
    return HunspellAffixCondition._(atoms);
  }

  /// The compiled atoms, one per matched position, or `null` for the
  /// unconditional (bare `.`) condition.
  final List<_HunspellConditionAtom>? _atoms;

  /// Whether [stem] satisfies this condition when checked at its end (the
  /// position a `SFX` rule's condition is defined to match).
  bool matchesEnd(String stem) => _matches(stem, fromEnd: true);

  /// Whether [stem] satisfies this condition when checked at its start
  /// (the position a `PFX` rule's condition is defined to match).
  bool matchesStart(String stem) => _matches(stem, fromEnd: false);

  /// The shared implementation of [matchesEnd] and [matchesStart].
  bool _matches(String stem, {required bool fromEnd}) {
    final atoms = _atoms;
    if (atoms == null) {
      return true;
    }
    if (stem.length < atoms.length) {
      return false;
    }
    final offset = fromEnd ? stem.length - atoms.length : 0;
    for (var i = 0; i < atoms.length; i++) {
      if (!atoms[i].matches(stem[offset + i])) {
        return false;
      }
    }
    return true;
  }
}

/// A single `PFX`/`SFX` rule line: how to turn a dictionary stem into a
/// surface form (or, read the other way round, how affix stripping tries
/// to turn a typed word back into one).
class HunspellAffixRule {
  /// Creates a [HunspellAffixRule].
  const HunspellAffixRule({
    required this.flag,
    required this.strip,
    required this.append,
    required this.continuationFlags,
    required this.condition,
    required this.crossProduct,
  });

  /// The flag identifying this rule; a dictionary entry must carry it (or
  /// receive it through a continuation class) to accept the rule.
  final String flag;

  /// The text removed from the end (`SFX`) or start (`PFX`) of the
  /// dictionary stem to build the surface form (empty for hunspell's `0`).
  final String strip;

  /// The text added to the end (`SFX`) or start (`PFX`) of the dictionary
  /// stem to build the surface form (empty for hunspell's `0`).
  final String append;

  /// The flags this rule grants to the surface form it builds, in addition
  /// to the base stem's own flags — what lets, for example, a suffix rule
  /// applied with no visible text change still make a prefix flag
  /// available for a cross-product combination.
  final String continuationFlags;

  /// The condition [strip]'s removal (equivalently, the reconstructed
  /// stem) must satisfy.
  final HunspellAffixCondition condition;

  /// Whether this rule may combine with a rule of the other affix kind
  /// (the header line's `Y`/`N`).
  final bool crossProduct;
}

/// A parsed hunspell `.aff` affix file.
///
/// Parsing is a single forward pass over the source lines that remembers
/// the block header currently open (a `PFX`/`SFX` header, or a counted
/// block like `MAP`/`REP`/`ICONV`/`OCONV`/`BREAK`/`COMPOUNDRULE`) instead of
/// rescanning earlier lines to find it — rescanning backwards for every
/// rule line is what made a throw-away spike's French load cost 621 ms.
class HunspellAffixFile {
  /// Creates a [HunspellAffixFile]. Prefer [HunspellAffixFile.parse].
  const HunspellAffixFile({
    required this.flagLong,
    required this.tryChars,
    required this.wordChars,
    required this.mapGroups,
    required this.repRules,
    required this.iconvRules,
    required this.oconvRules,
    required this.noSuggestFlag,
    required this.needAffixFlag,
    required this.circumfixFlag,
    required this.keepCaseFlag,
    required this.forbiddenWordFlag,
    required this.onlyInCompoundFlag,
    required this.fullStrip,
    required this.compoundMin,
    required this.compoundRules,
    required this.breakPatterns,
    required this.prefixRules,
    required this.suffixRules,
  });

  /// Parses [source] into a [HunspellAffixFile].
  ///
  /// `SET` and `KEY` are recognized and otherwise ignored: this engine
  /// never needs the input encoding (the caller always hands it a decoded
  /// `String`) or the keyboard-adjacency table (used only by hunspell's
  /// `n`-gram suggestion tier, which this package does not implement).
  factory HunspellAffixFile.parse(String source) {
    var flagLong = false;
    var tryChars = '';
    var wordChars = '';
    final mapGroups = <String>[];
    final repRules = <HunspellRepRule>[];
    final iconvRules = <HunspellConvRule>[];
    final oconvRules = <HunspellConvRule>[];
    String? noSuggestFlag;
    String? needAffixFlag;
    String? circumfixFlag;
    String? keepCaseFlag;
    String? forbiddenWordFlag;
    String? onlyInCompoundFlag;
    var fullStrip = false;
    var compoundMin = 3;
    final compoundRulePatterns = <String>[];
    final breakPatternLines = <String>[];
    var breakDeclared = false;
    final prefixRules = <HunspellAffixRule>[];
    final suffixRules = <HunspellAffixRule>[];

    _PendingAffixBlock? pendingAffix;
    _PendingCountedBlock? pendingCounted;

    for (final rawLine in source.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) {
        continue;
      }

      final affixBlock = pendingAffix;
      if (affixBlock != null) {
        final rule = _parseAffixRuleLine(line);
        (affixBlock.kind == 'PFX' ? prefixRules : suffixRules).add(
          HunspellAffixRule(
            flag: affixBlock.flag,
            strip: rule.strip,
            append: rule.append,
            continuationFlags: rule.continuationFlags,
            condition: HunspellAffixCondition.parse(rule.condition),
            crossProduct: affixBlock.crossProduct,
          ),
        );
        affixBlock.remaining--;
        if (affixBlock.remaining == 0) {
          pendingAffix = null;
        }
        continue;
      }

      final counted = pendingCounted;
      if (counted != null) {
        counted.onLine(_valueAfterKeyword(line));
        counted.remaining--;
        if (counted.remaining == 0) {
          pendingCounted = null;
        }
        continue;
      }

      final spaceIndex = line.indexOf(RegExp(r'\s'));
      final keyword = spaceIndex == -1 ? line : line.substring(0, spaceIndex);
      final value = spaceIndex == -1
          ? ''
          : line.substring(spaceIndex + 1).trim();

      switch (keyword) {
        case 'FLAG':
          flagLong = value == 'long';
        case 'TRY':
          tryChars = value;
        case 'WORDCHARS':
          wordChars = value;
        case 'MAP':
          pendingCounted = _PendingCountedBlock(
            remaining: int.parse(value),
            onLine: mapGroups.add,
          );
        case 'REP':
          pendingCounted = _PendingCountedBlock(
            remaining: int.parse(value),
            onLine: (line) => repRules.add(_parseRepLine(line)),
          );
        case 'ICONV':
          pendingCounted = _PendingCountedBlock(
            remaining: int.parse(value),
            onLine: (line) => iconvRules.add(_parseConvLine(line)),
          );
        case 'OCONV':
          pendingCounted = _PendingCountedBlock(
            remaining: int.parse(value),
            onLine: (line) => oconvRules.add(_parseConvLine(line)),
          );
        case 'BREAK':
          breakDeclared = true;
          final count = int.parse(value);
          if (count > 0) {
            pendingCounted = _PendingCountedBlock(
              remaining: count,
              onLine: breakPatternLines.add,
            );
          }
        case 'COMPOUNDRULE':
          final count = int.parse(value);
          if (count > 0) {
            pendingCounted = _PendingCountedBlock(
              remaining: count,
              onLine: compoundRulePatterns.add,
            );
          }
        case 'COMPOUNDMIN':
          compoundMin = int.parse(value);
        case 'NOSUGGEST':
          noSuggestFlag = value;
        case 'NEEDAFFIX':
          needAffixFlag = value;
        case 'CIRCUMFIX':
          circumfixFlag = value;
        case 'KEEPCASE':
          keepCaseFlag = value;
        case 'FORBIDDENWORD':
          forbiddenWordFlag = value;
        case 'ONLYINCOMPOUND':
          onlyInCompoundFlag = value;
        case 'FULLSTRIP':
          fullStrip = true;
        case 'PFX':
        case 'SFX':
          final tokens = value.split(RegExp(r'\s+'));
          pendingAffix = _PendingAffixBlock(
            kind: keyword,
            flag: tokens[0],
            crossProduct: tokens[1] == 'Y',
            remaining: int.parse(tokens[2]),
          );
        default:
        // An unrecognized directive (SET, KEY, or a future addition
        // neither bundled dictionary uses) is intentionally ignored.
      }
    }

    return HunspellAffixFile(
      flagLong: flagLong,
      tryChars: tryChars,
      wordChars: wordChars,
      mapGroups: mapGroups,
      repRules: repRules,
      iconvRules: iconvRules,
      oconvRules: oconvRules,
      noSuggestFlag: noSuggestFlag,
      needAffixFlag: needAffixFlag,
      circumfixFlag: circumfixFlag,
      keepCaseFlag: keepCaseFlag,
      forbiddenWordFlag: forbiddenWordFlag,
      onlyInCompoundFlag: onlyInCompoundFlag,
      fullStrip: fullStrip,
      compoundMin: compoundMin,
      compoundRules: compoundRulePatterns
          .map((pattern) => _parseCompoundRule(pattern, flagLong: flagLong))
          .toList(),
      breakPatterns: breakDeclared
          ? breakPatternLines.map(_parseBreakPattern).toList()
          : _defaultBreakPatterns,
      prefixRules: prefixRules,
      suffixRules: suffixRules,
    );
  }

  /// Hunspell's documented default `BREAK` set, in force whenever a `.aff`
  /// file declares no `BREAK` directive at all (an explicit `BREAK 0` is a
  /// different thing: it means no breaking, and is represented as an empty
  /// [breakPatterns] rather than falling back to this default).
  static final List<HunspellBreakPattern> _defaultBreakPatterns = [
    _parseBreakPattern('-'),
    _parseBreakPattern('^-'),
    _parseBreakPattern(r'-$'),
  ];

  /// Whether flags are two characters wide (`FLAG long`) rather than one.
  ///
  /// Hunspell's other two widths, `num` (decimal flag numbers separated by
  /// commas) and `UTF-8` (a single UTF-8-encoded character), are used by
  /// neither bundled dictionary; a `FLAG` value other than `long` is
  /// treated as the single-character default.
  final bool flagLong;

  /// The characters tried, in order, when generating a one-edit suggestion.
  final String tryChars;

  /// Extra characters (beyond letters) a word may be made of, as declared
  /// by `WORDCHARS`.
  final String wordChars;

  /// Each `MAP` group: a run of characters the suggester treats as mutually
  /// interchangeable (typically a base letter and its accented forms).
  final List<String> mapGroups;

  /// The `REP` substitution table, in the file's own declared order.
  final List<HunspellRepRule> repRules;

  /// The `ICONV` table, applied to a word before every lookup.
  final List<HunspellConvRule> iconvRules;

  /// The `OCONV` table. Parsed and exposed, but never applied by this
  /// package: a suggestion is inserted into the writer's own text, and
  /// silently converting, for example, `'` to `’` would be an edit the
  /// writer never asked for.
  final List<HunspellConvRule> oconvRules;

  /// The flag marking a dictionary entry as valid but never suggested, or
  /// `null` if the file declares none.
  final String? noSuggestFlag;

  /// The flag marking a dictionary entry as not a word by itself — only
  /// valid once an affix has applied to it — or `null` if the file
  /// declares none.
  final String? needAffixFlag;

  /// The flag marking a prefix or suffix rule as usable only alongside its
  /// circumfix partner, or `null` if the file declares none.
  final String? circumfixFlag;

  /// The flag marking a dictionary entry as matching only its exact typed
  /// casing, or `null` if the file declares none.
  final String? keepCaseFlag;

  /// The flag marking a dictionary entry as never known, however it is
  /// typed, or `null` if the file declares none.
  final String? forbiddenWordFlag;

  /// The flag marking a dictionary entry as usable only as a
  /// `COMPOUNDRULE` piece, never bare and never as an affix stem, or `null`
  /// if the file declares none.
  final String? onlyInCompoundFlag;

  /// Whether a `PFX`/`SFX` rule's `strip` may consume an entire stem,
  /// leaving nothing of the original word before the affix was applied.
  final bool fullStrip;

  /// The minimum length, in characters, of every piece of a
  /// `COMPOUNDRULE` match (hunspell's default is 3).
  final int compoundMin;

  /// The parsed `COMPOUNDRULE` patterns.
  final List<HunspellCompoundRule> compoundRules;

  /// The effective `BREAK` patterns: either the file's own, an explicit
  /// empty list for a declared `BREAK 0`, or [_defaultBreakPatterns] when
  /// the file declares no `BREAK` directive at all.
  final List<HunspellBreakPattern> breakPatterns;

  /// Every parsed `PFX` rule, across every flag.
  final List<HunspellAffixRule> prefixRules;

  /// Every parsed `SFX` rule, across every flag.
  final List<HunspellAffixRule> suffixRules;

  /// Whether [flags] (a dictionary entry's or a rule's raw, concatenated
  /// flag string) contains [flag], striding one or two characters at a
  /// time depending on [flagLong].
  bool containsFlag(String flags, String? flag) {
    if (flag == null || flag.isEmpty) {
      return false;
    }
    final width = flagLong ? 2 : 1;
    for (var i = 0; i + width <= flags.length; i += width) {
      if (flags.startsWith(flag, i)) {
        return true;
      }
    }
    return false;
  }
}

/// The state carried forward while a `PFX`/`SFX` block's rule lines are
/// being read, remembered rather than re-derived from earlier lines.
class _PendingAffixBlock {
  /// Creates a [_PendingAffixBlock] for a just-read header line.
  _PendingAffixBlock({
    required this.kind,
    required this.flag,
    required this.crossProduct,
    required this.remaining,
  });

  /// `'PFX'` or `'SFX'`.
  final String kind;

  /// The block's flag, shared by every rule line under this header.
  final String flag;

  /// The block's cross-product flag (the header line's `Y`/`N`).
  final bool crossProduct;

  /// How many more rule lines are expected before this block closes.
  int remaining;
}

/// The state carried forward while a counted block (`MAP`, `REP`, `ICONV`,
/// `OCONV`, `BREAK`, `COMPOUNDRULE`) is being read.
class _PendingCountedBlock {
  /// Creates a [_PendingCountedBlock] for a just-read header line.
  _PendingCountedBlock({required this.remaining, required this.onLine});

  /// How many more data lines are expected before this block closes.
  int remaining;

  /// Called with each data line's value (the keyword already stripped).
  final void Function(String line) onLine;
}

/// Returns the part of [line] after its first whitespace-delimited token
/// (the keyword), trimmed.
String _valueAfterKeyword(String line) {
  final spaceIndex = line.indexOf(RegExp(r'\s'));
  return spaceIndex == -1 ? '' : line.substring(spaceIndex + 1).trim();
}

/// The strip/append/continuation-flags/condition fields of one `PFX`/`SFX`
/// rule line, before the append text and continuation flags have been
/// pulled apart from each other.
class _ParsedAffixRuleLine {
  /// Creates a [_ParsedAffixRuleLine].
  const _ParsedAffixRuleLine({
    required this.strip,
    required this.append,
    required this.continuationFlags,
    required this.condition,
  });

  /// The text to strip (empty for hunspell's `0`).
  final String strip;

  /// The text to append (empty for hunspell's `0`).
  final String append;

  /// The continuation flags carried after a `/` in the append field, or
  /// empty if there were none.
  final String continuationFlags;

  /// The raw (not yet compiled) condition text.
  final String condition;
}

/// Parses one `PFX`/`SFX` rule line's fields, given [line] with the block's
/// `PFX`/`SFX` and flag tokens still on it (`PFX L' 0 l' .`). Trailing
/// morphological fields, which neither bundled dictionary's affix file
/// uses, are dropped along with everything past the condition token.
_ParsedAffixRuleLine _parseAffixRuleLine(String line) {
  final tokens = line.split(RegExp(r'\s+'));
  // tokens[0] is 'PFX'/'SFX', tokens[1] is the flag: both already known to
  // the caller from the open block, so only tokens[2..4] are read here.
  final strip = tokens[2] == '0' ? '' : tokens[2];
  final appendField = tokens[3];
  final slashIndex = appendField.indexOf('/');
  final String append;
  final String continuationFlags;
  if (slashIndex == -1) {
    append = appendField == '0' ? '' : appendField;
    continuationFlags = '';
  } else {
    final appendText = appendField.substring(0, slashIndex);
    append = appendText == '0' ? '' : appendText;
    continuationFlags = appendField.substring(slashIndex + 1);
  }
  final condition = tokens.length > 4 ? tokens[4] : '.';
  return _ParsedAffixRuleLine(
    strip: strip,
    append: append,
    continuationFlags: continuationFlags,
    condition: condition,
  );
}

/// Parses one `REP` data line (`from to`, `_` standing for a space and
/// `^`/`$` anchoring either end) into a [HunspellRepRule].
HunspellRepRule _parseRepLine(String line) {
  final tokens = line.split(RegExp(r'\s+'));
  var from = tokens[0].replaceAll('_', ' ');
  final to = tokens.length > 1 ? tokens[1].replaceAll('_', ' ') : '';
  final anchoredStart = from.startsWith('^');
  if (anchoredStart) {
    from = from.substring(1);
  }
  final anchoredEnd = from.endsWith(r'$');
  if (anchoredEnd) {
    from = from.substring(0, from.length - 1);
  }
  return HunspellRepRule(
    from: from,
    to: to,
    anchoredStart: anchoredStart,
    anchoredEnd: anchoredEnd,
  );
}

/// Parses one `ICONV`/`OCONV` data line (`from to`) into a
/// [HunspellConvRule].
HunspellConvRule _parseConvLine(String line) {
  final tokens = line.split(RegExp(r'\s+'));
  return HunspellConvRule(
    from: tokens[0],
    to: tokens.length > 1 ? tokens[1] : '',
  );
}

/// Parses one `BREAK` data line into a [HunspellBreakPattern], splitting
/// off a leading `^` or trailing `$` anchor if present.
HunspellBreakPattern _parseBreakPattern(String raw) {
  var text = raw;
  final anchoredStart = text.startsWith('^');
  if (anchoredStart) {
    text = text.substring(1);
  }
  final anchoredEnd = text.endsWith(r'$');
  if (anchoredEnd) {
    text = text.substring(0, text.length - 1);
  }
  return HunspellBreakPattern(
    text: text,
    anchoredStart: anchoredStart,
    anchoredEnd: anchoredEnd,
  );
}

/// Parses one `COMPOUNDRULE` pattern (for example `n*1t`) into a
/// [HunspellCompoundRule], reading each flag as one character, or as two
/// (bare, or grouped in parentheses to disambiguate) when [flagLong] holds.
HunspellCompoundRule _parseCompoundRule(String pattern, {required bool flagLong}) {
  final elements = <HunspellCompoundRuleElement>[];
  var index = 0;
  while (index < pattern.length) {
    String flag;
    if (pattern[index] == '(') {
      final close = pattern.indexOf(')', index);
      final end = close == -1 ? pattern.length : close;
      flag = pattern.substring(index + 1, end);
      index = end + 1;
    } else if (flagLong) {
      final width = index + 2 <= pattern.length ? 2 : pattern.length - index;
      flag = pattern.substring(index, index + width);
      index += width;
    } else {
      flag = pattern[index];
      index++;
    }
    var quantifier = HunspellCompoundRuleQuantifier.one;
    if (index < pattern.length) {
      if (pattern[index] == '*') {
        quantifier = HunspellCompoundRuleQuantifier.zeroOrMore;
        index++;
      } else if (pattern[index] == '?') {
        quantifier = HunspellCompoundRuleQuantifier.zeroOrOne;
        index++;
      }
    }
    elements.add(HunspellCompoundRuleElement(flag: flag, quantifier: quantifier));
  }
  return HunspellCompoundRule(elements);
}
