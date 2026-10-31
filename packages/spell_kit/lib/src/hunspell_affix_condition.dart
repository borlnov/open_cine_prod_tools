// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

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
  const _HunspellConditionAtom.charClass({required Set<String> members, required bool negated})
    : _literal = null,
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
