// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_selection.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_budget_labels.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_totals.dart';

/// This bar's own fixed height, in logical pixels — a compact reading for a list of many cards,
/// half the resources tree's own coverage band (`_ocptResourcesCoverageBarHeight`), which has only
/// one bar to draw on a whole page.
const double _ocptPosteDockBarHeight = 6;

/// The budget mode's left dock: one card per live poste, in the mode's own poste order, over a
/// four-line footer totalling the whole project.
///
/// **Purely presentational.** No bloc, no `globalGetIt()`, no service: every figure it draws is
/// handed in already computed by `OcptBudgetState` and `lib/utils/ocpt_budget_totals.dart`, and
/// every gesture is reported upward through a callback — the mode decides what each one writes.
///
/// **Drawn on every view of the mode, `financing`, `regie` and `sharing` included.** It is the
/// mode's own standing reading of where the quote stands, not a control belonging to one page — the
/// cost-tracking table can be scrolled away, the régie or the sharing view can be on screen
/// entirely, and this dock still answers "how is the quote doing" without asking the reader to
/// switch views to find out.
///
/// **Two gestures on a card, and they mean two different things.** A click on the card itself
/// ([onPosteSelected]) *selects* the poste — it opens the fiche and highlights the card, exactly as
/// a poste row of the cost-tracking tree already does, and it narrows nothing: a reader who wants a
/// closer look at one poste must not find every other view of the mode silently narrowed to it,
/// which is precisely the conflation `docs/architecture/budget.md`'s "Selecting a poste and
/// filtering by one are two different facts" already retired for the cost-tracking table's own row.
/// The card's own `⋮` menu carries the one gesture that *does* narrow — [onPosteFilterRequested] —
/// reached deliberately, through a menu rather than the card's own click target, so filtering stays
/// a decision a reader makes on purpose. Both only ever read the project, so neither is withheld
/// under a read-only version preview.
///
/// [onPosteFilterRequested] and [onFilterClearRequested] are **withheld together**, both null on the
/// three views with no poste dimension at all (`financing`, `regie`, `sharing` —
/// `ocptBudgetViewHonoursPosteFilter`): a card's own `⋮` menu carries no filter entry there, and the
/// footer's own `Tout` link draws nowhere either, even while [filterPosteId] still names a poste —
/// the filter is still set, and leaving brings it back, exactly as the header's own chip already
/// reads it on those views.
class OcptBudgetPosteDock extends StatelessWidget {
  /// Every live poste, in the mode's own display order — unfiltered: this dock is a standing
  /// reading of the whole quote, not a narrowed view.
  final List<OcptBudgetPoste> postes;

  /// What is currently selected for the right dock's own fiche, or null while none is.
  final OcptBudgetSelection? selection;

  /// Whether the header's simplified/detailed switch currently reads simplified.
  final bool isSimplified;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// A poste's own paid total, in cents — `OcptBudgetState.paidCentsOf`.
  final int Function(String posteId) paidCentsOf;

  /// A poste's own committed total, in cents — `OcptBudgetState.committedCentsOf`.
  final int Function(String posteId) committedCentsOf;

  /// The poste every view of the mode is currently narrowed to, or null for the whole project —
  /// `OcptBudgetState.filterPosteId`, read here only to decide whether the footer's own `Tout` link
  /// draws; the header's own chip stays the single source of truth for the filter itself.
  final String? filterPosteId;

  /// Called with a poste's id when its card is clicked — a selection, never a filter. Never
  /// withheld: see the class doc comment.
  final ValueChanged<String> onPosteSelected;

  /// Called with a poste's id when its card's own `⋮` menu asks to narrow every view to it, or null
  /// on the three views with no poste dimension — see the class doc comment.
  final ValueChanged<String>? onPosteFilterRequested;

  /// Called when the footer's own `Tout` link is clicked, or null on the three views with no poste
  /// dimension, mirroring [onPosteFilterRequested]'s own nullness.
  final VoidCallback? onFilterClearRequested;

