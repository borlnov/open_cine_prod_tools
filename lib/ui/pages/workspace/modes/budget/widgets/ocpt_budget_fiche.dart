// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/models/ocpt_asset_ref.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_line.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_resource.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_revenue.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_covered_total.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_journal.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_projection.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_totals.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_selection.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_tax_basis.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_fiche_commitment.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_fiche_empty_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_fiche_entry.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_fiche_line.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_fiche_poste.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_fiche_receipt.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_fiche_resource.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_fiche_revenue.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_budget_labels.dart';

/// The right dock's own `Inspector` tab, once and for all: a single panel, polymorphic on
/// [selection], drawing whatever `OcptBudgetSelection` variant is currently selected —
/// `docs/architecture/budget.md`'s "The right dock belongs to the view, not to the mode".
///
/// Every variant draws the same grammar, top to bottom: a breadcrumb up to the document, the
/// object's own name and amount, an optional hint (and, for a resource or a taking, a status badge
/// beside it), a small stepper of its states, the figures that make it up, the outstanding amount
/// in large type, one primary action and at most two secondary ones. The table says where things
/// stand; this fiche says where they come from and what to do next.
///
/// **The poste's and the quote line's own editable fields move here** (the tree draws every quote
/// line, commitment and entry as a row of its own, so this panel stops listing them): a poste keeps
/// its label, code, simple label and typed estimate to complete; a quote line keeps its label,
/// quantity, unit, unit price, tax choice, VAT override and notes.
///
/// A composite panel (`docs/architecture/foundations.md`'s own idiom): [isReadOnly] withholds every
/// writing affordance — every callback simply arrives null under a previewed version, this widget
/// never disabling one instead.
///
/// This widget resolves the object [selection] names off the whole catalogues it is handed
/// ([postes], [commitments], [entries], [resources], [revenues]) rather than being handed the
/// object pre-resolved, exactly as `OcptBudgetCostTracking` already resolves its own rows off
/// `selection` and the same catalogues — the mode hands in what it has on state, this panel finds
/// its own subject and its own ancestors (a line's own poste, a commitment's own line) in it.
class OcptBudgetFiche extends StatelessWidget {
  /// What is currently selected, or null while nothing is — the tab then shows a plain hint.
  final OcptBudgetSelection? selection;

  /// Every live poste of the project, each carrying its own lines.
  final List<OcptBudgetPoste> postes;

  /// Every live commitment of the project.
  final List<OcptBudgetCommitment> commitments;

  /// Every live journal entry of the project.
  final List<OcptBudgetEntry> entries;

  /// Every live financing resource of the project.
  final List<OcptBudgetResource> resources;

  /// Every live taking of the project.
  final List<OcptBudgetRevenue> revenues;

  /// Which basis every amount is currently read in — the quote's own toggle, read by the poste and
  /// the quote-line variants alone: every other variant reads money that has moved, always
  /// tax-inclusive (`docs/architecture/budget.md`).
  final OcptBudgetTaxBasis taxBasis;

  /// The project's default VAT rate, in basis points, or null.
  final int? defaultVatRateBasisPoints;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Whether the header's simplified/detailed switch currently reads simplified — a poste's own
  /// displayed name.
  final bool isSimplified;

  /// Whether the mode shows a project version being previewed read-only.
  final bool isReadOnly;

  /// A live element's own name, keyed by its id — resolves a quote line's own `elementId` into its
  /// own quiet hint line.
  final Map<String, String> elementNameByElementId;

  /// Every live voucher, keyed by the `budget_entries` row it evidences — an entry's own hint reads
  /// whether one is attached.
  final Map<String, OcptAssetRef> receiptsByEntryId;

  /// What has actually come in against each financing resource, keyed by its own id — a resource
  /// with no key here has received nothing at all (`ocptBudgetReceivedByResourceId`'s own doc
  /// comment).
  final Map<String, OcptBudgetCoveredTotal> receivedByResourceId;

  /// What has actually come in against each taking, keyed by its own id — mirrors
  /// [receivedByResourceId].
  final Map<String, OcptBudgetCoveredTotal> receivedByRevenueId;

