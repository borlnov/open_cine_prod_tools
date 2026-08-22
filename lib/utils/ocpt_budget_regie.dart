// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_totals.dart';

/// The catering-and-travel pass: what a shooting day actually costs in meals and at the buffet, and
/// what each person's own commute costs the production in mileage.
///
/// **Nothing here is typed twice.** The head counts come from the schedule
/// (`OcptScheduleSnapshot`'s own days, slots and blocks), the two unit prices from the project
/// settings, and each traveller's own distance and rate from their own sheet
/// (`people.commuteKmMilli`, `people.mileageRateId`) — this file only ever crosses figures that
/// already live somewhere else, exactly as ADR 0026 argues for the whole mode.
///
/// **A meal is read off the timetable, never assumed.** Earlier readings of this pass counted one
/// meal per head per shooting day mechanically, whatever the day's own timetable held — the
/// product owner's objection: nobody can know whether a day feeds anybody, or feeds them lunch,
/// dinner or both, unless the timetable says so, and it does, through `shooting_day_blocks` rows
/// of kind [OcptShootingBlockKind.meal]. A meal is therefore counted **once per meal block**, over
/// the heads convoked to **that block's own slot** (`shooting_day_blocks.slotId`) — a slot holding
/// a lunch block and a dinner block feeds its heads twice, two parallel slots each holding their own
/// meal block feed their own heads at their own times, and a slot holding no meal block feeds
/// nobody. See [OcptBudgetRegieMealSitting] and [ocptBudgetRegieDaysOf]'s own doc comment for the
/// dedup this reading applies, and its own stated limit.
///
/// **The buffet is unaffected by any of this.** It reads as a permanently available table, not a
/// meal, so it is still counted per head per shooting day, deduplicated exactly as before (present
/// in three slots, counted once) — a per-head rate is the right shape for a table whose own size
/// follows how many people are there. This is the one rule in this file that did **not** change
/// when the meal reading did.

/// How many legs a return trip is made of — one out, one back — what turns a person's own one-way
/// [OcptBudgetTravelRow.totalKmMilli] into the distance the production actually reimburses.
const int _ocptBudgetReturnTripLegCount = 2;

/// How many thousandths of a cent-per-kilometre make up one cent-per-kilometre, and how many
/// thousandths of a kilometre make up one kilometre at once: a distance in `kilometres × 1000`
/// times a rate in `cents × 1000` per kilometre is `cents × 1,000,000`, so this is what the product
/// of the two is divided back down by.
const int _ocptBudgetTravelMilliUnitsPerCent = 1000000;

/// Half of [_ocptBudgetTravelMilliUnitsPerCent] — added to a non-negative numerator before the
/// integer division in [_ocptBudgetTravelAmountCentsOf], so the division rounds to the nearest cent
/// exactly once rather than always truncating down, without ever going through a `double`.
const int _ocptBudgetTravelRoundingHalf = _ocptBudgetTravelMilliUnitsPerCent ~/ 2;

/// How many priced items a day's own catering [OcptBudgetRegieDay.cost] is built from — the meals
/// (folded across every sitting) and the buffet, the two figures `docs/architecture/budget.md`'s
/// catering pass prices separately.
const int _ocptBudgetRegiePricedItemCount = 2;

/// One meal block's own reading: who it fed, and at which slot.
///
/// **Deduplicated by person within this one block, not further.** Crew is read by `personId`
/// directly; cast is read by `roles.personId` — a role names a person only once it is cast, so a
/// role with no person recorded cannot be told apart from the crew and counts on its own
/// ([ocptBudgetRegieDaysOf]'s own doc comment states why this is the honest reading rather than a
/// gap). Somebody who is both cast and crew on this block's own slot is counted once.
class OcptBudgetRegieMealSitting extends Equatable {
  /// The meal block this sitting reads.
  final String blockId;

  /// The slot this block belongs to — whose own crew and cast are who it fed.
  final String slotId;

  /// How many distinct heads this sitting fed.
  final int headCount;

  /// Class constructor
  const OcptBudgetRegieMealSitting({
    required this.blockId,
    required this.slotId,
    required this.headCount,
  });

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptBudgetRegieMealSitting(blockId: $blockId, slotId: $slotId, headCount: $headCount)";

