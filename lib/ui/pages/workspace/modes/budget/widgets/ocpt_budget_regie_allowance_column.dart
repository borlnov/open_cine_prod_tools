// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_allowance.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_covered_total.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_reimbursements.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_regie.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_regie_allowance_defrayal_row.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_regie_allowance_header_row.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_regie_allowance_no_person_row.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_regie_allowance_person_row.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_regie_allowance_reimbursement_row.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_regie_allowance_total_row.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_regie_allowance_tree_row.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_regie_metrics.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_regie_table_pane.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_horizontal_scroll_view.dart';

/// The right column: the heading band with its caption, then the defrayal tree — its own creation
/// gesture removed, every defrayal now typed through the capture wizard's own `defrayPerson`
/// gesture instead.
///
/// **A tree grouped by person, mirroring `OcptBudgetFinancing`'s own resources tree exactly**: a
/// person group row carries the régie's own running account for them — `ADVANCED`, `REIMBURSED`,
/// `OWED` — mirroring the resources tree's `Promis`/`Rentré`/`Reste à venir`, expanding onto their
/// own defrayals then their own reimbursements. See the class doc comment above for the money rules
/// and [_rowsOf] for how the tree is flattened.
class OcptBudgetRegieAllowanceColumn extends StatelessWidget {
  /// See [OcptBudgetRegie.allowances].
  final List<OcptBudgetAllowance> allowances;

  /// See [OcptBudgetRegie.entries].
  final List<OcptBudgetEntry> entries;

  /// See [OcptBudgetRegie.reimbursedByPersonId].
  final Map<String, OcptBudgetCoveredTotal> reimbursedByPersonId;

  /// See [OcptBudgetRegie.defaultVatRateBasisPoints].
  final int? defaultVatRateBasisPoints;

  /// See [OcptBudgetRegie.roles].
  final List<OcptRole> roles;

  /// See [OcptBudgetRegie.people].
  final List<OcptPerson> people;

  /// See [OcptBudgetRegie.currencyCode].
  final String currencyCode;

  /// See [OcptBudgetRegie.isReadOnly].
  final bool isReadOnly;

  /// See [OcptBudgetRegie.expandedNodeIds].
  final Set<String> expandedNodeIds;

  /// See [OcptBudgetRegie.onNodeExpansionToggled].
  final ValueChanged<String> onNodeExpansionToggled;

  /// See [OcptBudgetRegie.onPersonOpenRequested].
  final ValueChanged<String> onPersonOpenRequested;

  /// Called with a defrayal's id to edit it, or null while editing is withheld — see
  /// [OcptBudgetRegie.onAllowanceEditRequested].
  final ValueChanged<String>? onEditRequested;

  /// Called with a defrayal's id to delete it, or null while deleting is withheld — see
  /// [OcptBudgetRegie.onAllowanceDeletionRequested].
  final ValueChanged<String>? onDeletionRequested;

  /// Called with a person's id to reimburse them, or null while reimbursing is withheld — see
  /// [OcptBudgetRegie.onPersonReimburseRequested].
  final ValueChanged<String>? onReimburseRequested;

  /// The height the table card is drawn at, or null while the panes sit side by side and the card
  /// takes whatever height the heading band leaves it — see [ocptBudgetRegieStackedMinRowCount].
  final double? tableHeight;

  /// Get [people], keyed by their own id.
  Map<String, OcptPerson> get _personById => {for (final person in people) person.id: person};

  /// Get [roles], keyed by the person each one is played by — a role naming no person carries no
  /// key.
  Map<String, OcptRole> get _roleByPersonId => {
    for (final role in roles)
      if (role.personId != null) role.personId!: role,
  };

  /// Class constructor
  const OcptBudgetRegieAllowanceColumn({
    super.key,
    required this.allowances,
    required this.entries,
    required this.reimbursedByPersonId,
    required this.defaultVatRateBasisPoints,
    required this.roles,
    required this.people,
    required this.currencyCode,
    required this.isReadOnly,
    required this.expandedNodeIds,
    required this.tableHeight,
    required this.onNodeExpansionToggled,
    required this.onPersonOpenRequested,
    required this.onEditRequested,
    required this.onDeletionRequested,
    required this.onReimburseRequested,
  });

