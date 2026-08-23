// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_resource.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_group_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_empty_mode.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_budget_labels.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_financing.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_totals.dart';

/// The `Status` column's own fixed width, in logical pixels — matches
/// `OcptBudgetCommittedSpending`'s own status column.
const double _ocptFinancingStatusColumnWidth = 132;

/// The `Amount`, `Received` and `Outstanding` columns' own fixed width, in logical pixels.
const double _ocptFinancingAmountColumnWidth = 108;

/// The trailing `⋮` menu column's own fixed width, in logical pixels — matches every other table
/// of this mode's own menu column.
const double _ocptFinancingMenuColumnWidth = 36;

/// The budget mode's financing view: a KPI row across the top, then the plan itself, one bordered
/// card per `OcptBudgetResourceGroupKind`, in enum order.
///
/// **Creating a resource is three explicit gestures, one per `OcptBudgetResourceGroupKind`, not
/// one.** The product owner's own words motivate the split: *"Ajouter une caméra qui est valorisée
/// n'est pas la même chose que d'ajouter du vrai argent qui va servir à la production pour acheter à
/// manger"* — a valuation and real money are not the same gesture, even though both end up as a row
/// of the same table. `_OcptFinancingKpiRow`'s own `+ Resource` control is a `MenuAnchor` anchored
/// on one button, offering the three kinds by name (`Subvention`/`Apport en numéraire`/`Apport en
/// nature`) — chosen over three separate buttons, which the row has no width to spare for beside its
/// three KPIs, and over a `Wrap` of `MenuItemButton`s, which throws the moment a `MenuAnchor` hands
/// one an unbounded width (`AGENTS.md`'s own known pitfall). Picking one calls
/// [onResourceCreationRequested] with the kind picked, and `OcptBudgetResourceDialog` opens on it
/// already set, stated in the dialog's own title — see that dialog's own class doc comment for how
/// the form itself is worded once the kind is known. The kind stays editable on an existing
/// resource, exactly as it is today.
///
/// **No inspector.** A resource's row selects it ([onResourceSelected]) purely as a highlight —
/// `OcptBudgetState.selectedResourceId`, read and written exactly as `selectedPosteId` already is —
/// rather than opening a right-dock tab. `OcptBudgetRightDockTab` carries exactly two tabs,
/// `Inspector` (built entirely around a poste's own quote lines) and `Versions`, and a resource has
/// no lines, no expandable card and nothing this dock's existing `Inspector` tab could show without
/// growing a conditional branch of its own onto a shape it was never built to hold. Rather than
/// inventing a second, competing inspector concept for one more record kind, this view keeps its
/// own selection **select-and-highlight only**: a resource's own fields are read and written
/// through `OcptBudgetResourceDialog` instead, reached from the row's own `⋮` menu.
///
/// **The one row kind with a branch: an in-kind resource with no entry naming it.** A contribution
/// in kind is *valued*, not collected — equipment lent free of charge, work donated, a lab pass
/// given — so "how much of it has arrived" is not a question with an answer for as long as nothing
/// has actually moved against it, exactly the silence `docs/architecture/budget.md`'s own "What the
/// mode still does not show" already keeps for a poste's own `Consumed` column carrying no quote at
/// all: a figure that cannot exist, not one that merely happens to be absent. The moment an entry
/// does name such a resource — the production actually logs the loan, say, once it is returned or
/// valued for real — `OcptBudgetSnapshot.receivedByResourceId` carries a key for it and the real
/// figures print instead: this app never hides a movement that actually happened. No other row kind
/// reads either column any differently, [receivedCentsOf] (the ordinary `?? 0` reading
/// `OcptBudgetState.receivedCentsOf` already gives every other row) being enough for a subsidy or a
/// cash contribution, which are real money either already in the account or genuinely still not.
///
/// A composite panel (`docs/architecture/foundations.md`'s own idiom): takes [isReadOnly] rather
/// than a null callback per affordance, and withholds — never disables — every one of its own
/// writing affordances under it: the `+ Resource` action and a row's own `⋮` menu entries
/// (`Edit`/`Record a receipt`/`Undo the last receipt`/`Delete`).
///
/// **One column header, above every group card, rather than one per card.** The five columns
/// (`Label`, `Status`, `Amount`, `Received`, `Outstanding`) read identically whichever group a row
/// sits in, so naming them once, in [_OcptFinancingColumnHeaderRow], is what
/// `OcptBudgetCostTracking`'s own header row already does for a table with one pinned pane rather
/// than several bordered cards; repeating the same five words inside every card, above a group
/// heading that already names the card itself, would be noise a reader has to skip past group after
/// group. It sits between the KPI row and the list of cards, aligned to a row's own five columns by
/// sharing their exact widths.
///
/// **`Record a receipt` is withheld — never disabled — once a resource is fully received
/// (`received >= amount`), and on any in-kind resource at all, entered or not.** A contribution in
/// kind is valued rather than collected (see "An in-kind contribution is valued, not collected" in
/// `docs/architecture/budget.md`), so no cash will ever move for it and the gesture that records a
/// cash movement has nothing to offer here; a resource whose received total already meets its own
/// amount has nothing left to receive either, though a **partially** received one keeps offering
/// it — the ordinary case of several instalments landing against the one resource. **`Undo the last
/// receipt`** is the way back a mis-click into `Record a receipt` used to have none of: offered the
/// moment a resource has received anything at all, it tombstones the most recently recorded live
/// `budget_entries` credit naming that resource — `ocptBudgetLatestReceiptEntryIdOf`
/// (`lib/utils/ocpt_budget_financing.dart`) resolves which one, and the mode alone dispatches the
/// very same `OcptBudgetEntryDeletionConfirmedEvent` the cash journal's own `Delete` already uses,
/// through `OcptConfirmDialog` first: deleting a journal entry is irreversible, exactly the dialog's
/// own case.
///
/// Empty states, both mirroring the mode's own established readings: a group holding no resource of
/// its own draws no card at all — an empty bordered card stating a zero subtotal says nothing a
/// reader needs — and a project holding no resource whatsoever shows [OcptWorkspaceEmptyMode]
/// **where the plan would be, under a KPI row that stays drawn**, `OcptBudgetCashJournal`'s own
/// reading and for its own reason: `+ Resource` lives in that row, and a plan nobody has started is
/// precisely the moment somebody reaches for it.
class OcptBudgetFinancing extends StatelessWidget {
  /// Every live resource, in `sortKey` order.
  final List<OcptBudgetResource> resources;

