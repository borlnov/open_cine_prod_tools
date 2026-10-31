// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_covered_total.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_regie.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_regie_meal_sitting.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';

/// One shooting day's own catering reading: who was on set, and what feeding them comes to.
class OcptBudgetRegieDay extends Equatable {
  /// The day this reading is for.
  final String dayId;

  /// This day's own 1-based rank — [OcptShootingDay.dayNumber], carried through rather than
  /// recomputed here.
  final int dayNumber;

  /// This day's calendar date.
  final DateTime date;

  /// How many distinct people were linked as crew to any slot of this day — the buffet's own
  /// reading, unaffected by the meal reading below. See [ocptBudgetRegieDaysOf]'s own doc comment
  /// for why this is a de-duplicated count rather than a count of assignments.
  final int crewCount;

  /// How many distinct roles convoked to this day are cast (not [OcptRoleKind.extra]) — the
  /// buffet's own reading. See [ocptBudgetRegieDaysOf]'s own doc comment for how a role
  /// `roleKindById` does not know is read.
  final int castCount;

  /// How many distinct roles convoked to this day are of kind [OcptRoleKind.extra] — the buffet's
  /// own reading.
  final int extraCount;

  /// How many people the buffet actually has to serve today — [crewCount] plus [castCount] plus
  /// [extraCount]. A derived reading, not a field of its own: it would otherwise be a second copy
  /// of the very three counts it is computed from. **Unaffected by [mealSittings]**: the buffet is
  /// still one per head per shooting day, exactly as before this pass started reading meal blocks.
  int get headCount => crewCount + castCount + extraCount;

  /// [headCount] under its own name for the buffet's own column — the two happen to read the same
  /// figure today, but they answer different questions ("how many people are on set" versus "how
  /// many meal-block sittings a day makes"), so this is its own reading rather than a caller
  /// borrowing [headCount] for a purpose it isn't named for.
  int get buffetCount => headCount;

  /// Every meal block this day's own timetable holds, one entry per sitting, in the order the
  /// day's own blocks chain in — **empty when the day's timetable holds no meal block at all**,
  /// which is a stated absence rather than a coincidental zero: the view reads this list's own
  /// emptiness to print a dash rather than a total that looks like a confirmed "nobody eats today".
  final List<OcptBudgetRegieMealSitting> mealSittings;

  /// How many meals this day accounts for — the sum of every [mealSittings] entry's own
  /// [OcptBudgetRegieMealSitting.headCount]. A person fed at two sittings of the same day (lunch
  /// and dinner) is counted twice here, on purpose: they ate twice, and the production pays for
  /// both.
  int get mealCount => mealSittings.fold(0, (sum, sitting) => sum + sitting.headCount);

  /// This day's own catering cost, priced over [mealCount] and [buffetCount] — see
  /// [ocptBudgetRegieDaysOf]'s own doc comment for why a missing price leaves one of the two out
  /// rather than the whole figure.
  final OcptBudgetCoveredTotal cost;

  /// Class constructor
  const OcptBudgetRegieDay({
    required this.dayId,
    required this.dayNumber,
    required this.date,
    required this.crewCount,
    required this.castCount,
    required this.extraCount,
    required this.mealSittings,
    required this.cost,
  });

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptBudgetRegieDay(dayId: $dayId, dayNumber: $dayNumber, headCount: $headCount, "
      "mealSittingCount: ${mealSittings.length}, cost: $cost)";

  /// Object properties
  @override
  List<Object?> get props => [
    dayId,
    dayNumber,
    date,
    crewCount,
    castCount,
    extraCount,
    mealSittings,
    cost,
  ];
}