  /// A poste's or a line's current value for `field` — a pending edit, or its own stored value.
  final String Function(String targetId, OcptBudgetField field, String storedValue) fieldValueOf;

  /// Called with a poste's or a line's id, which field and the raw text just typed, or null while
  /// [isReadOnly].
  final void Function(String targetId, OcptBudgetField field, String rawValue)? onFieldChanged;

  /// Called with the poste's id when its own `Derive again` action is clicked, or null while
  /// [isReadOnly]. Not an irreversible action, so the mode answers this by dispatching straight
  /// away, with no `OcptConfirmDialog`.
  final ValueChanged<String>? onPosteEstimateToCompleteDerivedRequested;

  /// Called with a line's id and the including/excluding-tax choice just picked, or null while
  /// [isReadOnly].
  final void Function(String lineId, {required bool isTaxInclusive})? onLineTaxInclusiveChanged;

  /// Called with a line's id when its own `Inherit` action is clicked, or null while [isReadOnly].
  final ValueChanged<String>? onLineVatRateInheritedRequested;

  /// Called with a line's id when `Commit this line…` is clicked, or null while [isReadOnly].
  final ValueChanged<String>? onLineCommitRequested;

  /// Called with a line's id when its own `Pay` action is clicked on an un-promoted line — pays the
  /// line directly, the commitment created transparently behind the payment — or null while
  /// [isReadOnly]. The common gesture: a production quotes a cost and pays it without ever thinking
  /// of the commitment in between.
  final ValueChanged<String>? onLinePayDirectlyRequested;

  /// Called with a line's id when its own promoted, unsettled commitment is to be paid — opens the
  /// entry dialog pre-filled from that commitment, or null while [isReadOnly].
  final ValueChanged<String>? onLineSettleRequested;

  /// Called with a line's id when `Show the commitment` is clicked — never withheld under
  /// [isReadOnly], since it only moves the reader to a view they may open by hand. Offered from the
  /// promoted-and-unsettled branch alone: a settled commitment has nowhere left to be shown, `À
  /// venir` holding unsettled commitments only.
  final ValueChanged<String>? onLineShowCommitmentRequested;

  /// Called with a line's id when `Cancel the commitment` is clicked, or null while [isReadOnly] or
  /// there is nothing to cancel.
  final ValueChanged<String>? onLineUncommitRequested;

  /// Called with a line's id when its own `Delete` action is clicked, or null while [isReadOnly].
  final ValueChanged<String>? onLineDeletionRequested;

  /// Called with a commitment when its own `Pay` action is clicked, or null while [isReadOnly] or
  /// it is already settled.
  final ValueChanged<OcptBudgetCommitment>? onCommitmentSettleRequested;

  /// Called with a commitment when its own `Edit` action is clicked, or null while [isReadOnly].
  final ValueChanged<OcptBudgetCommitment>? onCommitmentEditRequested;

  /// Called with a commitment's id when its own `Delete` action is clicked, or null while
  /// [isReadOnly].
  final ValueChanged<String>? onCommitmentDeletionRequested;

  /// Called when the off-line banner's own `Add to the quote` action is clicked, on the commitment
  /// currently shown, or null while [isReadOnly] — `ocptBudgetCommitmentIsOffLine` says which
  /// commitment draws the banner at all. Promotes the commitment into a quote line it is then
  /// linked to (`docs/architecture/budget.md`'s "A quote line is paid directly" — this is that same
  /// shape, run the other way round, on a commitment that already exists).
  final VoidCallback? onCommitmentPromoteToQuoteRequested;

  /// Called with an entry when its own `Edit` action is clicked, or null while [isReadOnly].
  final ValueChanged<OcptBudgetEntry>? onEntryEditRequested;

  /// Called with an entry's id when its own `Delete` action is clicked, or null while [isReadOnly].
  final ValueChanged<String>? onEntryDeletionRequested;