  /// What has actually come in against each resource, keyed by its own id — read raw, rather than
  /// through [receivedCentsOf], for the one reading that needs to tell "no entry names this
  /// resource at all" from "entries name it and sum to zero" — see the class doc comment.
  final Map<String, OcptBudgetCoveredTotal> receivedByResourceId;

  /// A resource's own received total, in cents, tax-inclusive, honestly zero the moment its own
  /// entries are known to sum to nothing — `OcptBudgetState.receivedCentsOf`. Read by every row but
  /// an in-kind one carrying no entry at all, which reads [receivedByResourceId] instead.
  final int Function(String resourceId) receivedCentsOf;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// The id of the currently selected resource, or null while none is.
  final String? selectedResourceId;

  /// Whether the mode shows a project version being previewed read-only — see the class doc
  /// comment.
  final bool isReadOnly;

  /// Called with the kind picked when the KPI row's own `+ Resource` menu asks to create a fresh
  /// resource, or null while [isReadOnly] — see the class doc comment for why this is a choice of
  /// kind now, rather than one gesture opening one form for all three.
  final ValueChanged<OcptBudgetResourceGroupKind>? onResourceCreationRequested;

  /// Called with a resource's id when its row is clicked — selects it, and only that.
  final ValueChanged<String> onResourceSelected;

  /// Called with a resource when its row's own `⋮` menu asks to edit it, or null while
  /// [isReadOnly]. Opens `OcptBudgetResourceDialog` on it.
  final ValueChanged<OcptBudgetResource>? onResourceEditRequested;

