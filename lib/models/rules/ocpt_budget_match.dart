// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/models/ocpt_budget_allowance.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_match_suggestion.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_resource.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_revenue.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_allowances.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_covered_total.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_financing.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_match_candidate_kind.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_projection.dart';

/// How many days apart a candidate's own date and the draft's own date may sit and still count as
/// "close" — [OcptBudgetMatchSuggestion.matchesDate]'s own threshold. A week: wide enough to cover
/// the ordinary lag between a due date and the day somebody actually gets round to recording the
/// payment or the receipt against it, narrow enough that a commitment due next quarter is not
/// misleadingly called close just because it happens to be nearer than everything else on offer.
const int _ocptBudgetMatchCloseDateWindowDays = 7;

/// The fewest letters a folded word needs to count towards
/// [OcptBudgetMatchSuggestion.matchesWording] — three, so a connector word ("de", "la", "un")
/// shared by almost any two French sentences does not manufacture a match neither wording actually
/// intended.
const int _ocptBudgetMatchMinWordLength = 3;

/// At most how many suggestions [ocptBudgetMatchSuggestionsOf] ever returns — three. The band
/// itself shows only the very first, but a close second and third stay one click away without
/// opening the full dialog, since a production's own paperwork clusters: two invoices from the same
/// supplier, due the same week, are not a rare shape for the ranking to have to pick between.
const int _ocptBudgetMatchSuggestionCap = 3;

/// The diacritics a French wording actually uses, each folded onto the plain letter it decorates —
/// what lets "Couronne" and "couronné" compare equal on their own letters without pulling in a
/// normalization dependency this pure file has no business reaching for.
const Map<String, String> _ocptBudgetMatchDiacritics = {
  "à": "a",
  "á": "a",
  "â": "a",
  "ã": "a",
  "ä": "a",
  "å": "a",
  "è": "e",
  "é": "e",
  "ê": "e",
  "ë": "e",
  "ì": "i",
  "í": "i",
  "î": "i",
  "ï": "i",
  "ò": "o",
  "ó": "o",
  "ô": "o",
  "õ": "o",
  "ö": "o",
  "ù": "u",
  "ú": "u",
  "û": "u",
  "ü": "u",
  "ç": "c",
  "ñ": "n",
  "ý": "y",
  "ÿ": "y",
  "œ": "oe",
  "æ": "ae",
};

/// Every character [_ocptBudgetMatchWordsOf] treats as a word boundary — anything that is not a
/// plain lowercase letter or digit once [_ocptBudgetMatchFold] has run.
final RegExp _ocptBudgetMatchWordSeparators = RegExp("[^a-z0-9]+");

/// [text], lower-cased and every accented letter [_ocptBudgetMatchDiacritics] knows folded onto its
/// plain one.
String _ocptBudgetMatchFold(String text) {
  final buffer = StringBuffer();
  for (final rune in text.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_ocptBudgetMatchDiacritics[char] ?? char);
  }
  return buffer.toString();
}

/// [text] split into its own significant words — folded through [_ocptBudgetMatchFold], cut on
/// [_ocptBudgetMatchWordSeparators], and read as a set (so "Couronne, Couronne" is one word, not
/// two) of at least [_ocptBudgetMatchMinWordLength] letters each.
Set<String> _ocptBudgetMatchWordsOf(String text) => _ocptBudgetMatchFold(text)
    .split(_ocptBudgetMatchWordSeparators)
    .where((word) => word.length >= _ocptBudgetMatchMinWordLength)
    .toSet();

/// One candidate before it is known whether it is worth offering at all — carries the sort keys
/// alongside the [OcptBudgetMatchSuggestion] it would become, so [_ocptBudgetMatchRank] never has
/// to recompute a date distance or a word count it already has.
class _OcptBudgetMatchCandidate {
  /// The suggestion this candidate would become if it survives the filter.
  final OcptBudgetMatchSuggestion suggestion;

  /// The whole number of days between [OcptBudgetMatchSuggestion.date] and the draft's own date, or
  /// null when there is no date to measure from — sorts after every non-null distance, never as an
  /// infinite one: see [ocptBudgetMatchSuggestionsOf]'s own doc comment.
  final int? dateDistanceDays;

  /// How many significant words [OcptBudgetMatchSuggestion.label] shares with the draft's own
  /// wording — the ranking's own third key, more of a tie-break among already-plausible candidates
  /// than a match in its own right.
  final int wordOverlapCount;

