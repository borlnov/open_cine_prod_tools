// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The digits a fractional key is written with, in ascending ASCII order.
///
/// Base 62, `0-9A-Za-z`, listed in the very order their code units compare in: that is what makes
/// a plain lexicographic string comparison — which is all SQLite's `ORDER BY` does on a `TEXT`
/// column — agree with the numeric order of the fraction each key denotes.
const _ocptFractionalKeyDigits =
    "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";

/// The base fractional keys are written in: the number of [_ocptFractionalKeyDigits].
const _ocptFractionalKeyBase = 62;

/// How many free slots a fresh [ocptFractionalKeySequence] leaves between two neighbours, at the
/// width it picks.
///
/// Keys can always be inserted between two neighbours by growing one digit longer (that is the
/// whole point of a fractional index), but a sequence that packed its keys one apart would force
/// that on the very first insertion anywhere. Spreading them out costs nothing at write time and
/// keeps the common insertions short.
const _ocptFractionalKeySequenceSpread = 4;

/// A key strictly between [before] and [after], for the `sortKey` column of an ordered table.
///
/// A null [before] means "no lower bound" (inserting at the head of the group), a null [after]
/// means "no upper bound" (appending at the tail); both null yields the first key of an empty
/// group. This is what lets an insertion or a move write **exactly one row**, where a dense
/// `0, 1, 2, …` numbering has to rewrite every row after the one that moved (see
/// `docs/adr/0010-sync-ready-data-model-prerequisites.md`).
///
/// The returned key never ends with the lowest digit, and that is a load-bearing property rather
/// than a cosmetic one: nothing can be inserted between a key `k` and the key `k + "0"`, since no
/// non-empty string of these digits sorts below `"0"`. Every key this library produces — here and
/// in [ocptFractionalKeySequence] — therefore keeps room below it, so any two of them always have
/// somewhere for a third to go.
///
/// Throws an [ArgumentError] if [before] is not strictly below [after].
String ocptFractionalKeyBetween({String? before, String? after}) {
  if (before != null && after != null && before.compareTo(after) >= 0) {
    throw ArgumentError(
      "A fractional key can only be allocated between two keys in ascending order "
      "(before: $before, after: $after)",
    );
  }

  final lower = before ?? "";
  // Dropped as soon as the key being built is known to sort strictly below `after`: from that
  // point on, whatever `after` holds further right cannot constrain the digits left to pick.
  var upper = after;
  final key = StringBuffer();

  for (var i = 0; ; i++) {
    if (upper != null && i >= upper.length) {
      // Every digit picked so far matched `after`'s, and `after` has none left: there is genuinely
      // nothing between these two, which can only happen if `after` ends with the lowest digit (or
      // is empty). No key this library hands out ever does — see the doc comment above.
      throw ArgumentError("No fractional key fits between '$before' and '$after'");
    }

    final lowerDigit = i < lower.length ? _digitAt(lower, i) : 0;
    final upperDigit = upper != null ? _digitAt(upper, i) : _ocptFractionalKeyBase;

    if (lowerDigit + 1 < upperDigit) {
      key.write(_ocptFractionalKeyDigits[(lowerDigit + upperDigit) ~/ 2]);
      return key.toString();
    }

    key.write(_ocptFractionalKeyDigits[lowerDigit]);
    if (upper != null && lowerDigit != upperDigit) {
      upper = null;
    }
  }
}

/// [count] keys in strictly ascending order, evenly spread, for backfilling a whole group at once.
///
/// This is what the schema v3 migration writes over the rows an older build ordered by `position`
/// alone, and what any other bulk (re)keying of a whole group should use: allocating a group's
/// keys one [ocptFractionalKeyBetween] call at a time would work, but each call lands halfway
/// between its predecessor and the end, so the keys would grow a digit longer every handful of
/// rows.
List<String> ocptFractionalKeySequence(int count) {
  if (count <= 0) {
    return const [];
  }

  var width = 1;
  var capacity = _ocptFractionalKeyBase;
  while (capacity < (count + 1) * _ocptFractionalKeySequenceSpread) {
    width++;
    capacity *= _ocptFractionalKeyBase;
  }

  final step = capacity ~/ (count + 1);

  return [
    for (var i = 1; i <= count; i++) _encode(_withRoomBelow(step * i), width),
  ];
}

/// [count] keys in strictly ascending order, all strictly between [after] and [before]'s bounds.
///
/// Each key is allocated against the one before it, so the whole run stays inside the gap it was
/// asked for. A null bound means that side is open, exactly as in [ocptFractionalKeyBetween].
List<String> ocptFractionalKeysBetween({
  required int count,
  String? before,
  String? after,
}) {
  final keys = <String>[];
  var previous = before;

  for (var i = 0; i < count; i++) {
    final key = ocptFractionalKeyBetween(before: previous, after: after);
    keys.add(key);
    previous = key;
  }

  return keys;
}