  /// Called with a resource when its row's own `⋮` menu asks to record a receipt against it, or
  /// null while [isReadOnly]. Opens `OcptBudgetEntryDialog` pre-filled from it, as a credit.
  ///
  /// The row itself further withholds the menu entry that calls this — never disables it — once
  /// the resource is fully received or is an in-kind one: see the class doc comment.
  final ValueChanged<OcptBudgetResource>? onResourceReceiptRequested;

  /// Called with a resource when its row's own `⋮` menu asks to undo the most recent receipt
  /// against it, or null while [isReadOnly]. The mode resolves which `budget_entries` credit that
  /// is and answers through `OcptConfirmDialog` before dispatching its deletion — see the class doc
  /// comment.
  ///
  /// The row itself further withholds the menu entry that calls this until the resource has
  /// actually received something.
  final ValueChanged<OcptBudgetResource>? onResourceReceiptUndoRequested;

  /// Called with a resource's id when its row's own `⋮` menu asks to delete it, or null while
  /// [isReadOnly]. The mode answers this through `OcptConfirmDialog` before dispatching anything.
  final ValueChanged<String>? onResourceDeletionRequested;

  /// Class constructor
  const OcptBudgetFinancing({
    super.key,
    required this.resources,
    required this.receivedByResourceId,
    required this.receivedCentsOf,
    required this.currencyCode,
    required this.selectedResourceId,
    required this.isReadOnly,
    required this.onResourceCreationRequested,
    required this.onResourceSelected,
    required this.onResourceEditRequested,
    required this.onResourceReceiptRequested,
    required this.onResourceReceiptUndoRequested,
    required this.onResourceDeletionRequested,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _OcptFinancingKpiRow(
          resources: resources,
          receivedCentsOf: receivedCentsOf,
          currencyCode: currencyCode,
          onResourceCreationRequested: isReadOnly ? null : onResourceCreationRequested,
        ),
        const SizedBox(height: 16),
        Expanded(
          child: resources.isEmpty
              ? OcptWorkspaceEmptyMode(icon: Icons.savings_outlined, message: tr.budgetFinancingEmptyHint)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _OcptFinancingColumnHeaderRow(),
                    const SizedBox(height: 4),
                    Expanded(
                      child: ListView(
                        children: [
                          for (final groupKind in OcptBudgetResourceGroupKind.values)
                            _buildGroupCard(context, groupKind),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  /// The bordered card for [groupKind], or an empty widget while it holds no resource — see the
  /// class doc comment for why a group with nothing in it draws no card at all.
  Widget _buildGroupCard(BuildContext context, OcptBudgetResourceGroupKind groupKind) {
    final groupResources = [for (final resource in resources) if (resource.groupKind == groupKind) resource];
    if (groupResources.isEmpty) {
      return const SizedBox.shrink();
    }

    final tr = Tr.of(context);
    final theme = Theme.of(context);
    final subtotalCents = groupResources.fold(0, (sum, resource) => sum + resource.amountCents);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    ocptBudgetResourceGroupKindLabel(tr, groupKind),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  ocptBudgetAmountLabel(subtotalCents, currencyCode),
                  style: theme.textTheme.titleSmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            for (final resource in groupResources)
              _OcptFinancingResourceRow(
                resource: resource,
                receivedByResourceId: receivedByResourceId,
                receivedCentsOf: receivedCentsOf,
                currencyCode: currencyCode,
                isSelected: resource.id == selectedResourceId,
                onTap: () => onResourceSelected(resource.id),
                onEditRequested: isReadOnly || onResourceEditRequested == null
                    ? null
                    : () => onResourceEditRequested?.call(resource),
                onReceiptRequested: isReadOnly || onResourceReceiptRequested == null
                    ? null
                    : () => onResourceReceiptRequested?.call(resource),
                onReceiptUndoRequested: isReadOnly || onResourceReceiptUndoRequested == null
                    ? null
                    : () => onResourceReceiptUndoRequested?.call(resource),
                onDeletionRequested: isReadOnly || onResourceDeletionRequested == null
                    ? null
                    : () => onResourceDeletionRequested?.call(resource.id),
              ),
          ],
        ),
      ),
    );
  }
}

/// The top KPI row: `Total resources`, `Cash` (subsidy and cash combined, with what has come in and
/// what is still to come underneath), `In-kind contributions` (in the accent colour, with a fixed
/// hint underneath rather than a figure of its own kind), then `+ Resource`.
class _OcptFinancingKpiRow extends StatelessWidget {
  /// See [OcptBudgetFinancing]'s own fields of the same name.
  final List<OcptBudgetResource> resources;
  final int Function(String resourceId) receivedCentsOf;
  final String currencyCode;
  final ValueChanged<OcptBudgetResourceGroupKind>? onResourceCreationRequested;

  /// Class constructor
  const _OcptFinancingKpiRow({
    required this.resources,
    required this.receivedCentsOf,
    required this.currencyCode,
    required this.onResourceCreationRequested,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);
    final totalCents = ocptBudgetResourcesTotalCents(resources);
    final byGroupKind = ocptBudgetResourcesTotalByGroupKind(resources);
    final inKindCents = byGroupKind[OcptBudgetResourceGroupKind.inKind] ?? 0;

    final cashResources = [
      for (final resource in resources)
        if (resource.groupKind != OcptBudgetResourceGroupKind.inKind) resource,
    ];
    final cashAmountCents =
        (byGroupKind[OcptBudgetResourceGroupKind.subsidy] ?? 0) +
        (byGroupKind[OcptBudgetResourceGroupKind.cash] ?? 0);
    final cashReceivedCents = cashResources.fold(
      0,
      (sum, resource) => sum + receivedCentsOf(resource.id),
    );
    final cashOutstandingCents = ocptBudgetResourceOutstandingCents(
      amountCents: cashAmountCents,
      receivedCents: cashReceivedCents,
    );

    // The three figures ride a `Wrap` inside an `Expanded`, exactly as `OcptBudgetDashboard`'s own
    // KPI row does, rather than a plain `Row` whose only give was a `Spacer`. Each figure carries a
    // caption as long as the words it states, so three of them plus the button outgrew any centre
    // pane under roughly 1,120 px — the right dock opening is enough — and a `Row` clips silently
    // in release rather than overflowing loudly. The button stays outside the `Wrap` so it keeps
    // its place at the right whatever the figures do.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Wrap(
            spacing: 32,
            runSpacing: 12,
            children: [
              _OcptFinancingKpi(
                label: tr.budgetFinancingTotalResourcesLabel,
                value: ocptBudgetAmountLabel(totalCents, currencyCode),
              ),
              _OcptFinancingKpi(
                label: tr.budgetFinancingCashLabel,
                value: ocptBudgetAmountLabel(cashAmountCents, currencyCode),
                caption: tr.budgetFinancingCashCaption(
                  ocptBudgetAmountLabel(cashReceivedCents, currencyCode),
                  ocptBudgetAmountLabel(cashOutstandingCents, currencyCode),
                ),
              ),
              _OcptFinancingKpi(
                label: tr.budgetFinancingInKindLabel,
                value: ocptBudgetAmountLabel(inKindCents, currencyCode),
                valueColor: theme.colorScheme.primary,
                caption: tr.budgetFinancingInKindHint,
              ),
            ],
          ),
        ),
        if (onResourceCreationRequested != null) ...[
          const SizedBox(width: 16),
          _OcptAddResourceButton(onGroupKindPicked: onResourceCreationRequested!),
        ],
      ],
    );
  }
}

