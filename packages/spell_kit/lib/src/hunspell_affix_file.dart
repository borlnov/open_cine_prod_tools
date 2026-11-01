// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0
import 'package:spell_kit/src/hunspell_affix_condition.dart';
import 'package:spell_kit/src/hunspell_affix_rule.dart';
import 'package:spell_kit/src/hunspell_break_pattern.dart';
import 'package:spell_kit/src/hunspell_compound_rule.dart';
import 'package:spell_kit/src/hunspell_compound_rule_element.dart';
import 'package:spell_kit/src/hunspell_compound_rule_quantifier.dart';
import 'package:spell_kit/src/hunspell_conv_rule.dart';
import 'package:spell_kit/src/hunspell_rep_rule.dart';

/// A parsed hunspell `.aff` affix file.
///
/// Parsing is a single forward pass over the source lines that remembers
/// the block header currently open (a `PFX`/`SFX` header, or a counted
/// block like `MAP`/`REP`/`ICONV`/`OCONV`/`BREAK`/`COMPOUNDRULE`) instead of
/// rescanning earlier lines to find it — rescanning backwards for every
/// rule line is what made a throw-away spike's French load cost 621 ms.
class HunspellAffixFile {
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
      final value = spaceIndex == -1 ? '' : line.substring(spaceIndex + 1).trim();

      switch (keyword) {
        case 'FLAG':
          flagLong = value == 'long';
        case 'TRY':
          tryChars = value;
        case 'WORDCHARS':
          wordChars = value;
        case 'MAP':
          pendingCounted = _PendingCountedBlock(remaining: int.parse(value), onLine: mapGroups.add);
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
            pendingCounted = _PendingCountedBlock(remaining: count, onLine: breakPatternLines.add);
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
  /// `'PFX'` or `'SFX'`.
  final String kind;

  /// The block's flag, shared by every rule line under this header.
  final String flag;

  /// The block's cross-product flag (the header line's `Y`/`N`).
  final bool crossProduct;

  /// How many more rule lines are expected before this block closes.
  int remaining;

  /// Creates a [_PendingAffixBlock] for a just-read header line.
  _PendingAffixBlock({
    required this.kind,
    required this.flag,
    required this.crossProduct,
    required this.remaining,
  });
}

/// The state carried forward while a counted block (`MAP`, `REP`, `ICONV`,
/// `OCONV`, `BREAK`, `COMPOUNDRULE`) is being read.
class _PendingCountedBlock {
  /// How many more data lines are expected before this block closes.
  int remaining;

  /// Called with each data line's value (the keyword already stripped).
  final void Function(String line) onLine;

  /// Creates a [_PendingCountedBlock] for a just-read header line.
  _PendingCountedBlock({required this.remaining, required this.onLine});
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
  /// The text to strip (empty for hunspell's `0`).
  final String strip;

  /// The text to append (empty for hunspell's `0`).
  final String append;

  /// The continuation flags carried after a `/` in the append field, or
  /// empty if there were none.
  final String continuationFlags;

  /// The raw (not yet compiled) condition text.
  final String condition;

  /// Creates a [_ParsedAffixRuleLine].
  const _ParsedAffixRuleLine({
    required this.strip,
    required this.append,
    required this.continuationFlags,
    required this.condition,
  });
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
  return HunspellConvRule(from: tokens[0], to: tokens.length > 1 ? tokens[1] : '');
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
  return HunspellBreakPattern(text: text, anchoredStart: anchoredStart, anchoredEnd: anchoredEnd);
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