  /// Called when the off-line-debit banner's own `Add to the quote` action is clicked, on the entry
  /// currently shown, or null while [isReadOnly] — `ocptBudgetEntryIsOffLineDebit` says which entry
  /// draws the banner at all. Promotes the entry into a quote line and a settled commitment naming
  /// it (`docs/architecture/budget.md`'s "A quote line is paid directly, the commitment made for
  /// it" — this is that same shape, run the other way round, on a debit that already exists).
  final VoidCallback? onEntryPromoteToQuoteRequested;

  /// Called when the off-line-debit banner's own `Move off-quote` action is clicked, on the entry
  /// currently shown, or null while [isReadOnly]. Clears the entry's own poste, so it reads as an
  /// honest off-quote spend from then on (`docs/architecture/budget.md`'s "Off-quote spending is
  /// named, never hidden").
  final VoidCallback? onEntryMoveOffQuoteRequested;

  /// Called with a resource when its own `Receive` action is clicked, or null while [isReadOnly].
  final ValueChanged<OcptBudgetResource>? onResourceReceiptRequested;

  /// Called with a resource when its own `Edit` action is clicked, or null while [isReadOnly].
  final ValueChanged<OcptBudgetResource>? onResourceEditRequested;

  /// Called with a resource's id when its own `Delete` action is clicked, or null while
  /// [isReadOnly].
  final ValueChanged<String>? onResourceDeletionRequested;

  /// Called with a taking when its own `Receive` action is clicked, or null while [isReadOnly].
  final ValueChanged<OcptBudgetRevenue>? onRevenueReceiptRequested;

  /// Called with a taking when its own `Edit` action is clicked, or null while [isReadOnly].
  final ValueChanged<OcptBudgetRevenue>? onRevenueEditRequested;

  /// Called with a taking's id when its own `Delete` action is clicked, or null while [isReadOnly].
  final ValueChanged<String>? onRevenueDeletionRequested;

  /// Class constructor
  const OcptBudgetFiche({
    super.key,
    required this.selection,
    required this.postes,
    required this.commitments,
    required this.entries,
    required this.resources,
    required this.revenues,
    required this.taxBasis,
    required this.defaultVatRateBasisPoints,
    required this.currencyCode,
    required this.isSimplified,
    required this.isReadOnly,
    required this.elementNameByElementId,
    required this.receiptsByEntryId,
    required this.receivedByResourceId,
    required this.receivedByRevenueId,
    required this.fieldValueOf,
    required this.onFieldChanged,
    required this.onPosteEstimateToCompleteDerivedRequested,
    required this.onLineTaxInclusiveChanged,
    required this.onLineVatRateInheritedRequested,
    required this.onLineCommitRequested,
    required this.onLinePayDirectlyRequested,
    required this.onLineSettleRequested,
    required this.onLineShowCommitmentRequested,
    required this.onLineUncommitRequested,
    required this.onLineDeletionRequested,
    required this.onCommitmentSettleRequested,
    required this.onCommitmentEditRequested,
    required this.onCommitmentDeletionRequested,
    required this.onCommitmentPromoteToQuoteRequested,
    required this.onEntryEditRequested,
    required this.onEntryDeletionRequested,
    required this.onEntryPromoteToQuoteRequested,
    required this.onEntryMoveOffQuoteRequested,
    required this.onResourceReceiptRequested,
    required this.onResourceEditRequested,
    required this.onResourceDeletionRequested,
    required this.onRevenueReceiptRequested,
    required this.onRevenueEditRequested,
    required this.onRevenueDeletionRequested,
  });