/// The KPI row's own `+ Resource` control: a `MenuAnchor`/`MenuItemButton` menu offering the three
/// `OcptBudgetResourceGroupKind` values by name, anchored on one `FilledButton` — see
/// [OcptBudgetFinancing]'s own class doc comment for why three explicit gestures rather than one
/// form. Built exactly the way `OcptResourcesMode`'s own `_OcptAddRoleButton`/`_OcptAddElementButton`
/// are (`lib/ui/pages/workspace/modes/resources/widgets/ocpt_resources_list_panel.dart`), so picking
/// an entry closes the menu for free.
class _OcptAddResourceButton extends StatelessWidget {
  /// Called with the kind picked.
  final ValueChanged<OcptBudgetResourceGroupKind> onGroupKindPicked;

  /// Class constructor
  const _OcptAddResourceButton({required this.onGroupKindPicked});

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return MenuAnchor(
      menuChildren: [
        MenuItemButton(
          onPressed: () => onGroupKindPicked(OcptBudgetResourceGroupKind.subsidy),
          child: Text(tr.budgetFinancingAddSubsidyAction),
        ),
        MenuItemButton(
          onPressed: () => onGroupKindPicked(OcptBudgetResourceGroupKind.cash),
          child: Text(tr.budgetFinancingAddCashAction),
        ),
        MenuItemButton(
          onPressed: () => onGroupKindPicked(OcptBudgetResourceGroupKind.inKind),
          child: Text(tr.budgetFinancingAddInKindAction),
        ),
      ],
      builder: (context, controller, child) => FilledButton.icon(
        onPressed: () => controller.isOpen ? controller.close() : controller.open(),
        icon: const Icon(Icons.add, size: 16),
        label: Text(tr.budgetFinancingCreationAction),
      ),
    );
  }
}