  /// Object properties
  @override
  List<Object?> get props => [blockId, slotId, headCount];
}

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
  /// [OcptBudgetRegieMealSitting.headCount]. A person fed at two sittings of the same day (lunch and
  /// dinner) is counted twice here, on purpose: they ate twice, and the production pays for both.
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

/// [days], each read for its own catering cost, in the order [days] was given.
///
/// **Never reorders [days]** — the same discipline `ocptBudgetJournalRowsOf`
/// (`lib/utils/ocpt_budget_journal.dart`) states about the cash journal: a caller wanting the
/// schedule's own chronological order gets it because the schedule handed the days in that order
/// already, not because this function imposes one of its own.
///
/// **The buffet's own reading is untouched by this milestone.** Crew is the distinct `personId` set
/// across every slot of the day ([OcptShootingSlot.crew]): a person linked to three slots of one
/// day still counts once. Cast and extras are the distinct `roleId` set across the day's slots
/// ([OcptShootingSlot.cast]), split on [roleKindById]: a role of kind [OcptRoleKind.extra] counts as
/// an extra, everything else as cast. **A role id [roleKindById] does not know counts as cast, not
/// as nothing**: it is still a convocation the production has to feed, and only a role this map
/// explicitly names [OcptRoleKind.extra] is known to be a block of extras rather than one speaking
/// or silent character.
///
/// **Meals are read off [blocksByDayId] instead.** Every block of kind [OcptShootingBlockKind.meal]
/// on the day becomes one [OcptBudgetRegieMealSitting], read over that block's own slot alone (never
/// the whole day) — a slot holding two meal blocks (lunch, dinner) therefore feeds its own heads
/// twice, and a slot with none is never read for a sitting at all. **Deduplicated by person within
/// one sitting**: a person linked as crew to that slot and named by a cast role's own
/// [personIdByRoleId] entry is counted once, not twice — "comédien et technicien" eats once. **A
/// role [personIdByRoleId] cannot resolve counts on its own, never folded into the crew set**: cast
/// is `roles`, not people, and a role names a person only once it is cast (`roles.personId`); a role
/// with nobody cast in it yet cannot honestly be told apart from the crew, so it is left standing on
/// its own rather than guessed away. This is the dedup's own stated limit — a role that turns out to
/// be played by somebody already on the crew list will keep counting twice until it is cast.
///
/// **Guests are deliberately excluded**, from both readings — [OcptShootingSlot.guests] is never
/// read by this function. A guest is a visitor the production has not convoked to work, exactly the
/// distinction ADR 0018 already draws by refusing a guest a shooting band
/// (`lib/utils/ocpt_shooting_convocations.dart`, `OcptDayConvocation.isGuest`).
///
/// [mealPriceCents] and [buffetPriceCents] price every day alike — the project's own settings, not
/// typed per day. [buffetPriceCents] is `project_info.snackPriceCents` read under its new,
/// user-facing name: the column keeps the name the schema gave it (ADR 0007's schema-number rule),
/// but the buffet it prices was never a snack in the trade's own words.
List<OcptBudgetRegieDay> ocptBudgetRegieDaysOf({
  required List<OcptShootingDay> days,
  required Map<String, List<OcptShootingSlot>> slotsByDayId,
  required Map<String, List<OcptShootingDayBlock>> blocksByDayId,
  required Map<String, OcptRoleKind> roleKindById,
  required Map<String, String?> personIdByRoleId,
  required int? mealPriceCents,
  required int? buffetPriceCents,
}) => [
  for (final day in days)
    _ocptBudgetRegieDayOf(
      day,
      slots: slotsByDayId[day.id] ?? const [],
      blocks: blocksByDayId[day.id] ?? const [],
      roleKindById: roleKindById,
      personIdByRoleId: personIdByRoleId,
      mealPriceCents: mealPriceCents,
      buffetPriceCents: buffetPriceCents,
    ),
];

