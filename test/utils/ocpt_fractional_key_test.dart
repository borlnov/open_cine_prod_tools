// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/utils/ocpt_fractional_key.dart';

void main() {
  group("ocptFractionalKeyBetween", () {
    test("with no bounds at all yields the first key of an empty group", () {
      final key = ocptFractionalKeyBetween();

      expect(key, isNotEmpty);
      // The lowest digit is what nothing can be inserted below, so a key must never end on it.
      expect(key.endsWith("0"), isFalse);
    });

    test("at the head sorts strictly below the key it was given", () {
      final tail = ocptFractionalKeyBetween();
      final head = ocptFractionalKeyBetween(after: tail);

      expect(head.compareTo(tail), lessThan(0));
    });

    test("at the tail sorts strictly above the key it was given", () {
      final head = ocptFractionalKeyBetween();
      final tail = ocptFractionalKeyBetween(before: head);

      expect(tail.compareTo(head), greaterThan(0));
    });

    test("between two neighbours sorts strictly between them", () {
      final first = ocptFractionalKeyBetween();
      final third = ocptFractionalKeyBetween(before: first);
      final second = ocptFractionalKeyBetween(before: first, after: third);

      expect(first.compareTo(second), lessThan(0));
      expect(second.compareTo(third), lessThan(0));
    });

    test("repeated insertions between the same pair always find room", () {
      final lower = ocptFractionalKeyBetween();
      final upper = ocptFractionalKeyBetween(before: lower);

      // Each insertion lands between the previous one and the same upper bound, so the gap halves
      // every time: this is exactly the case a fixed-width index runs out of room on.
      var previous = lower;
      final inserted = <String>[];
      for (var i = 0; i < 50; i++) {
        final key = ocptFractionalKeyBetween(before: previous, after: upper);
        expect(key.compareTo(previous), greaterThan(0));
        expect(key.compareTo(upper), lessThan(0));
        inserted.add(key);
        previous = key;
      }

      expect(inserted.toSet(), hasLength(inserted.length));
      expect([...inserted]..sort(), inserted);
    });

    test("insertions at the head, one after another, always find room", () {
      var lowest = ocptFractionalKeyBetween();

      for (var i = 0; i < 50; i++) {
        final key = ocptFractionalKeyBetween(after: lowest);
        expect(key.compareTo(lowest), lessThan(0));
        lowest = key;
      }
    });

    test("throws when the bounds are not in ascending order", () {
      expect(() => ocptFractionalKeyBetween(before: "V", after: "V"), throwsArgumentError);
      expect(() => ocptFractionalKeyBetween(before: "W", after: "V"), throwsArgumentError);
    });

    test("throws rather than returning a key outside bounds nothing fits between", () {
      // Nothing sorts strictly between "V" and "V0": no non-empty string of these digits is below
      // the lowest digit. No key this library hands out ends on it, which is why this can only be
      // reached by passing one in.
      expect(() => ocptFractionalKeyBetween(before: "V", after: "V0"), throwsArgumentError);
      expect(() => ocptFractionalKeyBetween(after: ""), throwsArgumentError);
    });

    test("rejects a bound that isn't written in its digits", () {
      expect(() => ocptFractionalKeyBetween(before: "-"), throwsArgumentError);
    });
  });

  group("ocptFractionalKeySequence", () {
    test("of nothing is empty", () {
      expect(ocptFractionalKeySequence(0), isEmpty);
      expect(ocptFractionalKeySequence(-1), isEmpty);
    });

    for (final count in [1, 2, 3, 61, 62, 63, 500]) {
      test("of $count keys is strictly ascending, distinct, and leaves room below each", () {
        final keys = ocptFractionalKeySequence(count);

        expect(keys, hasLength(count));
        expect(keys.toSet(), hasLength(count));
        expect([...keys]..sort(), keys);
        expect(keys.every((key) => !key.endsWith("0")), isTrue);
        // Every key of one sequence shares a width, so none of them is a prefix of another.
        expect(keys.map((key) => key.length).toSet(), hasLength(1));
      });
    }

    test("leaves room to insert between any two of its keys, and around them", () {
      final keys = ocptFractionalKeySequence(20);

      for (var i = 0; i < keys.length - 1; i++) {
        final inserted = ocptFractionalKeyBetween(before: keys[i], after: keys[i + 1]);
        expect(inserted.compareTo(keys[i]), greaterThan(0));
        expect(inserted.compareTo(keys[i + 1]), lessThan(0));
      }

      expect(ocptFractionalKeyBetween(after: keys.first).compareTo(keys.first), lessThan(0));
      expect(ocptFractionalKeyBetween(before: keys.last).compareTo(keys.last), greaterThan(0));
    });
  });

  group("ocptFractionalKeyRekeyPlan", () {
    test("of an order nothing has to change writes nothing", () {
      expect(ocptFractionalKeyRekeyPlan(ocptFractionalKeySequence(5)), isEmpty);
      expect(ocptFractionalKeyRekeyPlan(const []), isEmpty);
    });

    /// Applies [plan] to [keys] and returns the keys the group ends up with, in target order.
    List<String> applied(List<String> keys, Map<int, String> plan) => [
      for (var i = 0; i < keys.length; i++) plan[i] ?? keys[i],
    ];

    test("moving one row to the front rewrites that one row only", () {
      final keys = ocptFractionalKeySequence(5);
      // Target order: the last row first, everything else unchanged behind it.
      final target = [keys.last, ...keys.take(4)];

      final plan = ocptFractionalKeyRekeyPlan(target);

      expect(plan.keys, [0]);
      final result = applied(target, plan);
      expect([...result]..sort(), result);
    });

    test("moving one row into the middle rewrites that one row only", () {
      final keys = ocptFractionalKeySequence(5);
      final target = [keys[0], keys[4], keys[1], keys[2], keys[3]];

      final plan = ocptFractionalKeyRekeyPlan(target);

      expect(plan.keys, [1]);
      final result = applied(target, plan);
      expect([...result]..sort(), result);
    });

    test("a full reversal still comes out strictly ascending", () {
      final keys = ocptFractionalKeySequence(6);
      final target = keys.reversed.toList(growable: false);

      final plan = ocptFractionalKeyRekeyPlan(target);

      final result = applied(target, plan);
      expect([...result]..sort(), result);
      expect(result.toSet(), hasLength(result.length));
    });

    test("rows sharing a key are pulled apart", () {
      final plan = ocptFractionalKeyRekeyPlan(const ["V", "V", "V"]);

      final result = applied(const ["V", "V", "V"], plan);
      expect([...result]..sort(), result);
      expect(result.toSet(), hasLength(3));
    });
  });
}