  /// Whether this candidate agreed with the draft on at least one of amount, date or wording —
  /// [ocptBudgetMatchSuggestionsOf]'s own filter: a candidate agreeing on nothing is worse offered
  /// than not offered at all.
  bool get isWorthOffering =>
      suggestion.matchesAmount || suggestion.matchesDate || suggestion.matchesWording;

  /// Class constructor
  const _OcptBudgetMatchCandidate({
    required this.suggestion,
    required this.dateDistanceDays,
    required this.wordOverlapCount,
  });
}

/// Ranks what a draft movement — [isDebit], [draftAmountCents], [draftDate] and
/// [draftWording] — could settle among [commitments], [allowances], [resources] and [revenues],
/// given the project's own [projectVatRateBasisPoints].
///
/// **Which candidates are even eligible depends on the direction.** A debit (money going out) can
/// only settle a cost: [commitments] still owed — [ocptBudgetCommitmentOutstandingCentsOf] over
/// [entries] reading above zero, or unknown — and every one of [allowances] (see the file's own doc
/// comment for why none is pre-filtered). A credit (money coming in) can only settle an
/// expectation: a resource of [resources] whose [receivedByResourceId]'s own figure falls short of
/// [OcptBudgetResource.amountCents], and a revenue of [revenues] whose [receivedByRevenueId]'s own
/// figure falls short of [OcptBudgetRevenue.amountCents]. The other two kinds are never even built
/// for a given direction — money going out cannot settle a resource, and money coming in cannot
/// settle a commitment.
///
/// **The ranking is an order, not a weighted sum**, so that what wins is always explainable in one
/// sentence rather than by two figures happening to add up a certain way:
///
/// 1. **Exact amount first.** A candidate whose own [OcptBudgetMatchSuggestion.outstandingCents]
///    equals [draftAmountCents] to the cent outranks every candidate that does not, whatever else
///    agrees — the fact a user actually recognises on sight. A commitment whose cash figure cannot
///    be read ([ocptBudgetCommitmentCashCentsOf] answering null) is never a match on amount; it can
///    still win on date or wording.
/// 2. **Then date proximity.** Nearer to [draftDate] first, among candidates already tied on (1). A
///    candidate carrying no date at all — a resource, always, or a commitment/defrayal nobody dated
///    — sorts **after** every candidate that carries one, never as though it were infinitely far: a
///    resource has no date by nature, and that silence is not evidence against it.
/// 3. **Then wording.** The candidate sharing the more significant words with [draftWording] wins,
///    among candidates already tied on (1) and (2) — compared case- and accent-insensitively, on
///    words rather than on the whole string, so "Loc. caméra Couronne" finds "Couronne" —
///    [_ocptBudgetMatchWordsOf].
///
/// Ties after all three break on the candidate's own id, so the order is total and no test is ever
/// at the mercy of the input order.
///
/// **A candidate agreeing with the draft on none of amount, date or wording is dropped outright**,
/// never returned as a low-confidence guess — proposing something that agrees on nothing is worse
/// than proposing nothing, since the user then has to read it only to reject it. The survivors are
/// capped at [_ocptBudgetMatchSuggestionCap] — see that constant's own doc comment.
List<OcptBudgetMatchSuggestion> ocptBudgetMatchSuggestionsOf({
  required bool isDebit,
  required int draftAmountCents,
  required DateTime draftDate,
  required String draftWording,
  required List<OcptBudgetCommitment> commitments,
  required List<OcptBudgetEntry> entries,
  required List<OcptBudgetAllowance> allowances,
  required List<OcptBudgetResource> resources,
  required List<OcptBudgetRevenue> revenues,
  required Map<String, OcptBudgetCoveredTotal> receivedByResourceId,
  required Map<String, OcptBudgetCoveredTotal> receivedByRevenueId,
  required int? projectVatRateBasisPoints,
}) {
  final draftWords = _ocptBudgetMatchWordsOf(draftWording);

  int? dateDistanceOf(DateTime? date) =>
      date == null ? null : (date.difference(draftDate).inDays).abs();

  _OcptBudgetMatchCandidate buildCandidate({
    required OcptBudgetMatchCandidateKind kind,
    required String candidateId,
    required String label,
    required int? amountCents,
    required DateTime? date,
    required int? outstandingCents,
  }) {
    final dateDistanceDays = dateDistanceOf(date);
    final wordOverlapCount = _ocptBudgetMatchWordsOf(label).intersection(draftWords).length;

    return _OcptBudgetMatchCandidate(
      suggestion: OcptBudgetMatchSuggestion(
        kind: kind,
        candidateId: candidateId,
        label: label,
        amountCents: amountCents,
        date: date,
        outstandingCents: outstandingCents,
        matchesAmount: outstandingCents != null && outstandingCents == draftAmountCents,
        matchesDate:
            dateDistanceDays != null && dateDistanceDays <= _ocptBudgetMatchCloseDateWindowDays,
        matchesWording: wordOverlapCount > 0,
      ),
      dateDistanceDays: dateDistanceDays,
      wordOverlapCount: wordOverlapCount,
    );
  }

  final candidates = <_OcptBudgetMatchCandidate>[];

  if (isDebit) {
    for (final commitment in commitments) {
      final outstandingCents = ocptBudgetCommitmentOutstandingCentsOf(
        commitment,
        entries,
        projectVatRateBasisPoints: projectVatRateBasisPoints,
      );
      if (outstandingCents != null && outstandingCents <= 0) {
        continue;
      }

      final cashCents = ocptBudgetCommitmentCashCentsOf(
        commitment,
        projectVatRateBasisPoints: projectVatRateBasisPoints,
      );
      candidates.add(
        buildCandidate(
          kind: OcptBudgetMatchCandidateKind.commitment,
          candidateId: commitment.id,
          label: commitment.label,
          amountCents: cashCents,
          date: commitment.dueDate,
          outstandingCents: outstandingCents,
        ),
      );
    }

    for (final allowance in allowances) {
      final allowanceCents = ocptBudgetAllowanceCentsOf(allowance);
      candidates.add(
        buildCandidate(
          kind: OcptBudgetMatchCandidateKind.defrayal,
          candidateId: allowance.id,
          label: allowance.label,
          amountCents: allowanceCents,
          date: allowance.date,
          outstandingCents: allowanceCents,
        ),
      );
    }
  } else {
    for (final resource in resources) {
      final receivedCents = receivedByResourceId[resource.id]?.amountCents ?? 0;
      final outstandingCents = ocptBudgetResourceOutstandingCents(
        amountCents: resource.amountCents,
        receivedCents: receivedCents,
      );
      if (outstandingCents <= 0) {
        continue;
      }

      candidates.add(
        buildCandidate(
          kind: OcptBudgetMatchCandidateKind.resource,
          candidateId: resource.id,
          label: resource.label,
          amountCents: resource.amountCents,
          date: null,
          outstandingCents: outstandingCents,
        ),
      );
    }

    for (final revenue in revenues) {
      final receivedCents = receivedByRevenueId[revenue.id]?.amountCents ?? 0;
      final outstandingCents = revenue.amountCents - receivedCents;
      if (outstandingCents <= 0) {
        continue;
      }

      candidates.add(
        buildCandidate(
          kind: OcptBudgetMatchCandidateKind.revenue,
          candidateId: revenue.id,
          label: revenue.label,
          amountCents: revenue.amountCents,
          date: revenue.date,
          outstandingCents: outstandingCents,
        ),
      );
    }
  }

  final worthOffering = candidates.where((candidate) => candidate.isWorthOffering).toList()
    ..sort(_ocptBudgetMatchRank);

  return worthOffering
      .take(_ocptBudgetMatchSuggestionCap)
      .map((candidate) => candidate.suggestion)
      .toList();
}

/// [ocptBudgetMatchSuggestionsOf]'s own comparator — see that function's own doc comment for the
/// three keys this reads, in order, and for why a missing date sorts after every present one rather
/// than comparing as infinitely distant.
int _ocptBudgetMatchRank(_OcptBudgetMatchCandidate a, _OcptBudgetMatchCandidate b) {
  final amountRank = (a.suggestion.matchesAmount ? 0 : 1).compareTo(
    b.suggestion.matchesAmount ? 0 : 1,
  );
  if (amountRank != 0) {
    return amountRank;
  }

  final aDistance = a.dateDistanceDays;
  final bDistance = b.dateDistanceDays;
  if (aDistance == null && bDistance != null) {
    return 1;
  }
  if (aDistance != null && bDistance == null) {
    return -1;
  }
  if (aDistance != null && bDistance != null) {
    final dateRank = aDistance.compareTo(bDistance);
    if (dateRank != 0) {
      return dateRank;
    }
  }

  final wordRank = b.wordOverlapCount.compareTo(a.wordOverlapCount);
  if (wordRank != 0) {
    return wordRank;
  }

  return a.suggestion.candidateId.compareTo(b.suggestion.candidateId);
}