/// One KPI of [_OcptFinancingKpiRow]: a muted label, a value (in [valueColor] while given), and an
/// optional muted caption underneath.
class _OcptFinancingKpi extends StatelessWidget {
  /// The KPI's own label.
  final String label;

  /// The KPI's own value.
  final String value;

  /// [value]'s own colour, or null for the ordinary body colour.
  final Color? valueColor;

  /// A muted caption under [value], or null for a KPI with nothing further to say.
  final String? caption;

  /// Class constructor
  const _OcptFinancingKpi({required this.label, required this.value, this.valueColor, this.caption});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final caption = this.caption;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 2),
        Text(value, style: theme.textTheme.titleMedium?.copyWith(color: valueColor)),
        if (caption != null)
          Text(
            caption,
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
      ],
    );
  }
}

/// The column header naming a resource row's own five columns — `Label`, `Status`, `Amount`,
/// `Received`, `Outstanding` — sitting once above every group card, `OcptBudgetCostTracking`'s own
/// header row read over `OcptBudgetFinancing`'s own layout: a plain [Row] rather than that table's
/// two independently scrolling panes, since a resource row is never pinned or scrolled apart from
/// its own figures. Its own widths mirror [_OcptFinancingResourceRow]'s own cells exactly, so a
/// column lines up with its own heading whichever group card sits beneath it — see
/// [OcptBudgetFinancing]'s own class doc comment for why one header rather than one per card.
class _OcptFinancingColumnHeaderRow extends StatelessWidget {
  /// Class constructor
  const _OcptFinancingColumnHeaderRow();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          ocptTableRowHorizontalPadding,
          0,
          ocptTableRowHorizontalPadding,
          6,
        ),
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(tr.budgetFinancingColumnLabel.toUpperCase(), style: labelStyle),
              ),
            ),
            SizedBox(
              width: _ocptFinancingStatusColumnWidth,
              child: Text(tr.budgetFinancingColumnStatus.toUpperCase(), style: labelStyle),
            ),
            SizedBox(
              width: _ocptFinancingAmountColumnWidth,
              child: Text(
                tr.budgetFinancingColumnAmount.toUpperCase(),
                textAlign: TextAlign.right,
                style: labelStyle,
              ),
            ),
            SizedBox(
              width: _ocptFinancingAmountColumnWidth,
              child: Text(
                tr.budgetFinancingColumnReceived.toUpperCase(),
                textAlign: TextAlign.right,
                style: labelStyle,
              ),
            ),
            SizedBox(
              width: _ocptFinancingAmountColumnWidth,
              child: Text(
                tr.budgetFinancingColumnOutstanding.toUpperCase(),
                textAlign: TextAlign.right,
                style: labelStyle,
              ),
            ),
            const SizedBox(width: _ocptFinancingMenuColumnWidth),
          ],
        ),
      ),
    );
  }
}

