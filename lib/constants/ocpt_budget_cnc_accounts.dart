// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// One entry of the [ocptBudgetCncAccounts] catalogue: an account of the CNC nomenclature the
/// budget mode seeds a fresh project's `budget_postes` table with.
class OcptBudgetCncAccount {
  /// The **constant, hard-coded UUID** this account is seeded with — deliberately not a fresh one
  /// minted at seeding time.
  ///
  /// `OcptBudgetQuoteService` seeds these ten rows on the first read of an empty `budget_postes`
  /// table, on whichever replica gets there first; a random id per replica would mean two of them
  /// seeding the same project independently produce twenty rows for a merge to reconcile instead of
  /// ten it recognises as the same ones: a deterministic id is what lets two replicas agree without
  /// talking to each other first.
  ///
  /// **Never renamed once shipped**, for the reason `OcptCrewPosition.id`'s own doc comment gives
  /// its own: `budget_lines.accountId` and any project version payload captured before a rename
  /// would point at an id nothing seeds any more. Retiring an account removes it from this list
  /// without reusing its id for something else; adding a new one only ever appends.
  final String id;

  /// The CNC account number as printed (e.g. `2`, `4`), seeded into `budget_postes.code` and free
  /// to be edited afterwards like any other field of a seeded row.
  final String code;

  /// The name of the ARB key (the generated `Tr` class exposes it as a getter of the same name)
  /// this account's detailed-header label is localised under.
  ///
  /// A plain [String] rather than a `Tr` lookup: `lib/constants/` must stay free of `Tr`. The ARB
  /// entries and the call site that resolves this key into the seed `OcptBudgetQuoteService.seed`
  /// takes are the budget mode's own (`lib/ui/widgets/helpers/ocpt_budget_labels.dart`).
  final String labelKey;

  /// The name of the ARB key this account's simplified-header label is localised under —
  /// [labelKey]'s sibling, resolved the same way and by the same call site.
  final String simpleLabelKey;

  /// Class constructor
  const OcptBudgetCncAccount({
    required this.id,
    required this.code,
    required this.labelKey,
    required this.simpleLabelKey,
  });
}

/// The ten accounts of the CNC nomenclature `OcptBudgetQuoteService` seeds a project's
/// `budget_postes` table with, on the first read of a table holding no row at all — not at project
/// creation, so an existing project gets them too (ADR 0028). Seeded, never
/// frozen: every one of the ten is an ordinary row from the moment it exists, renamed, reordered or
/// deleted like any other.
///
/// Not a database table itself, since it never needs a `sortKey` or a tombstone of its own — it
/// changes with an app release, not with a project, exactly as `ocptCrewPositions` doesn't.
const List<OcptBudgetCncAccount> ocptBudgetCncAccounts = [
  OcptBudgetCncAccount(
    id: 'dc130387-be90-4fc3-a406-ce271dde481a',
    code: '1',
    labelKey: 'budgetCncAccountArtisticRights',
    simpleLabelKey: 'budgetCncAccountSimpleArtisticRights',
  ),
  OcptBudgetCncAccount(
    id: '1e6a81cd-5b6e-4d79-8380-6d809e5163ec',
    code: '2',
    labelKey: 'budgetCncAccountPersonnel',
    simpleLabelKey: 'budgetCncAccountSimplePersonnel',
  ),
  OcptBudgetCncAccount(
    id: 'ef67432c-e5d0-4f8d-9675-e6cabb52bbfe',
    code: '3',
    labelKey: 'budgetCncAccountCast',
    simpleLabelKey: 'budgetCncAccountSimpleCast',
  ),
  OcptBudgetCncAccount(
    id: '740eeaed-a000-4494-a755-54f0fa695d16',
    code: '4',
    labelKey: 'budgetCncAccountSocialCharges',
    simpleLabelKey: 'budgetCncAccountSimpleSocialCharges',
  ),
  OcptBudgetCncAccount(
    id: '29151ca2-1f79-42ba-a000-91a5a51d8830',
    code: '5',
    labelKey: 'budgetCncAccountSetsAndCostumes',
    simpleLabelKey: 'budgetCncAccountSimpleSetsAndCostumes',
  ),
  OcptBudgetCncAccount(
    id: 'd75aa74c-ed99-494a-bca0-3508b166ec18',
    code: '6',
    labelKey: 'budgetCncAccountTransportPerDiemsLogistics',
    simpleLabelKey: 'budgetCncAccountSimpleTransportPerDiemsLogistics',
  ),
  OcptBudgetCncAccount(
    id: '56071376-fc1c-4e05-a372-b9eaad4c368c',
    code: '7',
    labelKey: 'budgetCncAccountTechnicalEquipment',
    simpleLabelKey: 'budgetCncAccountSimpleTechnicalEquipment',
  ),
  OcptBudgetCncAccount(
    id: '8174adcf-69e4-4871-8798-0d363056b6f2',
    code: '8',
    labelKey: 'budgetCncAccountLaboratoryAndPostProduction',
    simpleLabelKey: 'budgetCncAccountSimpleLaboratoryAndPostProduction',
  ),
  OcptBudgetCncAccount(
    id: 'b956cca3-792c-40c4-966b-8d3ab0c5ce55',
    code: '9',
    labelKey: 'budgetCncAccountInsuranceAndMiscellaneous',
    simpleLabelKey: 'budgetCncAccountSimpleInsuranceAndMiscellaneous',
  ),
  OcptBudgetCncAccount(
    id: 'd4296a9e-8d0d-4e8c-927e-23fb9397fa34',
    code: '10',
    labelKey: 'budgetCncAccountOverheads',
    simpleLabelKey: 'budgetCncAccountSimpleOverheads',
  ),
];