/// [day]'s own catering reading, over its own [slots] and [blocks] — see [ocptBudgetRegieDaysOf]'s
/// own doc comment for the arithmetic argued in full.
OcptBudgetRegieDay _ocptBudgetRegieDayOf(
  OcptShootingDay day, {
  required List<OcptShootingSlot> slots,
  required List<OcptShootingDayBlock> blocks,
  required Map<String, OcptRoleKind> roleKindById,
  required Map<String, String?> personIdByRoleId,
  required int? mealPriceCents,
  required int? buffetPriceCents,
}) {
  // The buffet's own day-wide reading — mechanical, unchanged by this milestone.
  final crewPersonIds = <String>{};
  final castRoleIds = <String>{};

  for (final slot in slots) {
    for (final crewMember in slot.crew) {
      crewPersonIds.add(crewMember.personId);
    }
    for (final castMember in slot.cast) {
      castRoleIds.add(castMember.roleId);
    }
  }

  var castCount = 0;
  var extraCount = 0;
  for (final roleId in castRoleIds) {
    if (roleKindById[roleId] == OcptRoleKind.extra) {
      extraCount++;
    } else {
      castCount++;
    }
  }

  // The meal reading — one sitting per meal block, read over that block's own slot alone.
  final slotById = {for (final slot in slots) slot.id: slot};
  final mealSittings = [
    for (final block in blocks)
      if (block.kind == OcptShootingBlockKind.meal)
        _ocptBudgetRegieMealSittingOf(
          block,
          slot: slotById[block.slotId],
          personIdByRoleId: personIdByRoleId,
        ),
  ];
  final mealCount = mealSittings.fold(0, (sum, sitting) => sum + sitting.headCount);
  final buffetCount = crewPersonIds.length + castCount + extraCount;

  return OcptBudgetRegieDay(
    dayId: day.id,
    dayNumber: day.dayNumber,
    date: day.date,
    crewCount: crewPersonIds.length,
    castCount: castCount,
    extraCount: extraCount,
    mealSittings: mealSittings,
    cost: _ocptBudgetRegieCostOf(
      mealCount: mealCount,
      buffetCount: buffetCount,
      mealPriceCents: mealPriceCents,
      buffetPriceCents: buffetPriceCents,
    ),
  );
}

/// [block]'s own meal sitting, read over its own [slot] — null while the block names a slot this
/// day's own live slots no longer carry, which reads as an empty sitting (nobody fed) rather than a
/// crash, mirroring how a candidacy removed under an audition block is read defensively elsewhere.
///
/// See [ocptBudgetRegieDaysOf]'s own doc comment for the dedup argued in full: crew is read by
/// `personId` directly, cast by [personIdByRoleId] resolving `roles.personId`, the two sets merged
/// before counting so a person appearing in both is counted once; a role [personIdByRoleId] cannot
/// resolve is counted on its own, added to the merged set's own size rather than folded into it.
OcptBudgetRegieMealSitting _ocptBudgetRegieMealSittingOf(
  OcptShootingDayBlock block, {
  required OcptShootingSlot? slot,
  required Map<String, String?> personIdByRoleId,
}) {
  final personIds = <String>{};
  var unresolvedRoleCount = 0;

  if (slot != null) {
    for (final crewMember in slot.crew) {
      personIds.add(crewMember.personId);
    }
    for (final castMember in slot.cast) {
      final personId = personIdByRoleId[castMember.roleId];
      if (personId != null) {
        personIds.add(personId);
      } else {
        unresolvedRoleCount++;
      }
    }
  }

  return OcptBudgetRegieMealSitting(
    blockId: block.id,
    slotId: block.slotId,
    headCount: personIds.length + unresolvedRoleCount,
  );
}