/// One resource row: the label with its notes underneath, a status pill, the amount, what has been
/// received and what is still to come, then its own `⋮` menu.
class _OcptFinancingResourceRow extends StatelessWidget {
  /// The resource this row draws.
  final OcptBudgetResource resource;

  /// See [OcptBudgetFinancing]'s own fields of the same name.
  final Map<String, OcptBudgetCoveredTotal> receivedByResourceId;
  final int Function(String resourceId) receivedCentsOf;
  final String currencyCode;

  /// Whether this resource is the currently selected one.
  final bool isSelected;

  /// Called when this row is clicked — selects it, and only that.
  final VoidCallback onTap;

  /// Called when this row's own `⋮` menu asks to edit it, or null while withheld.
  final VoidCallback? onEditRequested;

  /// Called when this row's own `⋮` menu asks to record a receipt against it, or null while
  /// withheld under a read-only preview.
  ///
  /// Withheld here too — the menu entry simply isn't drawn — once the resource is fully received
  /// or is an in-kind one: see [OcptBudgetFinancing]'s own class doc comment.
  final VoidCallback? onReceiptRequested;

  /// Called when this row's own `⋮` menu asks to undo the most recent receipt against it, or null
  /// while withheld under a read-only preview.
  ///
  /// Withheld here too — the menu entry simply isn't drawn — until the resource has actually
  /// received something: see [OcptBudgetFinancing]'s own class doc comment.
  final VoidCallback? onReceiptUndoRequested;

  /// Called when this row's own `⋮` menu asks to delete it, or null while withheld.
  final VoidCallback? onDeletionRequested;