/// The smallest set of `sortKey` writes that puts a group into the order [currentKeys] lists it
/// in, as a map from an index of [currentKeys] to the key that row must be given.
///
/// [currentKeys] holds the group's rows' current keys, **listed in the order the group must end up
/// in**. Rows absent from the returned map keep the key they already have. Moving one row of a
/// group therefore writes exactly that one row, which is the whole point of a fractional index:
/// the rows a reorder leaves alone are the longest run of them that is already in ascending order,
/// so nothing else can do better.
Map<int, String> ocptFractionalKeyRekeyPlan(List<String> currentKeys) {
  final untouched = _longestAscendingSubsequence(currentKeys);
  final plan = <int, String>{};

  var firstToRekey = 0;
  String? lowerBound;

  // The sentinel past the end closes the last run, whose upper bound is open.
  for (final boundIndex in [...untouched, currentKeys.length]) {
    final upperBound = boundIndex < currentKeys.length ? currentKeys[boundIndex] : null;
    final toRekey = boundIndex - firstToRekey;

    if (toRekey > 0) {
      final keys = ocptFractionalKeysBetween(
        count: toRekey,
        before: lowerBound,
        after: upperBound,
      );
      for (var i = 0; i < toRekey; i++) {
        plan[firstToRekey + i] = keys[i];
      }
    }

    firstToRekey = boundIndex + 1;
    lowerBound = upperBound;
  }

  return plan;
}

/// The indexes of a longest strictly ascending subsequence of [keys], in ascending index order.
///
/// Patience sorting: `tails` holds, for each length of subsequence found so far, the index of the
/// smallest key that can end one, and `previousOf` threads each index back to its predecessor so
/// the subsequence itself can be read back out at the end.
List<int> _longestAscendingSubsequence(List<String> keys) {
  final tails = <int>[];
  final previousOf = List<int>.filled(keys.length, -1);

  for (var i = 0; i < keys.length; i++) {
    final length = _ascendingTails(tails, keys, keys[i]);
    previousOf[i] = length > 0 ? tails[length - 1] : -1;

    if (length == tails.length) {
      tails.add(i);
    } else {
      tails[length] = i;
    }
  }

  final subsequence = <int>[];
  for (var i = tails.isEmpty ? -1 : tails.last; i >= 0; i = previousOf[i]) {
    subsequence.add(i);
  }

  return subsequence.reversed.toList(growable: false);
}

/// How many entries of [tails] end on a key strictly below [key]: the length of the longest
/// ascending subsequence [key] can be appended to, found by binary search since [tails] is itself
/// ascending by construction.
int _ascendingTails(List<int> tails, List<String> keys, String key) {
  var low = 0;
  var high = tails.length;

  while (low < high) {
    final middle = (low + high) ~/ 2;
    if (keys[tails[middle]].compareTo(key) < 0) {
      low = middle + 1;
    } else {
      high = middle;
    }
  }

  return low;
}

/// [value] nudged up to the next index whose lowest digit isn't zero.
///
/// See [ocptFractionalKeyBetween] for why a key must never end with the lowest digit. The nudge is
/// always by one, and [ocptFractionalKeySequence] spaces its indexes several apart, so it can
/// never reach the next key of the sequence.
int _withRoomBelow(int value) => value % _ocptFractionalKeyBase == 0 ? value + 1 : value;

/// [value] written in base [_ocptFractionalKeyBase], left-padded with the lowest digit to exactly
/// [width] digits.
///
/// Every key of a sequence sharing one width is what keeps them comparable digit by digit, and
/// keeps none of them a prefix of another.
String _encode(int value, int width) {
  final digits = List<String>.filled(width, _ocptFractionalKeyDigits[0]);
  var remainder = value;

  for (var i = width - 1; i >= 0 && remainder > 0; i--) {
    digits[i] = _ocptFractionalKeyDigits[remainder % _ocptFractionalKeyBase];
    remainder ~/= _ocptFractionalKeyBase;
  }

  return digits.join();
}

/// The value of the digit at [index] in [key].
///
/// Throws an [ArgumentError] if that character isn't one of [_ocptFractionalKeyDigits]: a key that
/// isn't a fractional key at all would otherwise silently allocate around a digit value of -1.
int _digitAt(String key, int index) {
  final digit = _ocptFractionalKeyDigits.indexOf(key[index]);
  if (digit < 0) {
    throw ArgumentError("'$key' isn't a fractional key: '${key[index]}' isn't one of its digits");
  }

  return digit;
}