/// The catering cost over [mealCount] meals at [mealPriceCents] and [buffetCount] heads at the
/// buffet, priced at [buffetPriceCents] — two priced items, each contributing to
/// [OcptBudgetCoveredTotal.amountCents]/[OcptBudgetCoveredTotal.coveredLineCount] only when its own
/// price is known, exactly the "null, never zero" reading `lib/utils/ocpt_budget_vat.dart` states
/// for a rate: a project that has recorded a meal price but no buffet price reads a real, partial
/// figure that says how much of itself it covers, rather than a total silently short by the buffet.
OcptBudgetCoveredTotal _ocptBudgetRegieCostOf({
  required int mealCount,
  required int buffetCount,
  required int? mealPriceCents,
  required int? buffetPriceCents,
}) {
  var amountCents = 0;
  var coveredLineCount = 0;

  if (mealPriceCents != null) {
    amountCents += mealPriceCents * mealCount;
    coveredLineCount++;
  }
  if (buffetPriceCents != null) {
    amountCents += buffetPriceCents * buffetCount;
    coveredLineCount++;
  }

  return OcptBudgetCoveredTotal(
    amountCents: amountCents,
    coveredLineCount: coveredLineCount,
    lineCount: _ocptBudgetRegiePricedItemCount,
  );
}

/// The catering pass folded over every day: how many heads, meals and buffet servings the whole
/// schedule accounts for, and the whole cost.
class OcptBudgetRegieTotals extends Equatable {
  /// The sum of every day's own [OcptBudgetRegieDay.headCount] — a person shooting on three days is
  /// counted three times here, once per day they actually had to be fed, unlike the de-duplication
  /// each day's own count already applies within itself.
  final int headCount;

  /// The sum of every day's own [OcptBudgetRegieDay.mealCount] — a person fed at two sittings of one
  /// day is counted twice, exactly as [OcptBudgetRegieDay.mealCount] already counts them.
  final int mealCount;

  /// The sum of every day's own [OcptBudgetRegieDay.buffetCount].
  final int buffetCount;

  /// Every day's own [OcptBudgetRegieDay.cost], folded together — row by row, then summed, the same
  /// reading `docs/architecture/budget.md` states for every other total in this mode.
  final OcptBudgetCoveredTotal cost;

  /// Class constructor
  const OcptBudgetRegieTotals({
    required this.headCount,
    required this.mealCount,
    required this.buffetCount,
    required this.cost,
  });

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptBudgetRegieTotals(headCount: $headCount, mealCount: $mealCount, "
      "buffetCount: $buffetCount, cost: $cost)";

  /// Object properties
  @override
  List<Object?> get props => [headCount, mealCount, buffetCount, cost];
}

/// [days]' own catering reading, folded into one total — see [OcptBudgetRegieTotals]'s own doc
/// comment.
OcptBudgetRegieTotals ocptBudgetRegieTotalsOf(List<OcptBudgetRegieDay> days) {
  var headCount = 0;
  var mealCount = 0;
  var buffetCount = 0;
  var amountCents = 0;
  var coveredLineCount = 0;
  var lineCount = 0;

  for (final day in days) {
    headCount += day.headCount;
    mealCount += day.mealCount;
    buffetCount += day.buffetCount;
    amountCents += day.cost.amountCents;
    coveredLineCount += day.cost.coveredLineCount;
    lineCount += day.cost.lineCount;
  }

  return OcptBudgetRegieTotals(
    headCount: headCount,
    mealCount: mealCount,
    buffetCount: buffetCount,
    cost: OcptBudgetCoveredTotal(
      amountCents: amountCents,
      coveredLineCount: coveredLineCount,
      lineCount: lineCount,
    ),
  );
}

/// One traveller's own mileage reading: how many return trips the schedule puts them on, and what
/// that comes to.
class OcptBudgetTravelRow extends Equatable {
  /// The person this row is for.
  final String personId;

  /// How many distinct shooting days this person is present on — one return trip per day, see
  /// [ocptBudgetTravelRowsOf]'s own doc comment.
  final int returnTripCount;

  /// The total distance this person actually travels, in thousandths of a kilometre — null when
  /// their own commute is null, never zero: nobody has said how far they travel, which is a
  /// different fact from them travelling no distance at all.
  final int? totalKmMilli;

  /// What reimbursing [totalKmMilli] comes to, in cents — null when [totalKmMilli] is, when this
  /// person names no rate, or when the rate they name is not one this project holds.
  final int? amountCents;

