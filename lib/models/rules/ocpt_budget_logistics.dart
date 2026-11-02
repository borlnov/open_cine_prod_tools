// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_covered_total.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_logistics_day.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_logistics_meal_sitting.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_logistics_totals.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';

/// The catering pass: what a shooting day actually costs in meals and at the buffet.
///
/// **Nothing here is typed twice.** The head counts come from the schedule
/// (`OcptScheduleSnapshot`'s own days, slots and blocks) and the two unit prices from the project
/// settings — this file only ever crosses figures that already live somewhere else, exactly as
/// ADR 0026 argues for the whole mode.
///
/// **The defrayals used to live here too, and deliberately no longer do.** This file once computed
/// what a traveller costs as one return trip per day of presence, from their own home-to-set
/// distance and their own mileage rate; a real shoot does not work that way, so what a production
/// pays somebody back is now typed row by row into `budget_allowances` and read through
/// `lib/models/rules/ocpt_budget_allowances.dart` — see `OcptBudgetAllowancesTable`'s own doc
/// comment. What is left here is what genuinely *is* derivable from a schedule: who was fed, and
/// how often.
///
/// **A meal is read off the timetable, never assumed.** Earlier readings of this pass counted one
/// meal per head per shooting day mechanically, whatever the day's own timetable held — the product
/// owner's objection: nobody can know whether a day feeds anybody, or feeds them lunch, dinner or
/// both, unless the timetable says so, and it does, through `shooting_day_blocks` rows of kind
/// [OcptShootingBlockKind.meal]. A meal is therefore counted **once per meal block**, over the
/// heads convoked to **that block's own slot** (`shooting_day_blocks.slotId`) — a slot holding a
/// lunch block and a dinner block feeds its heads twice, two parallel slots each holding their own
/// meal block feed their own heads at their own times, and a slot holding no meal block feeds
/// nobody. See [OcptBudgetLogisticsMealSitting] and [ocptBudgetLogisticsDaysOf]'s own doc comment
/// for the dedup this reading applies, and its own stated limit.
///
/// **The buffet is unaffected by any of this.** It reads as a permanently available table, not a
/// meal, so it is still counted per head per shooting day, deduplicated exactly as before (present
/// in three slots, counted once) — a per-head rate is the right shape for a table whose own size
/// follows how many people are there. This is the one rule in this file that did **not** change
/// when the meal reading did.

/// How many priced items a day's own catering [OcptBudgetLogisticsDay.cost] is built from — the
/// meals (folded across every sitting) and the buffet, the two figures
/// `docs/architecture/budget.md`'s catering pass prices separately.
const int _ocptBudgetLogisticsPricedItemCount = 2;

/// Get [days], each read for its own catering cost, in the order [days] was given.
///
/// **Never reorders [days]** — the same discipline `ocptBudgetJournalRowsOf`
/// (`lib/models/rules/ocpt_budget_journal.dart`) states about the cash journal: a caller wanting
/// the schedule's own chronological order gets it because the schedule handed the days in that
/// order already, not because this function imposes one of its own.
///
/// **The buffet's own reading is mechanical.** Crew is the distinct `personId` set across every
/// slot of the day ([OcptShootingSlot.crew]): a person linked to three slots of one day still
/// counts once. Cast and extras are the distinct `roleId` set across the day's slots
/// ([OcptShootingSlot.cast]), split on [roleKindById]: a role of kind [OcptRoleKind.extra] counts
/// as an extra, everything else as cast. **A role id [roleKindById] does not know counts as cast,
/// not as nothing**: it is still a convocation the production has to feed, and only a role this map
/// explicitly names [OcptRoleKind.extra] is known to be a block of extras rather than one speaking
/// or silent character.
///
/// **Meals are read off [blocksByDayId] instead.** Every block of kind [OcptShootingBlockKind.meal]
/// on the day becomes one [OcptBudgetLogisticsMealSitting], read over that block's own slot alone
/// (never the whole day) — a slot holding two meal blocks (lunch, dinner) therefore feeds its own
/// heads twice, and a slot with none is never read for a sitting at all. **Deduplicated by person
/// within one sitting**: a person linked as crew to that slot and named by a cast role's own
/// [personIdByRoleId] entry is counted once, not twice — "comédien et technicien" eats once. **A
/// role [personIdByRoleId] cannot resolve counts on its own, never folded into the crew set**: cast
/// is `roles`, not people, and a role names a person only once it is cast (`roles.personId`); a
/// role with nobody cast in it yet cannot honestly be told apart from the crew, so it is left
/// standing on its own rather than guessed away. This is the dedup's own stated limit — a role that
/// turns out to be played by somebody already on the crew list will keep counting twice until it is
/// cast.
///
/// **Guests are deliberately excluded**, from both readings — [OcptShootingSlot.guests] is never
/// read by this function. A guest is a visitor the production has not convoked to work, exactly the
/// distinction ADR 0018 already draws by refusing a guest a shooting band
/// (`lib/models/rules/ocpt_shooting_convocations.dart`, `OcptDayConvocation.isGuest`).
///
/// [mealPriceCents] and [buffetPriceCents] price every day alike — the project's own settings, not
/// typed per day. [buffetPriceCents] is `project_info.snackPriceCents` read under its new,
/// user-facing name: the column keeps the name the schema gave it (ADR 0007's schema-number rule),
/// but the buffet it prices was never a snack in the trade's own words.
List<OcptBudgetLogisticsDay> ocptBudgetLogisticsDaysOf({
  required List<OcptShootingDay> days,
  required Map<String, List<OcptShootingSlot>> slotsByDayId,
  required Map<String, List<OcptShootingDayBlock>> blocksByDayId,
  required Map<String, OcptRoleKind> roleKindById,
  required Map<String, String?> personIdByRoleId,
  required int? mealPriceCents,
  required int? buffetPriceCents,
}) => [
  for (final day in days)
    _ocptBudgetLogisticsDayOf(
      day,
      slots: slotsByDayId[day.id] ?? const [],
      blocks: blocksByDayId[day.id] ?? const [],
      roleKindById: roleKindById,
      personIdByRoleId: personIdByRoleId,
      mealPriceCents: mealPriceCents,
      buffetPriceCents: buffetPriceCents,
    ),
];

