// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/models/rules/ocpt_convocation_audition.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_convocation_slot.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_shooting_convocations.dart';

/// One person's, one uncast role's, one guest's or one candidate's whole call for a day, joined
/// across everything they are linked to (ADR 0018) — every slot for the first three, every audition
/// block for a candidate (ADR 0024) — the app's one answer to "when does this human arrive, when
/// are they ready to shoot, and when are they done" (a guest excepted from the middle question, see
/// [patStartMinute]).
///
/// **Exactly one of [personId]/[roleId]/[guestPersonId]/[guestFreeName] is non-null**, the same
/// discriminator `breakdown_tags` uses (ADR 0014): a cast role with nobody cast in it is still a
/// convocation the production has to honour, named by the role rather than by nobody, and a guest
/// is named by the address book or by a free name exactly as `shooting_slot_guests` itself
/// discriminates one.
///
/// **A candidate is not a fifth arm, and deliberately.** Somebody seen for a part is a *person*,
/// and a person arrives once and leaves once whatever brings them in: crewing the day, playing a
/// part and being seen for another are three reasons and one call. So the candidacies the day sees
/// of them ride along on their own convocation, in [roleCandidateIds], rather than making a second
/// convocation of their own — which is what stopped anybody receiving two call sheets for one day.
class OcptDayConvocation {
  /// Builds a computed day convocation.
  const OcptDayConvocation({
    required this.personId,
    required this.roleId,
    required this.guestPersonId,
    required this.guestFreeName,
    required this.roleCandidateIds,
    required this.hasSlotConvocation,
    required this.arrivalMinute,
    required this.patStartMinute,
    required this.patEndMinute,
    required this.isPatBand,
    required this.departureMinute,
    required this.slotIds,
  });

  /// The person this convocation is for (crew or cast), or null when another of the four fields
  /// names it instead.
  final String? personId;

  /// The uncast role this convocation is for, or null when another of the five fields names it
  /// instead.
  final String? roleId;

  /// The address-book guest this convocation is for, or null when another of the five fields names
  /// it instead.
  final String? guestPersonId;

  /// The free-named guest this convocation is for, or null when another of the five fields names it
  /// instead.
  final String? guestFreeName;

  /// The candidacies of this person the day sees, empty for everybody the day sees for no part at
  /// all — which is everybody but a candidate, [personId] being the only arm this is ever non-empty
  /// beside.
  ///
  /// **A set rather than one id**: a person read for two parts on one day is seen twice and called
  /// once. What differs between the two is the part, which is why the directories that answer "who
  /// is expected for what" print one row per entry here while the sheet addressed to them stays a
  /// single sheet.
  final Set<String> roleCandidateIds;

  /// Whether any slot names this convocation as **crew or cast** — as opposed to a day that only
  /// sees them for a part.
  ///
  /// The one thing that tells "the second camera assistant, who is also being seen for Marie at
  /// eleven" from "Marie's candidate": both carry candidacies, and only the second belongs in the
  /// convocations panel's own candidates group. Always true for an uncast role and for a guest,
  /// neither of which is ever seen for a part.
  final bool hasSlotConvocation;

  /// Whether this convocation is a guest's — either half of the discriminator, [guestPersonId] or
  /// [guestFreeName].
  bool get isGuest => guestPersonId != null || guestFreeName != null;

  /// The key this convocation is picked by when named call sheets are asked for one recipient at a
  /// time — its own [personId] or [roleId], the two arms of the discriminator a named sheet is ever
  /// addressed to, and stable across the days of one export (somebody convoked on three days is one
  /// recipient, ticked once).
  ///
  /// **A person is one recipient, whatever they do that day.** A sheet is addressed to somebody,
  /// not to one of their reasons for being there: a person crewing the day and seen for a part
  /// receives the one sheet carrying both, which is what [roleCandidateIds] riding on this
  /// convocation is for.
  ///
  /// **Null for a guest** ([isGuest]), who is never a named sheet's recipient: they are on the day
  /// and owed an hour, and the sheet an assistant director reads down is not addressed to them —
  /// the same reason the trailing guest table exists rather than a guest row in the crew list. A
  /// caller building that recipient list therefore filters on this being non-null and needs no
  /// second rule of its own.
  String? get selectionKey => personId ?? roleId;