  /// Class constructor
  const OcptBudgetPosteDock({
    super.key,
    required this.postes,
    required this.selection,
    required this.isSimplified,
    required this.currencyCode,
    required this.paidCentsOf,
    required this.committedCentsOf,
    required this.filterPosteId,
    required this.onPosteSelected,
    required this.onPosteFilterRequested,
    required this.onFilterClearRequested,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final showClearFilterLink = filterPosteId != null && onFilterClearRequested != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(tr.budgetPosteDockTitle, style: theme.textTheme.titleSmall),
              ),
              if (showClearFilterLink)
                InkWell(
                  onTap: onFilterClearRequested,
                  mouseCursor: ocptClickableCursor,
                  borderRadius: BorderRadius.circular(ocptRadiusSmall),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Text(
                      tr.budgetPosteDockClearFilterLabel,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: postes.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    tr.budgetPosteDockEmptyHint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final poste in postes)
                        _OcptBudgetPosteDockCard(
                          poste: poste,
                          isSelected: _isPosteSelected(poste.id),
                          isSimplified: isSimplified,
                          currencyCode: currencyCode,
                          paidCents: paidCentsOf(poste.id),
                          committedCents: committedCentsOf(poste.id),
                          onTap: () => onPosteSelected(poste.id),
                          onFilterRequested: onPosteFilterRequested == null
                              ? null
                              : () => onPosteFilterRequested!(poste.id),
                        ),
                    ],
                  ),
                ),
        ),
        _OcptBudgetPosteDockFooter(postes: postes, currencyCode: currencyCode, paidCentsOf: paidCentsOf, committedCentsOf: committedCentsOf),
      ],
    );
  }

  /// Whether poste [posteId] is the currently selected one.
  bool _isPosteSelected(String posteId) {
    final selection = this.selection;
    return selection is OcptBudgetPosteSelection && selection.posteId == posteId;
  }
}

/// One poste's own card: its code (detailed reading only), its name, a two-tone bar reading paid
/// then committed against its own quoted total, the `total / devis` read-out, the consumed
/// percentage in its own strain colour, and a `⋮` menu carrying the one gesture that filters.
class _OcptBudgetPosteDockCard extends StatelessWidget {
  /// The poste this card shows.
  final OcptBudgetPoste poste;

  /// Whether this poste is the currently selected one.
  final bool isSelected;

  /// Whether the header's simplified/detailed switch currently reads simplified.
  final bool isSimplified;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// This poste's own paid total, in cents.
  final int paidCents;

  /// This poste's own committed total, in cents.
  final int committedCents;

  /// Called when this card is clicked.
  final VoidCallback onTap;

  /// Called when this card's own `⋮` menu asks to narrow every view to this poste, or null while
  /// withheld — no menu is drawn at all then.
  final VoidCallback? onFilterRequested;