/// Get [day]'s own catering reading, over its own [slots] and [blocks] — see
/// [ocptBudgetLogisticsDaysOf]'s
/// own doc comment for the arithmetic argued in full.
OcptBudgetLogisticsDay _ocptBudgetLogisticsDayOf(
  OcptShootingDay day, {
  required List<OcptShootingSlot> slots,
  required List<OcptShootingDayBlock> blocks,
  required Map<String, OcptRoleKind> roleKindById,
  required Map<String, String?> personIdByRoleId,
  required int? mealPriceCents,
  required int? buffetPriceCents,
}) {
  // The buffet's own day-wide reading — mechanical.
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
        _ocptBudgetLogisticsMealSittingOf(
          block,
          slot: slotById[block.slotId],
          personIdByRoleId: personIdByRoleId,
        ),
  ];
  final mealCount = mealSittings.fold(0, (sum, sitting) => sum + sitting.headCount);
  final buffetCount = crewPersonIds.length + castCount + extraCount;

  return OcptBudgetLogisticsDay(
    dayId: day.id,
    dayNumber: day.dayNumber,
    date: day.date,
    crewCount: crewPersonIds.length,
    castCount: castCount,
    extraCount: extraCount,
    mealSittings: mealSittings,
    cost: _ocptBudgetLogisticsCostOf(
      mealCount: mealCount,
      buffetCount: buffetCount,
      mealPriceCents: mealPriceCents,
      buffetPriceCents: buffetPriceCents,
    ),
  );
}

/// Get [block]'s own meal sitting, read over its own [slot] — null while the block names a slot
/// this
/// day's own live slots no longer carry, which reads as an empty sitting (nobody fed) rather than a
/// crash, mirroring how a candidacy removed under an audition block is read defensively elsewhere.
///
/// See [ocptBudgetLogisticsDaysOf]'s own doc comment for the dedup argued in full: crew is read by
/// `personId` directly, cast by [personIdByRoleId] resolving `roles.personId`, the two sets merged
/// before counting so a person appearing in both is counted once; a role [personIdByRoleId] cannot
/// resolve is counted on its own, added to the merged set's own size rather than folded into it.
OcptBudgetLogisticsMealSitting _ocptBudgetLogisticsMealSittingOf(
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

  return OcptBudgetLogisticsMealSitting(
    blockId: block.id,
    slotId: block.slotId,
    headCount: personIds.length + unresolvedRoleCount,
  );
}

/// Get the catering cost over [mealCount] meals at [mealPriceCents] and [buffetCount] heads at the
/// buffet, priced at [buffetPriceCents] — two priced items, each contributing to
/// [OcptBudgetCoveredTotal.amountCents]/[OcptBudgetCoveredTotal.coveredLineCount] only when its own
/// price is known, exactly the "null, never zero" reading `lib/models/rules/ocpt_budget_vat.dart`
/// states for a rate: a project that has recorded a meal price but no buffet price reads a real,
/// partial figure that says how much of itself it covers, rather than a total silently short by the
/// buffet.
OcptBudgetCoveredTotal _ocptBudgetLogisticsCostOf({
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
    lineCount: _ocptBudgetLogisticsPricedItemCount,
  );
}

/// Get [days]' own catering reading, folded into one total — see [OcptBudgetLogisticsTotals]'s own
/// doc comment.
OcptBudgetLogisticsTotals ocptBudgetLogisticsTotalsOf(List<OcptBudgetLogisticsDay> days) {
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

  return OcptBudgetLogisticsTotals(
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
