// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/models/rules/ocpt_convocation_candidacy.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_day_convocation.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_shooting_convocations.dart';

/// One **audition block** of a day, already resolved by the caller into what
/// [ocptComputeDayConvocations] needs of it: when it runs, whose hour it is, and which slot it sits
/// in.
///
/// The one convocation in this app read off a block rather than off a slot (ADR 0024), and ADR 0018
/// applied rather than bent: a candidate is expected at twenty past ten, for twenty minutes, which
/// is exactly what this block is — so this, and not the unit's whole day, is what their arrival,
/// their PAT band and their departure are read off.
class OcptConvocationAudition {
  /// Builds an audition to feed to [ocptComputeDayConvocations].
  const OcptConvocationAudition({
    required this.slotId,
    required this.startMinute,
    required this.endMinute,
    required this.candidacies,
  });

  /// The id of the slot this audition sits in — what [OcptDayConvocation.slotIds] echoes back for a
  /// candidate, so a named call sheet can narrow the timetable to the unit they are expected on
  /// exactly as it does for everybody else.
  final String slotId;

  /// The audition's own resolved start (`OcptShootingTimelineEntry.startMinute`), never a stored
  /// column.
  final int startMinute;

  /// The audition's own resolved end (`OcptShootingTimelineEntry.endMinute`).
  final int endMinute;

  /// The candidacies this audition sees, each already resolved to the person behind it. Several on
  /// one audition is ordinary — two actors of two different parts read together — and an audition
  /// naming none convokes nobody. Resolving a candidacy to a name and a part is the caller's job,
  /// this file knowing nothing of `role_candidates` beyond the two ids
  /// [OcptConvocationCandidacy] carries.
  final List<OcptConvocationCandidacy> candidacies;
}