  /// Build the budget regie allowance column as a [Column].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final rows = _rowsOf();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      // Stated by its own rows once it is stacked — see the catering column's own reading.
      mainAxisSize: tableHeight == null ? MainAxisSize.max : MainAxisSize.min,
      children: [
        Text(tr.budgetRegieAllowancesSectionTitle, style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          tr.budgetRegieAllowancesHint,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        OcptBudgetRegieTablePane(
          height: tableHeight,
          child: Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: allowances.isEmpty
                  ? Center(
                      child: Text(
                        tr.budgetRegieAllowancesEmptyHint,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) => OcptHorizontalScrollView(
                        child: SizedBox(
                          width: math.max(
                            constraints.maxWidth,
                            ocptBudgetRegieAllowanceMinTableWidth,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const OcptBudgetRegieAllowanceHeaderRow(),
                              const Divider(height: 1),
                              Expanded(
                                child: ListView.builder(
                                  itemCount: rows.length,
                                  itemBuilder: (context, index) => _rowOf(rows[index]),
                                ),
                              ),
                              const Divider(height: 1),
                              OcptBudgetRegieAllowanceTotalRow(
                                allowances: allowances,
                                entries: entries,
                                defaultVatRateBasisPoints: defaultVatRateBasisPoints,
                                currencyCode: currencyCode,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  /// Get the whole tree, flattened top to bottom into one list — mirrors
  /// `OcptBudgetFinancing._rowsOf`'s own reading exactly: a person group row draws whenever a
  /// live defrayal or a live reimbursement names them, its own sub-rows draw only while their own
  /// id sits in [expandedNodeIds]. A defrayal naming nobody draws as its own group of one, in the
  /// list's own `sortKey` order, right where [allowances] would have put it — see
  /// `OcptBudgetRegieAllowanceNoPersonGroupRow`'s own doc comment.
  ///
  /// **A person is named twice over: by their own defrayals and by their own reimbursements**, and
  /// either alone is enough to draw their group — a person reimbursed against a défraiement since
  /// deleted still has a running account worth reading. Every person a live defrayal names is added
  /// first, in [allowances]' own order; a person reimbursed but never defrayed is appended after,
  /// in [entries]' own order, since nothing in [allowances] ever named them.
  List<OcptBudgetRegieAllowanceTreeRow> _rowsOf() {
    final rows = <OcptBudgetRegieAllowanceTreeRow>[];
    final seenPersonIds = <String>{};

    void addPersonGroup(String personId) {
      if (!seenPersonIds.add(personId)) {
        return;
      }

      final advancedCents = ocptBudgetPersonAdvancedCents(personId, allowances);
      final reimbursedCents = ocptBudgetPersonReimbursedCentsOf(
        personId,
        entries,
        projectVatRateBasisPoints: defaultVatRateBasisPoints,
      ).amountCents;
      final isExpanded = expandedNodeIds.contains(personId);

      rows.add(
        OcptBudgetRegieAllowancePersonGroupRow(
          personId: personId,
          person: _personById[personId],
          role: _roleByPersonId[personId],
          advancedCents: advancedCents,
          reimbursedCents: reimbursedCents,
          outstandingCents: ocptBudgetPersonOutstandingCents(
            advancedCents: advancedCents,
            reimbursedCents: reimbursedCents,
          ),
          isExpanded: isExpanded,
        ),
      );
      if (!isExpanded) {
        return;
      }

      for (final allowance in allowances) {
        if (allowance.personId == personId) {
          rows.add(OcptBudgetRegieAllowanceDefrayalSubRow(allowance: allowance));
        }
      }
      for (final entry in entries) {
        if (entry.personId == personId) {
          rows.add(OcptBudgetRegieAllowanceReimbursementSubRow(entry: entry));
        }
      }
    }

    for (final allowance in allowances) {
      final personId = allowance.personId;
      if (personId == null) {
        rows.add(OcptBudgetRegieAllowanceNoPersonGroupRow(allowance: allowance));
        continue;
      }

      addPersonGroup(personId);
    }
    for (final entry in entries) {
      final personId = entry.personId;
      if (personId != null) {
        addPersonGroup(personId);
      }
    }

    return rows;
  }

  /// Build the widget for one flattened [row].
  Widget _rowOf(OcptBudgetRegieAllowanceTreeRow row) => switch (row) {
    OcptBudgetRegieAllowancePersonGroupRow() => OcptBudgetRegieAllowancePersonRow(
      person: row.person,
      role: row.role,
      advancedCents: row.advancedCents,
      reimbursedCents: row.reimbursedCents,
      outstandingCents: row.outstandingCents,
      currencyCode: currencyCode,
      isExpanded: row.isExpanded,
      onTwistyTap: () => onNodeExpansionToggled(row.personId),
      // Navigation, not a write: never withheld under [isReadOnly] — mirrors the very same reading
      // this menu entry already followed on the flat table.
      onPersonOpenRequested: () => onPersonOpenRequested(row.personId),
      onReimburseRequested: isReadOnly || onReimburseRequested == null
          ? null
          : () => onReimburseRequested?.call(row.personId),
    ),
    OcptBudgetRegieAllowanceNoPersonGroupRow() => OcptBudgetRegieAllowanceNoPersonRow(
      allowance: row.allowance,
      currencyCode: currencyCode,
      onTap: isReadOnly || onEditRequested == null
          ? null
          : () => onEditRequested?.call(row.allowance.id),
      onDeletionRequested: isReadOnly || onDeletionRequested == null
          ? null
          : () => onDeletionRequested?.call(row.allowance.id),
    ),
    OcptBudgetRegieAllowanceDefrayalSubRow() => OcptBudgetRegieAllowanceDefrayalRow(
      allowance: row.allowance,
      currencyCode: currencyCode,
      onTap: isReadOnly || onEditRequested == null
          ? null
          : () => onEditRequested?.call(row.allowance.id),
      onPersonOpenRequested: () => onPersonOpenRequested(row.allowance.personId!),
      onDeletionRequested: isReadOnly || onDeletionRequested == null
          ? null
          : () => onDeletionRequested?.call(row.allowance.id),
    ),
    OcptBudgetRegieAllowanceReimbursementSubRow() => OcptBudgetRegieAllowanceReimbursementRow(
      entry: row.entry,
      defaultVatRateBasisPoints: defaultVatRateBasisPoints,
      currencyCode: currencyCode,
    ),
  };
}