  /// Build the budget fiche as a [SingleChildScrollView].
  @override
  Widget build(BuildContext context) {
    final selection = this.selection;
    if (selection == null) {
      return const OcptBudgetFicheEmptyState();
    }

    // The part the selection names, or null while its subject has disappeared from a freshly loaded
    // snapshot — which is answered with the plain hint rather than left to throw.
    Widget? variant;
    switch (selection) {
      case OcptBudgetPosteSelection(:final posteId):
        final poste = posteById(posteId);
        if (poste != null) {
          variant = OcptBudgetFichePoste(fiche: this, poste: poste);
        }
      case OcptBudgetLineSelection(:final lineId):
        final poste = posteOfLine(lineId);
        final line = poste == null ? null : lineById(lineId);
        if (poste != null && line != null) {
          variant = OcptBudgetFicheLine(fiche: this, poste: poste, line: line);
        }
      case OcptBudgetCommitmentSelection(:final commitmentId):
        final commitment = commitments.firstWhereOrNull(
          (commitment) => commitment.id == commitmentId,
        );
        if (commitment != null) {
          variant = OcptBudgetFicheCommitment(fiche: this, commitment: commitment);
        }
      case OcptBudgetEntrySelection(:final entryId):
        final entry = entries.firstWhereOrNull((entry) => entry.id == entryId);
        if (entry != null) {
          variant = OcptBudgetFicheEntry(fiche: this, entry: entry);
        }
      case OcptBudgetResourceSelection(:final resourceId):
        final resource = resources.firstWhereOrNull((resource) => resource.id == resourceId);
        if (resource != null) {
          variant = OcptBudgetFicheResource(fiche: this, resource: resource);
        }
      case OcptBudgetRevenueSelection(:final revenueId):
        final revenue = revenues.firstWhereOrNull((revenue) => revenue.id == revenueId);
        if (revenue != null) {
          variant = OcptBudgetFicheRevenue(fiche: this, revenue: revenue);
        }
      // A receipt sub-row of the resources tree selects the entry it settles.
      case OcptBudgetReceiptSelection(:final receiptId):
        final entry = entries.firstWhereOrNull((entry) => entry.id == receiptId);
        if (entry != null) {
          variant = OcptBudgetFicheReceipt(fiche: this, entry: entry);
        }
    }
    if (variant == null) {
      return const OcptBudgetFicheEmptyState();
    }

    // The one scroll view every variant shares, kept here rather than in each variant so that
    // switching from one selection to another leaves the scroll position where it was.
    return SingleChildScrollView(padding: const EdgeInsets.all(12), child: variant);
  }

  /// Get [postes]' own entry naming [posteId], or null while no live poste carries that id.
  OcptBudgetPoste? posteById(String posteId) =>
      postes.firstWhereOrNull((poste) => poste.id == posteId);

  /// Get the poste [lineId]'s own quote line belongs to, or null while no live poste carries it.
  OcptBudgetPoste? posteOfLine(String lineId) =>
      postes.firstWhereOrNull((poste) => poste.lines.any((line) => line.id == lineId));

  /// Get [lineId]'s own live quote line, or null.
  OcptBudgetLine? lineById(String lineId) {
    for (final poste in postes) {
      final line = poste.lines.firstWhereOrNull((line) => line.id == lineId);
      if (line != null) {
        return line;
      }
    }
    return null;
  }

  /// Get [amountCents] formatted in [currencyCode], or [ocptBudgetEmptyValue] while it is null.
  String amountLabelOf(int? amountCents) =>
      amountCents == null ? ocptBudgetEmptyValue : ocptBudgetAmountLabel(amountCents, currencyCode);

  /// Get `posteId`'s own paid total, in cents, tax-inclusive — 0 while nothing is entered against
  /// it,
  /// read off [entries] directly since the fiche resolves its own poste rather than being handed
  /// one pre-resolved.
  int paidCentsOf(String posteId) =>
      ocptBudgetPaidCentsByPosteId(
        entries,
        projectVatRateBasisPoints: defaultVatRateBasisPoints,
      )[posteId]?.amountCents ??
      0;

  /// Get `posteId`'s own committed total, in cents, tax-inclusive — mirrors [paidCentsOf].
  int committedCentsOf(String posteId) =>
      ocptBudgetCommittedCentsByPosteId(
        commitments,
        entries: entries,
        projectVatRateBasisPoints: defaultVatRateBasisPoints,
      )[posteId]?.amountCents ??
      0;

  /// Get `posteId`'s own in-kind covered total, in cents — mirrors [paidCentsOf], read off [postes]
  /// directly since the fiche resolves its own poste rather than being handed one pre-resolved.
  int inKindCoveredCentsOf(String posteId) =>
      ocptBudgetInKindCoveredCentsByPosteId(postes)[posteId] ?? 0;
}