  /// Class constructor
  const _OcptBudgetPosteDockCard({
    required this.poste,
    required this.isSelected,
    required this.isSimplified,
    required this.currencyCode,
    required this.paidCents,
    required this.committedCents,
    required this.onTap,
    required this.onFilterRequested,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final name = ocptBudgetPosteDisplayLabel(poste, isSimplified: isSimplified);
    final quotedCents = ocptBudgetPosteQuotedTotalCents(poste);
    final consumedCents = paidCents + committedCents;
    final strain = ocptBudgetPosteStrainOf(
      quotedAmountCents: quotedCents,
      paidCents: paidCents,
      committedCents: committedCents,
    );
    final strainColor = ocptBudgetPosteStrainColor(context, strain);
    final consumedRatio = ocptBudgetConsumedRatioOf(
      quotedAmountCents: quotedCents,
      paidCents: paidCents,
      committedCents: committedCents,
    );
    final paidFraction = _fractionOf(paidCents, quotedCents);
    final consumedFraction = _fractionOf(consumedCents, quotedCents);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 3, 12, 3),
      child: InkWell(
        onTap: onTap,
        mouseCursor: ocptClickableCursor,
        borderRadius: BorderRadius.circular(ocptRadiusMedium),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
            ),
            color: isSelected
                ? theme.colorScheme.primary.withValues(alpha: ocptSelectedStateAlpha)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(ocptRadiusMedium),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (!isSimplified) ...[
                    Text(
                      poste.code,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      name.isEmpty ? tr.budgetPosteUnnamed : name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontStyle: name.isEmpty ? FontStyle.italic : FontStyle.normal,
                      ),
                    ),
                  ),
                  if (onFilterRequested != null)
                    PopupMenuButton<void>(
                      tooltip: "",
                      icon: const Icon(Icons.more_vert, size: 16),
                      padding: EdgeInsets.zero,
                      itemBuilder: (context) => [
                        PopupMenuItem<void>(
                          onTap: onFilterRequested,
                          child: Text(tr.budgetPosteDockFilterOnlyAction),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(_ocptPosteDockBarHeight / 2),
                child: Stack(
                  children: [
                    SizedBox(
                      height: _ocptPosteDockBarHeight,
                      width: double.infinity,
                      child: ColoredBox(color: theme.colorScheme.surfaceContainerHigh),
                    ),
                    FractionallySizedBox(
                      widthFactor: consumedFraction,
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        height: _ocptPosteDockBarHeight,
                        child: ColoredBox(color: strainColor.withValues(alpha: 0.35)),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: paidFraction,
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        height: _ocptPosteDockBarHeight,
                        child: ColoredBox(color: strainColor),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      "${ocptBudgetAmountLabel(consumedCents, currencyCode)} / "
                      "${ocptBudgetAmountLabel(quotedCents, currencyCode)}",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Text(
                    consumedRatio == null ? ocptBudgetEmptyValue : "${(consumedRatio * 100).round()}%",
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: strainColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// [numeratorCents] as a fraction of [denominatorCents], clamped to `[0, 1]` — a poste with no
  /// quote at all ([denominatorCents] zero) reads `1.0` the moment anything has moved against it,
  /// `0.0` otherwise, mirroring `_OcptResourcesCoverageBand`'s own reading of the very same shape.
  double _fractionOf(int numeratorCents, int denominatorCents) => denominatorCents <= 0
      ? (numeratorCents > 0 ? 1.0 : 0.0)
      : (numeratorCents / denominatorCents).clamp(0.0, 1.0);
}

/// The dock's own footer: `Devis`, `Payé`, `Engagé` and `Reste` for the whole project — the very
/// same four words the cost-tracking table's own columns already use, reused here rather than
/// resolved a second time.
///
/// **Scoped to the postes it is handed, exactly as [OcptBudgetPosteDock] is** — off-quote spending
/// prices no poste at all (`docs/architecture/budget.md`'s "Off-quote spending is named, never
/// hidden"), so it is no more this footer's business than it is `ocptBudgetPosteStrainOf`'s.
class _OcptBudgetPosteDockFooter extends StatelessWidget {
  /// Every live poste the footer totals over.
  final List<OcptBudgetPoste> postes;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// A poste's own paid total, in cents.
  final int Function(String posteId) paidCentsOf;

  /// A poste's own committed total, in cents.
  final int Function(String posteId) committedCentsOf;

  /// Class constructor
  const _OcptBudgetPosteDockFooter({
    required this.postes,
    required this.currencyCode,
    required this.paidCentsOf,
    required this.committedCentsOf,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    final quotedCents = ocptBudgetProjectQuotedTotalCents(postes);
    var paidCents = 0;
    var committedCents = 0;
    for (final poste in postes) {
      paidCents += paidCentsOf(poste.id);
      committedCents += committedCentsOf(poste.id);
    }
    final remainingCents = ocptBudgetRemainingCents(
      quotedAmountCents: quotedCents,
      paidCents: paidCents,
      committedCents: committedCents,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildRow(theme, tr.budgetCostTrackingColumnQuote, quotedCents),
            _buildRow(theme, tr.budgetCostTrackingColumnPaid, paidCents),
            _buildRow(theme, tr.budgetCostTrackingColumnCommitted, committedCents),
            _buildRow(theme, tr.budgetCostTrackingColumnRemaining, remainingCents),
          ],
        ),
      ),
    );
  }

  /// One footer line: a muted label on the left, the figure on the right.
  Widget _buildRow(ThemeData theme, String label, int cents) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        Text(ocptBudgetAmountLabel(cents, currencyCode), style: theme.textTheme.labelMedium),
      ],
    ),
  );
}