  /// Class constructor
  const OcptBudgetTravelRow({
    required this.personId,
    required this.returnTripCount,
    required this.totalKmMilli,
    required this.amountCents,
  });

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptBudgetTravelRow(personId: $personId, returnTripCount: $returnTripCount, "
      "totalKmMilli: $totalKmMilli, amountCents: $amountCents)";

  /// Object properties
  @override
  List<Object?> get props => [personId, returnTripCount, totalKmMilli, amountCents];
}

/// Every traveller the schedule names, each with their own return-trip count and what reimbursing
/// them comes to.
///
/// **A person is present on a day when they are linked as crew to any slot of it, or when a role
/// they are cast in is linked as cast to any slot of it** ([personIdByRoleId] resolving a role to
/// the human playing it) — crossed here with days rather than heads. **Guests are excluded**, for
/// the same reason as [ocptBudgetRegieDaysOf]: [OcptShootingSlot.guests] is never read by this
/// function.
///
/// [OcptBudgetTravelRow.returnTripCount] is the number of **distinct days** a person is present on
/// — one journey out and back per shooting day, never one per slot: a person linked to two slots of
/// the same day still makes one round trip.
///
/// [OcptBudgetTravelRow.totalKmMilli] is `returnTripCount × 2 × commuteKmMilli`, the `× 2` turning
/// a one-way commute into a return trip — null exactly when this person's own
/// [commuteKmMilliByPersonId] entry is, never zero.
///
/// [OcptBudgetTravelRow.amountCents] is that distance times the rate this person names
/// ([mileageRateIdByPersonId] resolved through [ratePerKmMilliCentsByRateId]), rounded to the
/// nearest cent **exactly once, at the end** — never a `double` anywhere in between, for the same
/// reason `quantityMilli` exists at all (`docs/architecture/budget.md`'s own money rule). It is
/// null when the distance is null, when this person names no rate at all, or when the rate they
/// name is not one [ratePerKmMilliCentsByRateId] holds — a rate since deleted, say.
///
/// **A person who claims nothing is still returned, with the money left silent**: dropping their
/// row instead would make an absent figure indistinguishable from an absent person, and it is
/// exactly by seeing the row that somebody discovers a distance nobody has filled in yet.
///
/// **Ordering is deterministic and not by name**: [OcptBudgetTravelRow.returnTripCount] descending,
/// ties broken by [OcptBudgetTravelRow.personId] — the very argument `ocptComputeDayConvocations`
/// (`lib/utils/ocpt_shooting_convocations.dart`) already makes about its own ordering. Nothing in
/// this file knows a person's display name, so a caller wanting an alphabetical reading re-sorts on
/// top of this one.
List<OcptBudgetTravelRow> ocptBudgetTravelRowsOf({
  required List<OcptShootingDay> days,
  required Map<String, List<OcptShootingSlot>> slotsByDayId,
  required Map<String, String?> personIdByRoleId,
  required Map<String, int?> commuteKmMilliByPersonId,
  required Map<String, String?> mileageRateIdByPersonId,
  required Map<String, int> ratePerKmMilliCentsByRateId,
}) {
  final presentDayIdsByPersonId = <String, Set<String>>{};

  for (final day in days) {
    final slots = slotsByDayId[day.id] ?? const [];
    final personIdsPresentToday = <String>{};

    for (final slot in slots) {
      for (final crewMember in slot.crew) {
        personIdsPresentToday.add(crewMember.personId);
      }
      for (final castMember in slot.cast) {
        final personId = personIdByRoleId[castMember.roleId];
        if (personId != null) {
          personIdsPresentToday.add(personId);
        }
      }
    }

    for (final personId in personIdsPresentToday) {
      presentDayIdsByPersonId.putIfAbsent(personId, () => <String>{}).add(day.id);
    }
  }

  final rows = [
    for (final entry in presentDayIdsByPersonId.entries)
      _ocptBudgetTravelRowOf(
        personId: entry.key,
        returnTripCount: entry.value.length,
        commuteKmMilliByPersonId: commuteKmMilliByPersonId,
        mileageRateIdByPersonId: mileageRateIdByPersonId,
        ratePerKmMilliCentsByRateId: ratePerKmMilliCentsByRateId,
      ),
  ];

  rows.sort((left, right) {
    final byReturnTripCount = right.returnTripCount.compareTo(left.returnTripCount);
    if (byReturnTripCount != 0) {
      return byReturnTripCount;
    }

    return left.personId.compareTo(right.personId);
  });

  return rows;
}

/// [personId]'s own travel row, having made [returnTripCount] return trips — see
/// [ocptBudgetTravelRowsOf]'s own doc comment for the arithmetic argued in full.
OcptBudgetTravelRow _ocptBudgetTravelRowOf({
  required String personId,
  required int returnTripCount,
  required Map<String, int?> commuteKmMilliByPersonId,
  required Map<String, String?> mileageRateIdByPersonId,
  required Map<String, int> ratePerKmMilliCentsByRateId,
}) {
  final commuteKmMilli = commuteKmMilliByPersonId[personId];
  final totalKmMilli = commuteKmMilli == null
      ? null
      : returnTripCount * _ocptBudgetReturnTripLegCount * commuteKmMilli;

  final rateId = mileageRateIdByPersonId[personId];
  final ratePerKmMilliCents = rateId == null ? null : ratePerKmMilliCentsByRateId[rateId];

  return OcptBudgetTravelRow(
    personId: personId,
    returnTripCount: returnTripCount,
    totalKmMilli: totalKmMilli,
    amountCents: _ocptBudgetTravelAmountCentsOf(
      totalKmMilli: totalKmMilli,
      ratePerKmMilliCents: ratePerKmMilliCents,
    ),
  );
}

/// [totalKmMilli] reimbursed at [ratePerKmMilliCents], rounded to the nearest cent — null when
/// either is, never a `double`: [totalKmMilli] and [ratePerKmMilliCents] are both already integers
/// in thousandths, so their product is an integer number of millionths of a cent, and
/// [_ocptBudgetTravelRoundingHalf] added before the integer division rounds it to the nearest whole
/// cent in one exact step rather than truncating down every time.
int? _ocptBudgetTravelAmountCentsOf({required int? totalKmMilli, required int? ratePerKmMilliCents}) {
  if (totalKmMilli == null || ratePerKmMilliCents == null) {
    return null;
  }

  final numerator = totalKmMilli * ratePerKmMilliCents;
  return (numerator + _ocptBudgetTravelRoundingHalf) ~/ _ocptBudgetTravelMilliUnitsPerCent;
}

/// The travel pass folded over every traveller: the total distance and the total reimbursement.
class OcptBudgetTravelTotals extends Equatable {
  /// The sum of [OcptBudgetTravelRow.totalKmMilli] over the rows that carry one — a row whose own
  /// distance is null contributes nothing here, exactly as it contributes no figure of its own.
  final int totalKmMilli;

