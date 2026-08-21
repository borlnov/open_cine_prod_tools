// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// One entry of the [ocptBudgetCncPostes] catalogue: a poste of the CNC nomenclature the budget
/// mode seeds a fresh project's `budget_postes` table with.
class OcptBudgetCncPoste {
  /// The **constant, hard-coded UUID** this poste is seeded with — deliberately not a fresh one
  /// minted at seeding time.
  ///
  /// `OcptBudgetQuoteService` seeds these ten rows on the first read of an empty `budget_postes`
  /// table, on whichever replica gets there first; a random id per replica would mean two of them
  /// seeding the same project independently produce twenty rows for a merge to reconcile instead of
  /// ten it recognises as the same ones. This is the same device schema version 18 uses to derive
  /// `role_episodes.id` from the role it links (`OcptProjectDatabase._deriveRoleEpisodes`): a
  /// deterministic id is what lets two replicas agree without talking to each other first.
  ///
  /// **Never renamed once shipped**, for the reason `OcptCrewPosition.id`'s own doc comment gives
  /// its own: `budget_lines.posteId` and any project version payload captured before a rename would
  /// point at an id nothing seeds any more. Retiring a poste removes it from this list without
  /// reusing its id for something else; adding a new one only ever appends.
  final String id;

  /// The CNC poste number as printed (e.g. `2`, `4`), seeded into `budget_postes.code` and free to
  /// be edited afterwards like any other field of a seeded row.
  final String code;

  /// The name of the ARB key (the generated `Tr` class exposes it as a getter of the same name)
  /// this poste's detailed-header label is localised under.
  ///
  /// A plain [String] rather than a `Tr` lookup: `lib/constants/` must stay free of `Tr`. The ARB
  /// entries and the call site that resolves this key into the seed `OcptBudgetQuoteService.seed`
  /// takes are the budget mode's own, built in the milestone after this one.
  final String labelKey;

  /// The name of the ARB key this poste's simplified-header label is localised under —
  /// [labelKey]'s sibling, resolved the same way and by the same call site.
  final String simpleLabelKey;

  /// Class constructor
  const OcptBudgetCncPoste({
    required this.id,
    required this.code,
    required this.labelKey,
    required this.simpleLabelKey,
  });
}

/// The ten postes of the CNC nomenclature `OcptBudgetQuoteService` seeds a project's
/// `budget_postes` table with, on the first read of a table holding no row at all — not at project
/// creation, so an existing project gets them too (`docs/plans/budget-mode.md` §4). Seeded, never
/// frozen: every one of the ten is an ordinary row from the moment it exists, renamed, reordered or
/// deleted like any other.
///
/// Not a database table itself, since it never needs a `sortKey` or a tombstone of its own — it
/// changes with an app release, not with a project, exactly as `ocptCrewPositions` doesn't.
const List<OcptBudgetCncPoste> ocptBudgetCncPostes = [
  OcptBudgetCncPoste(
    id: 'dc130387-be90-4fc3-a406-ce271dde481a',
    code: '1',
    labelKey: 'budgetCncPosteArtisticRights',
    simpleLabelKey: 'budgetCncPosteSimpleArtisticRights',
  ),
  OcptBudgetCncPoste(
    id: '1e6a81cd-5b6e-4d79-8380-6d809e5163ec',
    code: '2',
    labelKey: 'budgetCncPostePersonnel',
    simpleLabelKey: 'budgetCncPosteSimplePersonnel',
  ),
  OcptBudgetCncPoste(
    id: 'ef67432c-e5d0-4f8d-9675-e6cabb52bbfe',
    code: '3',
    labelKey: 'budgetCncPosteCast',
    simpleLabelKey: 'budgetCncPosteSimpleCast',
  ),
  OcptBudgetCncPoste(
    id: '740eeaed-a000-4494-a755-54f0fa695d16',
    code: '4',
    labelKey: 'budgetCncPosteSocialCharges',
    simpleLabelKey: 'budgetCncPosteSimpleSocialCharges',
  ),
  OcptBudgetCncPoste(
    id: '29151ca2-1f79-42ba-a000-91a5a51d8830',
    code: '5',
    labelKey: 'budgetCncPosteSetsAndCostumes',
    simpleLabelKey: 'budgetCncPosteSimpleSetsAndCostumes',
  ),
  OcptBudgetCncPoste(
    id: 'd75aa74c-ed99-494a-bca0-3508b166ec18',
    code: '6',
    labelKey: 'budgetCncPosteTransportPerDiemsLogistics',
    simpleLabelKey: 'budgetCncPosteSimpleTransportPerDiemsLogistics',
  ),
  OcptBudgetCncPoste(
    id: '56071376-fc1c-4e05-a372-b9eaad4c368c',
    code: '7',
    labelKey: 'budgetCncPosteTechnicalEquipment',
    simpleLabelKey: 'budgetCncPosteSimpleTechnicalEquipment',
  ),
  OcptBudgetCncPoste(
    id: '8174adcf-69e4-4871-8798-0d363056b6f2',
    code: '8',
    labelKey: 'budgetCncPosteLaboratoryAndPostProduction',
    simpleLabelKey: 'budgetCncPosteSimpleLaboratoryAndPostProduction',
  ),
  OcptBudgetCncPoste(
    id: 'b956cca3-792c-40c4-966b-8d3ab0c5ce55',
    code: '9',
    labelKey: 'budgetCncPosteInsuranceAndMiscellaneous',
    simpleLabelKey: 'budgetCncPosteSimpleInsuranceAndMiscellaneous',
  ),
  OcptBudgetCncPoste(
    id: 'd4296a9e-8d0d-4e8c-927e-23fb9397fa34',
    code: '10',
    labelKey: 'budgetCncPosteOverheads',
    simpleLabelKey: 'budgetCncPosteSimpleOverheads',
  ),
];