  /// Class constructor
  const _OcptFinancingResourceRow({
    required this.resource,
    required this.receivedByResourceId,
    required this.receivedCentsOf,
    required this.currencyCode,
    required this.isSelected,
    required this.onTap,
    required this.onEditRequested,
    required this.onReceiptRequested,
    required this.onReceiptUndoRequested,
    required this.onDeletionRequested,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    // An in-kind resource no entry has ever named reads em-dash on both columns — see
    // `OcptBudgetFinancing`'s own class doc comment for why. Every other row, in-kind included once
    // an entry does name it, reads the ordinary honest-zero figures.
    final isUnentriedInKind =
        resource.groupKind == OcptBudgetResourceGroupKind.inKind &&
        !receivedByResourceId.containsKey(resource.id);

    final receivedCents = isUnentriedInKind ? null : receivedCentsOf(resource.id);
    final outstandingCents = receivedCents == null
        ? null
        : ocptBudgetResourceOutstandingCents(amountCents: resource.amountCents, receivedCents: receivedCents);
    final isOutstandingNegative = outstandingCents != null && outstandingCents < 0;

    // `Record a receipt` has nothing left to offer on an in-kind resource (valued, never
    // collected) or on one that has already received at least its own amount — see
    // `OcptBudgetFinancing`'s own class doc comment for both readings.
    final canOfferReceipt =
        resource.groupKind != OcptBudgetResourceGroupKind.inKind && (receivedCents ?? 0) < resource.amountCents;
    final effectiveOnReceiptRequested = canOfferReceipt ? onReceiptRequested : null;

    // `Undo the last receipt` only makes sense once the resource has actually received something.
    final hasReceivedSomething = receivedCents != null && receivedCents > 0;
    final effectiveOnReceiptUndoRequested = hasReceivedSomething ? onReceiptUndoRequested : null;

    final hasMenu =
        onEditRequested != null ||
        effectiveOnReceiptRequested != null ||
        effectiveOnReceiptUndoRequested != null ||
        onDeletionRequested != null;

    return InkWell(
      onTap: onTap,
      mouseCursor: ocptClickableCursor,
      child: ColoredBox(
        color: isSelected ? theme.colorScheme.primary.withValues(alpha: ocptSelectedStateAlpha) : Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 8,
            horizontal: ocptTableRowHorizontalPadding,
          ),
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        resource.label.isEmpty ? tr.budgetPosteUnnamed : resource.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                      if (resource.notes.isNotEmpty)
                        Text(
                          resource.notes,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: _ocptFinancingStatusColumnWidth,
                child: _OcptFinancingStatusPill(
                  groupKind: resource.groupKind,
                  status: resource.status,
                ),
              ),
              SizedBox(
                width: _ocptFinancingAmountColumnWidth,
                child: Text(
                  ocptBudgetAmountLabel(resource.amountCents, currencyCode),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              SizedBox(
                width: _ocptFinancingAmountColumnWidth,
                child: Text(
                  receivedCents == null ? ocptBudgetEmptyValue : ocptBudgetAmountLabel(receivedCents, currencyCode),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              SizedBox(
                width: _ocptFinancingAmountColumnWidth,
                child: Text(
                  outstandingCents == null
                      ? ocptBudgetEmptyValue
                      : ocptBudgetAmountLabel(outstandingCents, currencyCode),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isOutstandingNegative ? theme.colorScheme.error : null,
                    fontWeight: isOutstandingNegative ? FontWeight.w600 : null,
                  ),
                ),
              ),
              SizedBox(
                width: _ocptFinancingMenuColumnWidth,
                child: !hasMenu
                    ? null
                    : PopupMenuButton<String>(
                        tooltip: "",
                        icon: const Icon(Icons.more_vert, size: 18),
                        onSelected: (value) => switch (value) {
                          "edit" => onEditRequested?.call(),
                          "receipt" => effectiveOnReceiptRequested?.call(),
                          "receiptUndo" => effectiveOnReceiptUndoRequested?.call(),
                          "delete" => onDeletionRequested?.call(),
                          _ => null,
                        },
                        itemBuilder: (context) => [
                          if (onEditRequested != null)
                            PopupMenuItem<String>(
                              value: "edit",
                              child: Text(tr.budgetFinancingEditAction),
                            ),
                          if (effectiveOnReceiptRequested != null)
                            PopupMenuItem<String>(
                              value: "receipt",
                              child: Text(tr.budgetFinancingRecordReceiptAction),
                            ),
                          if (effectiveOnReceiptUndoRequested != null)
                            PopupMenuItem<String>(
                              value: "receiptUndo",
                              child: Text(tr.budgetFinancingUndoReceiptAction),
                            ),
                          if (onDeletionRequested != null)
                            PopupMenuItem<String>(
                              value: "delete",
                              child: Text(tr.budgetCommittedDeleteAction),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One of `OcptBudgetResourceStatus`'s own three badges — mirrors `OcptBudgetCommittedSpending`'s
/// own `_OcptCommittedStatusBadge`, generic over a different enum: a bordered outline while the
/// resource is merely in play, growing into a solid fill once it is held on paper.
///
/// **Takes the row's own [groupKind] as well as its [status]**, because the word a step is called
/// belongs to the group — `Secured` under `Subsidies`, `Signed` under `In kind`, for two rows
/// standing at the very same step. The *colour* is the step's alone, so the eye reads how far along
/// a row is without having to read which group it sits in: `OcptBudgetResourceStatus`'s own doc
/// comment argues both halves.
class _OcptFinancingStatusPill extends StatelessWidget {
  /// The group the resource this pill belongs to sits in — what its [status] is called depends on
  /// it.
  final OcptBudgetResourceGroupKind groupKind;

  /// The status this pill paints.
  final OcptBudgetResourceStatus status;

  /// Class constructor
  const _OcptFinancingStatusPill({required this.groupKind, required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final accent = ocptBudgetResourceStatusAccentColor(theme.colorScheme, status);
    final isSolid = status == OcptBudgetResourceStatus.confirmed;
    final alpha = status.index / (OcptBudgetResourceStatus.values.length - 1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isSolid ? accent : accent.withValues(alpha: alpha),
        border: status == OcptBudgetResourceStatus.pending
            ? Border.all(color: accent.withValues(alpha: 0.6))
            : null,
        borderRadius: BorderRadius.circular(ocptRadiusSmall),
      ),
      child: Text(
        ocptBudgetResourceStatusLabel(tr, groupKind, status),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelSmall?.copyWith(
          color: isSolid ? theme.colorScheme.onPrimary : accent,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