  /// Every row's own [OcptBudgetTravelRow.amountCents], folded together — row by row, then summed,
  /// so the view can say `1 240 € · over 3 of the 7 travellers` for as long as any distance or rate
  /// is missing.
  final OcptBudgetCoveredTotal cost;

  /// Class constructor
  const OcptBudgetTravelTotals({required this.totalKmMilli, required this.cost});

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "OcptBudgetTravelTotals(totalKmMilli: $totalKmMilli, cost: $cost)";

  /// Object properties
  @override
  List<Object?> get props => [totalKmMilli, cost];
}

/// [rows]' own travel reading, folded into one total — see [OcptBudgetTravelTotals]'s own doc
/// comment.
OcptBudgetTravelTotals ocptBudgetTravelTotalsOf(List<OcptBudgetTravelRow> rows) {
  var totalKmMilli = 0;
  var amountCents = 0;
  var coveredLineCount = 0;

  for (final row in rows) {
    final rowKmMilli = row.totalKmMilli;
    if (rowKmMilli != null) {
      totalKmMilli += rowKmMilli;
    }

    final rowAmountCents = row.amountCents;
    if (rowAmountCents != null) {
      amountCents += rowAmountCents;
      coveredLineCount++;
    }
  }

  return OcptBudgetTravelTotals(
    totalKmMilli: totalKmMilli,
    cost: OcptBudgetCoveredTotal(
      amountCents: amountCents,
      coveredLineCount: coveredLineCount,
      lineCount: rows.length,
    ),
  );
}