  /// Whether the day sees this person for a part at all — one candidacy is enough.
  ///
  /// What the directories that answer "who is expected for what" read: the printed candidates list
  /// and the audition table both go through it, and both print one entry per candidacy rather than
  /// one per person.
  bool get isSeenForAPart => roleCandidateIds.isNotEmpty;

  /// Whether being seen for a part is the **only** reason the day has for this person.
  ///
  /// What the convocations panel's own candidates group holds: somebody crewing the day and seen
  /// for Marie at eleven belongs among the crew, with one band covering both, and only somebody the
  /// day has nothing else for belongs under `Candidates`. Unlike [isGuest], neither this nor
  /// [isSeenForAPart] changes anything about the figures below — a candidate arrives, is ready and
  /// leaves exactly as everybody else does, off the audition blocks naming them (ADR 0024) joined
  /// with whatever else the day asks of them.
  bool get isOnlySeenForAPart => isSeenForAPart && !hasSlotConvocation;

  /// The earliest minute this person or role is expected — the minimum
  /// [OcptConvocationSlot.startMinute] over every slot they are linked to.
  final int arrivalMinute;

  /// The start of this person's or role's band. When any slot they are linked to films
  /// ([isPatBand]), it is the *prêt à tourner* band — the minimum non-null
  /// [OcptConvocationSlot.filmingStartMinute] over those slots, their auditions and rehearsals left
  /// to [arrivalMinute]/[departureMinute]. Otherwise it is a presence band — the minimum non-null
  /// [OcptConvocationSlot.shootingStartMinute], widened by their own auditions — or null when none
  /// of those slots carries a shooting block at all: someone convoked only on preparation slots is
  /// there, not waiting to shoot, which is a different fact from having no band computed yet.
  /// **Always null for a guest** ([isGuest]), whatever shooting blocks the slots they are linked to
  /// carry: a guest does not shoot, and a band would say they were waiting to. Null exactly when
  /// [patEndMinute] is.
  final int? patStartMinute;

  /// The end of the band — the maximum non-null [OcptConvocationSlot.filmingEndMinute] or
  /// [OcptConvocationSlot.shootingEndMinute] over the same slots, whichever [patStartMinute] was
  /// read from — under the same condition as [patStartMinute]. The band is **not** clipped to one
  /// slot: someone on a morning slot and an evening slot reads one band spanning both, gaps
  /// included.
  final int? patEndMinute;

  /// Whether the band above is a **PAT** (*prêt à tourner*) band, or merely a presence one: true
  /// when any slot this convocation is linked to films ([OcptConvocationSlot.filmingStartMinute] is
  /// set), in which case the band covers the filming blocks **alone**; false when the work it
  /// covers is auditions and rehearsals alone.
  ///
  /// A PAT band never stretches over an audition or a rehearsal: a slot that auditions at 09:00 and
  /// shoots from 13:00 gives its unit `PAT 13:00`, and the morning is carried by the arrival. A PAT
  /// reading 09:00 would claim the camera was ready four hours before it was.
  ///
  /// **The label follows the band, never the day.** A day that auditions in the morning and shoots
  /// in the afternoon owes its cast a `PAT` and its candidates a `PRÉSENCE`, on the one sheet: the
  /// actor is due ready for a take and the candidate is due to be seen, and one word cannot be
  /// both. Always false for a guest and for a convocation with no band at all, neither having
  /// anything to name.
  final bool isPatBand;

  /// The latest minute this person or role is done — the maximum, over every slot they are linked
  /// to, of that slot's own [OcptConvocationSlot.endMinute] when it has one, or its own
  /// [OcptConvocationSlot.startMinute] otherwise: a slot carrying no block at all yet still ends
  /// the instant it begins, for someone linked to nothing more than that.
  final int departureMinute;

  /// The ids of every slot this person, role or candidacy is expected on, in the order
  /// [ocptComputeDayConvocations] was given [OcptConvocationSlot]s — or, for a candidate, the slots
  /// their own auditions sit in, deduplicated, in the order it was given
  /// [OcptConvocationAudition]s.
  final List<String> slotIds;
}
