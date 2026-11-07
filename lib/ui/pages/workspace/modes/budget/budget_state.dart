// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_project_info_table.dart';
import 'package:open_cine_prod_tools/models/ocpt_asset_ref.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_account.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_allowance.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_mileage_rate.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_resource.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_revenue.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_selection.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_share.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_element.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_package_notice.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_package_report.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_package_target.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_working_copy_state.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_alerts.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_cash_totals.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_covered_total.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_element_link.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_logistics_day.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_logistics_totals.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_repayment_line.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_share_split.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_sharing_pot.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_selection_cause.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_tax_basis.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_tools_view.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_view.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_version_notice_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_mode_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_project_package_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_project_versions_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';

export 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_state_copies.dart';

/// The state of `OcptBudgetBloc`.
///
/// [view], [toolsView], [isSimplified] and [taxBasis] are **not persisted**: the schedule mode's
/// own agenda mode is the precedent, only [rightDockFraction] and [lastRightDockTab] surviving a
/// relaunch. The free-text fields typed and not yet written belong to `OcptBudgetExpensesBloc`.
class OcptBudgetState extends BlocStateForMixin<OcptBudgetState>
    with
        MixinOcptProjectVersionsState<OcptBudgetState>,
        MixinOcptProjectPackageState<OcptBudgetState>,
        MixinOcptModeState<OcptBudgetState> {
  /// Whether the quote read is still being loaded from the project database.
  final bool isLoading;

  /// The title shown in the toolbar: the name of the project currently open.
  final String title;

  /// The whole quote read, as last loaded from the project database (the ten CNC accounts seeded on
  /// first read), or null while nothing has been read yet.
  final OcptBudgetSnapshot? snapshot;

  /// The project's currency, an ISO 4217 code, as last loaded — [ocptDefaultCurrencyCode] before
  /// the first read lands, mirroring `OcptResourcesState.currencyCode`.
  final String currencyCode;

  /// Which of the mode's views is currently shown.
  final OcptBudgetView view;

  /// Which of the tools drawer's own three pages is currently shown, while [view] is
  /// [OcptBudgetView.tools] — read even while it is not, so switching away from the drawer and
  /// back leaves it on the page it was last on. Defaults to
  /// [OcptBudgetToolsView.cashFlow] and is held in memory alone, mirroring [view] itself.
  /// Selecting [view] never clears this field, and selecting this field never clears [view]: the
  /// two are independent facts about what is on screen.
  final OcptBudgetToolsView toolsView;

  /// Whether the header's simplified/detailed switch currently reads simplified.
  final bool isSimplified;

  /// Which basis the header's excluding/including-tax toggle currently reads every amount in.
  final OcptBudgetTaxBasis taxBasis;

  /// What is currently selected for the right dock's own detail panel, once it exists — replaces
  /// the separate `selectedAccountId`/`selectedResourceId` id fields this state used to carry: see
  /// `OcptBudgetSelection`'s own doc comment for why one field now answers both.
  /// [selectedAccountId] and [selectedResourceId] below are the narrow getters every dock panel
  /// already reads, resolved off this one field so neither has to learn about the sealed type.
  final OcptBudgetSelection? selection;

  /// The account every view of the mode is currently narrowed to, or null for the whole project.
  ///
  /// **Mode-wide on purpose**, unlike [selectedAccountId]: it is set once, from the header, and
  /// holds across every view — which is what makes it worth having, since following one account
  /// through the quote, what is owed on it and what has moved against it is the reading it exists
  /// for. The three views with no account dimension at all (the financing plan, the logistics, the
  /// revenue sharing) say so rather than pretending to honour it.
  final String? filterAccountId;

  /// The id of the currently selected revenue sharing share, or null while none is — the sharing
  /// view's own right-column selection, mirroring [selectedRevenueId].
  final String? selectedShareId;

  /// Which nodes of the expenses tree, of the resources tree or of the logistics's own defrayal
  /// tree are currently expanded, keyed by their own id — an account id, a quote line id, a
  /// resource id, a revenue id or a person id, whichever twisty was last clicked open, or an
  /// `OcptBudgetResourceFamily`'s own `name` for a family row, which mints no id of its own. The
  /// expenses tree also keys one reserved node naming no record at all —
  /// `OcptBudgetCostTracking`'s own off-quote total, which sums a reading over the journal rather
  /// than an account or a line, and so mints no id either. A commitment sub-row, an entry sub-row,
  /// a receipt sub-row, a defrayal sub-row and a reimbursement sub-row carry no twisty of their own
  /// and so never appear here: each is revealed or hidden wholesale with whichever line, account,
  /// resource, revenue, family or person it sits directly under — a defrayal naming nobody mints no
  /// id here either, drawing as its own group of one with no twisty
  /// (`OcptBudgetLogistics`'s own doc comment). Not persisted across a relaunch, mirroring [view],
  /// [isSimplified] and [taxBasis] above.
  final Set<String> expandedNodeIds;

  /// The right dock's currently active tab, or null if the dock is closed.
  final OcptBudgetRightDockTab? rightDockTab;

  /// The tab the toolbar's right-dock toggle reopens a closed dock on: the last one explicitly
  /// selected, mirroring `OcptScheduleState.lastRightDockTab`.
  final OcptBudgetRightDockTab lastRightDockTab;

  /// The right dock's width, as a fraction of the mode's content row width. Persisted through
  /// `OcptPropertiesManager.budgetRightDockFraction`.
  final double rightDockFraction;

  /// Every live role of the project, as last loaded — read by `OcptBudgetLogistics` alone, to
  /// resolve a traveller's own convocation (a role's own [OcptRole.name] for a cast row, its
  /// [OcptRole.personId] to join a role back to the human playing it) and to tell cast from extras.
  /// Not part of [snapshot]: unlike the catering pass's own [OcptBudgetSnapshot.logisticsDays],
  /// this is the raw read the view resolves a display string
  /// from, exactly as `OcptScheduleState` carries its own roles beside its snapshot rather than
  /// inside it.
  final List<OcptRole> roles;

  /// Every live person of the project's address book, as last loaded — read by
  /// `OcptBudgetLogistics` alone, for the same reason [roles] is: a traveller's own display name
  /// and declared crew position.
  final List<OcptPerson> people;

  /// Every live element of the breakdown's own catalogue, as last loaded — [elementLinkCounts] is
  /// the feed card's own aggregate reading of it, and [unpricedElements] is what
  /// `OcptBudgetDetail`'s own `+ From breakdown` picker offers. Not part of [snapshot]: the
  /// picker needs the whole catalogue, not a figure derived from it, exactly the reason [roles] and
  /// [people] already sit beside it rather than inside it.
  final List<OcptElement> elements;

  /// Every live mileage rate of the project, as last loaded — read by
  /// `OcptBudgetAllowanceDialog` alone, for its `Use this person's own rate` pre-fill. Not part of
  /// [snapshot]: the dialog needs the catalogue itself, not a figure derived from it, exactly the
  /// reason [roles] and [people] already sit beside it rather than inside it.
  final List<OcptBudgetMileageRate> mileageRates;

  /// The account the logistics view's own provisioning would write into, or null while this
  /// project's quote holds no account at all.
  ///
  /// Defaults to the CNC nomenclature's own `Transports, défraiements, régie` account when the
  /// project still has it, and to the first account otherwise — a production is free to have
  /// renamed, split or deleted it, so this is a *preference among the accounts that exist*, never
  /// an assumption that one of them does.
  final String? provisionAccountId;

  /// The set name `OcptBudgetLogistics` prints under each shooting day, keyed by the day's own id
  /// — the first location or set the day's own slots name, resolved once at load time out of the
  /// project's own locations catalogue (`OcptLocationsService.loadLocations`, read for this alone).
  /// A day with no key here names neither in any of its slots, which the view reads as nothing
  /// rather than a placeholder.
  final Map<String, String> logisticsSetNameByDayId;

  /// {@macro open_cine_prod_tools.MixinOcptModeState.reloadEpoch}
  @override
  final int reloadEpoch;

  /// {@macro open_cine_prod_tools.MixinOcptModeState.selectionEpoch}
  @override
  final int selectionEpoch;

  /// What moved the selection the last time [selectionEpoch] advanced.
  final OcptBudgetSelectionCause selectionCause;

  /// {@macro open_cine_prod_tools.MixinOcptProjectVersionsState.projectVersions}
  @override
  final List<OcptProjectVersion> projectVersions;

  /// {@macro open_cine_prod_tools.MixinOcptProjectVersionsState.previewedVersionId}
  @override
  final String? previewedVersionId;

  /// {@macro open_cine_prod_tools.MixinOcptProjectVersionsState.workingCopy}
  @override
  final OcptProjectWorkingCopyState? workingCopy;

  /// {@macro open_cine_prod_tools.MixinOcptProjectVersionsState.versionPendingDeletionId}
  @override
  final String? versionPendingDeletionId;

  /// {@macro open_cine_prod_tools.MixinOcptProjectVersionsState.versionPendingRestoreId}
  @override
  final String? versionPendingRestoreId;

  /// {@macro open_cine_prod_tools.MixinOcptProjectVersionsState.versionPendingRenameId}
  @override
  final String? versionPendingRenameId;

  /// {@macro open_cine_prod_tools.MixinOcptProjectVersionsState.projectVersionNotice}
  @override
  final OcptProjectVersionNoticeKind? projectVersionNotice;

  /// {@macro open_cine_prod_tools.MixinOcptProjectPackageState.projectPackagePendingExport}
  @override
  final OcptProjectPackagePreflight? projectPackagePendingExport;

  /// {@macro open_cine_prod_tools.MixinOcptProjectPackageState.projectPackageNotice}
  @override
  final OcptProjectPackageNotice? projectPackageNotice;

  /// {@macro open_cine_prod_tools.MixinOcptProjectPackageState.projectPackagePendingExportTarget}
  @override
  final OcptProjectPackageTarget? projectPackagePendingExportTarget;

  /// The page setup the mode's own three PDF exports are pre-filled with: the open project's own
  /// page format, paired with the app-wide margins preference — loaded exactly as
  /// `OcptResourcesState.pageSetup` is, this mode carrying no screenplay of its own to typeset.
  final OcptPageSetup pageSetup;

  /// Get the id of the currently selected account, or null while [selection] does not name one.
  ///
  /// **A selection, and nothing else.** It drives the right dock's inspector and the row's own
  /// highlight; it narrows no view. It used to be the cash journal's filter too, one field doing
  /// two jobs, and that conflation was the fault: clicking a row in the quote silently filtered a
  /// view the reader was not even looking at, and they found out on arriving there. What narrows a
  /// view is [filterAccountId], which is only ever set by a gesture that says so.
  String? get selectedAccountId => switch (selection) {
    OcptBudgetAccountSelection(:final accountId) => accountId,
    _ => null,
  };

  /// Get the id of the currently selected financing resource, or null while [selection] does not
  /// name
  /// one — the financing view's own selection, read exactly as [selectedAccountId] is, but drawn as
  /// a plain highlight rather than opening a dock tab: see `OcptBudgetFinancing`'s own class doc
  /// comment for why this view carries no inspector of its own.
  String? get selectedResourceId => switch (selection) {
    OcptBudgetResourceSelection(:final resourceId) => resourceId,
    _ => null,
  };

  /// Get the id of the currently selected taking, or null while [selection] does not name one — the
  /// resources tree's own revenue row reads and dispatches this, opening the detail panel on it
  /// exactly as [selectedResourceId] does for a resource row.
  String? get selectedRevenueId => switch (selection) {
    OcptBudgetRevenueSelection(:final revenueId) => revenueId,
    _ => null,
  };

  /// Get every live account of [snapshot], in display order (empty while nothing is loaded).
  List<OcptBudgetAccount> get accounts => snapshot?.accounts ?? const [];

  /// Get the number of live accounts — the status bar's own first counter.
  int get accountCount => snapshot?.accountCount ?? 0;

  /// Get the total number of quote lines across every account — the status bar's own second
  /// counter.
  int get lineCount => snapshot?.lineCount ?? 0;

  /// Get every live journal entry of [snapshot], in chronological order (empty while nothing is
  /// loaded).
  List<OcptBudgetEntry> get entries => snapshot?.entries ?? const [];

  /// Get every live commitment of [snapshot], in due-date order (empty while nothing is loaded).
  List<OcptBudgetCommitment> get commitments => snapshot?.commitments ?? const [];

  /// Get every live financing resource of [snapshot], in `sortKey` order (empty while nothing is
  /// loaded).
  List<OcptBudgetResource> get resources => snapshot?.resources ?? const [];

  /// Get the number of live financing resources — mirrors [accountCount].
  int get resourceCount => snapshot?.resourceCount ?? 0;

  /// Get what has actually come in against each financing resource of [snapshot], keyed by its own
  /// id
  /// — empty while nothing is loaded. `OcptBudgetFinancing` reads this map itself, raw, for the one
  /// reading `receivedCentsOf` cannot answer — see [OcptBudgetSnapshot.receivedCentsOf]'s own doc
  /// comment.
  Map<String, OcptBudgetCoveredTotal> get receivedByResourceId =>
      snapshot?.receivedByResourceId ?? const {};

  /// Get the cash journal's own debit, credit and balance — a zero-everything total while nothing
  /// is
  /// loaded, mirroring [accounts]' own empty default.
  OcptBudgetCashTotals get cashTotals =>
      snapshot?.cashTotals ??
      const OcptBudgetCashTotals(
        debitCents: 0,
        creditCents: 0,
        coveredEntryCount: 0,
        entryCount: 0,
      );

  /// Get every live taking of [snapshot], in `sortKey` order (empty while nothing is loaded).
  List<OcptBudgetRevenue> get revenues => snapshot?.revenues ?? const [];

  /// Get the number of live takings — mirrors [resourceCount].
  int get revenueCount => snapshot?.revenueCount ?? 0;

  /// Get every live share of [snapshot], in `sortKey` order (empty while nothing is loaded).
  List<OcptBudgetShare> get shares => snapshot?.shares ?? const [];

  /// Get the number of live shares — mirrors [resourceCount].
  int get shareCount => snapshot?.shareCount ?? 0;

  /// Get what has actually come in against each taking of [snapshot], keyed by its own id — empty
  /// while nothing is loaded. `OcptBudgetSharing` reads this map itself, raw, for the one reading
  /// [receivedRevenueCentsOf] cannot answer — mirrors [receivedByResourceId].
  Map<String, OcptBudgetCoveredTotal> get receivedByRevenueId =>
      snapshot?.receivedByRevenueId ?? const {};

  /// Get what has actually been paid against each share of [snapshot], keyed by its own id —
  /// mirrors
  /// [receivedByRevenueId].
  Map<String, OcptBudgetCoveredTotal> get paidByShareId => snapshot?.paidByShareId ?? const {};

  /// Get what there is to share, and what stands between the takings and it — a zero-everything pot
  /// while nothing is loaded, mirroring [cashTotals]' own empty default.
  OcptBudgetSharingPot get sharingPot =>
      snapshot?.sharingPot ??
      const OcptBudgetSharingPot(
        received: OcptBudgetCoveredTotal(amountCents: 0, coveredLineCount: 0, lineCount: 0),
        reimbursableCents: 0,
        repaid: OcptBudgetCoveredTotal(amountCents: 0, coveredLineCount: 0, lineCount: 0),
      );

  /// Get the split of [sharingPot] across [shares], empty while nothing is loaded.
  List<OcptBudgetShareSplit> get shareSplits => snapshot?.shareSplits ?? const [];

  /// Get [resources]' own reimbursable ones, grouped by lender — empty while nothing is loaded. The
  /// `Repaying the contributions` card's own detail: who is owed what.
  List<OcptBudgetRepaymentLine> get repaymentLines => snapshot?.repaymentLines ?? const [];

  /// Get what has actually been paid against each account of [snapshot], empty while nothing is
  /// loaded —
  /// the cost-tracking table reads this, per account and folded into its own total row's `Payé`
  /// cell, rather than recomputing it.
  Map<String, OcptBudgetCoveredTotal> get paidByAccountId => snapshot?.paidByAccountId ?? const {};

  /// Get the total of every debit that names no account at all — spending outside the quote,
  /// `OcptBudgetSnapshot.offQuotePaidTotal`'s own doc comment. Zero and complete while nothing is
  /// loaded, mirroring [cashTotals]' own empty default. The cost-tracking table's own total row
  /// folds this in alongside [paidByAccountId].
  OcptBudgetCoveredTotal get offQuotePaidTotal =>
      snapshot?.offQuotePaidTotal ??
      const OcptBudgetCoveredTotal(amountCents: 0, coveredLineCount: 0, lineCount: 0);

  /// Get what is committed against each account of [snapshot], empty while nothing is loaded — the
  /// cost-tracking table reads this per account (`committedCentsOf`) rather than recomputing it.
  Map<String, OcptBudgetCoveredTotal> get committedByAccountId =>
      snapshot?.committedByAccountId ?? const {};

  /// Get the header's own two alerts, empty while nothing is loaded or the project raises neither.
  List<OcptBudgetAlert> get alerts => snapshot?.alerts ?? const [];

  /// Count how many of [elements] a live quote line already prices, and how many are not — the feed
  /// card's own breakdown row, derived here rather than in that widget, exactly as
  /// [paidByAccountId] is derived here rather than in the cost-tracking table.
  OcptBudgetElementLinkCounts get elementLinkCounts =>
      ocptBudgetElementLinkCountsOf(accounts: accounts, elements: elements);

  /// Get every one of [elements] no live quote line prices yet — what
  /// `OcptBudgetDetail`'s own `+ From breakdown` picker offers.
  List<OcptElement> get unpricedElements =>
      ocptBudgetUnpricedElementsOf(accounts: accounts, elements: elements);

  /// Get every live shooting day's own catering reading, empty while nothing is loaded or the
  /// project
  /// holds no shooting day — `OcptBudgetLogistics`'s own left column.
  List<OcptBudgetLogisticsDay> get logisticsDays => snapshot?.logisticsDays ?? const [];

  /// Get [logisticsDays] folded into one total — a zero-everything, fully-covered total while
  /// nothing is
  /// loaded, mirroring [cashTotals]' own empty default.
  OcptBudgetLogisticsTotals get logisticsTotals =>
      snapshot?.logisticsTotals ??
      const OcptBudgetLogisticsTotals(
        headCount: 0,
        mealCount: 0,
        buffetCount: 0,
        cost: OcptBudgetCoveredTotal(amountCents: 0, coveredLineCount: 0, lineCount: 0),
      );

  /// Get every live defrayal, empty while nothing is loaded or the production has defrayed nobody —
  /// `OcptBudgetLogistics`'s own right column.
  List<OcptBudgetAllowance> get allowances => snapshot?.allowances ?? const [];

  /// Get what has actually been reimbursed against each defrayed person of [snapshot], keyed by
  /// their
  /// own id — empty while nothing is loaded. `OcptBudgetLogistics`'s own person tree reads this map
  /// itself, raw, mirroring [receivedByResourceId]'s own reading.
  Map<String, OcptBudgetCoveredTotal> get reimbursedByPersonId =>
      snapshot?.reimbursedByPersonId ?? const {};

  /// Get every live voucher, keyed by the `budget_entries` row it evidences — empty while nothing
  /// is
  /// loaded or no entry carries one.
  Map<String, OcptAssetRef> get receiptsByEntryId => snapshot?.receiptsByEntryId ?? const {};

  /// Get the project's default VAT rate, in basis points, or null while nobody has recorded one.
  int? get defaultVatRateBasisPoints => snapshot?.defaultVatRateBasisPoints;

  /// Get the project's own meal price, in cents, or null while nobody has recorded one —
  /// `OcptBudgetLogistics`'s own caption.
  int? get mealPriceCents => snapshot?.mealPriceCents;

  /// Get the project's own buffet price, in cents, or null while nobody has recorded one — mirrors
  /// [mealPriceCents].
  int? get buffetPriceCents => snapshot?.buffetPriceCents;

  /// Get the selected account, or null while none is selected (or the selected one disappeared from
  /// a freshly loaded [snapshot]).
  OcptBudgetAccount? get selectedAccount {
    final selectedAccountId = this.selectedAccountId;
    if (selectedAccountId == null) {
      return null;
    }

    for (final account in accounts) {
      if (account.id == selectedAccountId) {
        return account;
      }
    }

    return null;
  }

  /// Class constructor
  const OcptBudgetState({
    required this.isLoading,
    required this.title,
    required this.snapshot,
    required this.currencyCode,
    required this.view,
    required this.toolsView,
    required this.isSimplified,
    required this.taxBasis,
    required this.selection,
    required this.filterAccountId,
    required this.selectedShareId,
    required this.expandedNodeIds,
    required this.rightDockTab,
    required this.lastRightDockTab,
    required this.rightDockFraction,
    required this.roles,
    required this.people,
    required this.elements,
    required this.mileageRates,
    required this.provisionAccountId,
    required this.logisticsSetNameByDayId,
    required this.reloadEpoch,
    required this.selectionEpoch,
    required this.selectionCause,
    required this.projectVersions,
    required this.previewedVersionId,
    required this.workingCopy,
    required this.versionPendingDeletionId,
    required this.versionPendingRestoreId,
    required this.versionPendingRenameId,
    required this.projectVersionNotice,
    required this.projectPackagePendingExport,
    required this.projectPackageNotice,
    required this.projectPackagePendingExportTarget,
    required this.pageSetup,
  });

  /// Init class constructor
  const OcptBudgetState.init()
    : isLoading = true,
      title = "",
      snapshot = null,
      currencyCode = ocptDefaultCurrencyCode,
      // The mode opens on the dashboard, the whole project's standing reading.
      view = OcptBudgetView.dashboard,
      toolsView = OcptBudgetToolsView.cashFlow,
      isSimplified = false,
      taxBasis = OcptBudgetTaxBasis.includingTax,
      selection = null,
      filterAccountId = null,
      selectedShareId = null,
      expandedNodeIds = const {},
      rightDockTab = null,
      lastRightDockTab = OcptBudgetRightDockTab.inspector,
      rightDockFraction = OcptWorkspaceDock.rightDefaultFraction,
      roles = const [],
      people = const [],
      elements = const [],
      mileageRates = const [],
      provisionAccountId = null,
      logisticsSetNameByDayId = const {},
      reloadEpoch = 0,
      selectionEpoch = 0,
      selectionCause = OcptBudgetSelectionCause.none,
      projectVersions = const [],
      previewedVersionId = null,
      workingCopy = null,
      versionPendingDeletionId = null,
      versionPendingRestoreId = null,
      versionPendingRenameId = null,
      projectVersionNotice = null,
      projectPackagePendingExport = null,
      projectPackageNotice = null,
      projectPackagePendingExportTarget = null,
      pageSetup = const OcptPageSetup.standard();

  /// Get `accountId`'s own paid total, in cents, tax-inclusive — 0 while [snapshot] is null or
  /// carries no
  /// entry against it. See `OcptBudgetSnapshot.paidCentsOf`'s own doc comment for why this is now
  /// honestly zero rather than a stand-in for an unknown figure.
  int paidCentsOf(String accountId) => snapshot?.paidCentsOf(accountId) ?? 0;

  /// Get `accountId`'s own committed total, in cents, tax-inclusive — 0 while [snapshot] is null or
  /// carries no commitment against it. See [paidCentsOf]'s own doc comment for the same reading.
  int committedCentsOf(String accountId) => snapshot?.committedCentsOf(accountId) ?? 0;

  /// Get `accountId`'s own in-kind covered total, in cents — 0 while [snapshot] is null or carries
  /// no counterpart line against it. See [paidCentsOf]'s own doc comment for the same reading.
  int inKindCoveredCentsOf(String accountId) => snapshot?.inKindCoveredCentsOf(accountId) ?? 0;

  /// Get `resourceId`'s own received total, in cents, tax-inclusive — 0 while [snapshot] is null or
  /// carries no entry against it. See [OcptBudgetSnapshot.receivedCentsOf]'s own doc comment for
  /// why this `?? 0` is the ordinary reading, and why the financing view reads
  /// [receivedByResourceId] itself for the one row kind that needs the other one.
  int receivedCentsOf(String resourceId) => snapshot?.receivedCentsOf(resourceId) ?? 0;

  /// Get `revenueId`'s own received total, in cents, tax-inclusive — 0 while [snapshot] is null or
  /// carries no entry against it. Mirrors [receivedCentsOf].
  int receivedRevenueCentsOf(String revenueId) => snapshot?.receivedRevenueCentsOf(revenueId) ?? 0;

  /// Get `shareId`'s own paid total, in cents, tax-inclusive — 0 while [snapshot] is null or
  /// carries no
  /// entry against it. Mirrors [receivedCentsOf].
  int paidShareCentsOf(String shareId) => snapshot?.paidShareCentsOf(shareId) ?? 0;

  /// {@macro act_flutter_utility.BlocStateForMixin.copyWith}
  ///
  /// [snapshot] is only replaced when a new one is given, exactly as `OcptScheduleState.snapshot`.
  /// [selection], [filterAccountId] and [rightDockTab] all legitimately go back to null while the
  /// mode is alive, so each has its own force flag.
  ///
  /// **[reloadEpoch] moves by itself** whenever a copy replaces [snapshot], so no handler can read
  /// the data again and forget to tell the views. An explicit [reloadEpoch] wins, for an emit that
  /// moves it without replacing anything.
  @override
  OcptBudgetState copyWith({
    bool? isLoading,
    String? title,
    OcptBudgetSnapshot? snapshot,
    bool forceSnapshotValue = false,
    String? currencyCode,
    OcptBudgetView? view,
    OcptBudgetToolsView? toolsView,
    bool? isSimplified,
    OcptBudgetTaxBasis? taxBasis,
    OcptBudgetSelection? selection,
    bool forceSelectionValue = false,
    String? filterAccountId,
    bool forceFilterAccountIdValue = false,
    String? selectedShareId,
    bool forceSelectedShareIdValue = false,
    Set<String>? expandedNodeIds,
    OcptBudgetRightDockTab? rightDockTab,
    bool forceRightDockTabValue = false,
    OcptBudgetRightDockTab? lastRightDockTab,
    double? rightDockFraction,
    List<OcptRole>? roles,
    List<OcptPerson>? people,
    List<OcptElement>? elements,
    List<OcptBudgetMileageRate>? mileageRates,
    String? provisionAccountId,
    bool forceProvisionAccountIdValue = false,
    Map<String, String>? logisticsSetNameByDayId,
    int? reloadEpoch,
    int? selectionEpoch,
    OcptBudgetSelectionCause? selectionCause,
    List<OcptProjectVersion>? projectVersions,
    String? previewedVersionId,
    bool forcePreviewedVersionIdValue = false,
    OcptProjectWorkingCopyState? workingCopy,
    bool forceWorkingCopyValue = false,
    String? versionPendingDeletionId,
    bool forceVersionPendingDeletionIdValue = false,
    String? versionPendingRestoreId,
    bool forceVersionPendingRestoreIdValue = false,
    String? versionPendingRenameId,
    bool forceVersionPendingRenameIdValue = false,
    OcptProjectVersionNoticeKind? projectVersionNotice,
    bool forceProjectVersionNoticeValue = false,
    OcptProjectPackagePreflight? projectPackagePendingExport,
    bool forceProjectPackagePendingExportValue = false,
    OcptProjectPackageNotice? projectPackageNotice,
    bool forceProjectPackageNoticeValue = false,
    OcptProjectPackageTarget? projectPackagePendingExportTarget,
    bool forceProjectPackagePendingExportTargetValue = false,
    OcptPageSetup? pageSetup,
  }) => OcptBudgetState(
    isLoading: isLoading ?? this.isLoading,
    title: title ?? this.title,
    snapshot: snapshot ?? (forceSnapshotValue ? null : this.snapshot),
    currencyCode: currencyCode ?? this.currencyCode,
    view: view ?? this.view,
    toolsView: toolsView ?? this.toolsView,
    isSimplified: isSimplified ?? this.isSimplified,
    taxBasis: taxBasis ?? this.taxBasis,
    selection: selection ?? (forceSelectionValue ? null : this.selection),
    filterAccountId: filterAccountId ?? (forceFilterAccountIdValue ? null : this.filterAccountId),
    selectedShareId: selectedShareId ?? (forceSelectedShareIdValue ? null : this.selectedShareId),
    expandedNodeIds: expandedNodeIds ?? this.expandedNodeIds,
    rightDockTab: rightDockTab ?? (forceRightDockTabValue ? null : this.rightDockTab),
    lastRightDockTab: lastRightDockTab ?? this.lastRightDockTab,
    rightDockFraction: rightDockFraction ?? this.rightDockFraction,
    roles: roles ?? this.roles,
    people: people ?? this.people,
    elements: elements ?? this.elements,
    mileageRates: mileageRates ?? this.mileageRates,
    provisionAccountId:
        provisionAccountId ?? (forceProvisionAccountIdValue ? null : this.provisionAccountId),
    logisticsSetNameByDayId: logisticsSetNameByDayId ?? this.logisticsSetNameByDayId,
    reloadEpoch: reloadEpoch ?? (snapshot != null ? this.reloadEpoch + 1 : this.reloadEpoch),
    selectionEpoch: selectionEpoch ?? this.selectionEpoch,
    selectionCause: selectionCause ?? this.selectionCause,
    projectVersions: projectVersions ?? this.projectVersions,
    previewedVersionId:
        previewedVersionId ?? (forcePreviewedVersionIdValue ? null : this.previewedVersionId),
    workingCopy: workingCopy ?? (forceWorkingCopyValue ? null : this.workingCopy),
    versionPendingDeletionId:
        versionPendingDeletionId ??
        (forceVersionPendingDeletionIdValue ? null : this.versionPendingDeletionId),
    versionPendingRestoreId:
        versionPendingRestoreId ??
        (forceVersionPendingRestoreIdValue ? null : this.versionPendingRestoreId),
    versionPendingRenameId:
        versionPendingRenameId ??
        (forceVersionPendingRenameIdValue ? null : this.versionPendingRenameId),
    projectVersionNotice:
        projectVersionNotice ?? (forceProjectVersionNoticeValue ? null : this.projectVersionNotice),
    projectPackagePendingExport:
        projectPackagePendingExport ??
        (forceProjectPackagePendingExportValue ? null : this.projectPackagePendingExport),
    projectPackageNotice:
        projectPackageNotice ?? (forceProjectPackageNoticeValue ? null : this.projectPackageNotice),
    projectPackagePendingExportTarget:
        projectPackagePendingExportTarget ??
        (forceProjectPackagePendingExportTargetValue
            ? null
            : this.projectPackagePendingExportTarget),
    pageSetup: pageSetup ?? this.pageSetup,
  );

  /// {@macro open_cine_prod_tools.MixinOcptProjectVersionsState.copyProjectVersionsState}
  @override
  OcptBudgetState copyProjectVersionsState({
    List<OcptProjectVersion>? projectVersions,
    String? previewedVersionId,
    bool forcePreviewedVersionIdValue = false,
    OcptProjectWorkingCopyState? workingCopy,
    bool forceWorkingCopyValue = false,
    String? versionPendingDeletionId,
    bool forceVersionPendingDeletionIdValue = false,
    String? versionPendingRestoreId,
    bool forceVersionPendingRestoreIdValue = false,
    String? versionPendingRenameId,
    bool forceVersionPendingRenameIdValue = false,
    OcptProjectVersionNoticeKind? projectVersionNotice,
    bool forceProjectVersionNoticeValue = false,
  }) => copyWith(
    projectVersions: projectVersions,
    previewedVersionId: previewedVersionId,
    forcePreviewedVersionIdValue: forcePreviewedVersionIdValue,
    workingCopy: workingCopy,
    forceWorkingCopyValue: forceWorkingCopyValue,
    versionPendingDeletionId: versionPendingDeletionId,
    forceVersionPendingDeletionIdValue: forceVersionPendingDeletionIdValue,
    versionPendingRestoreId: versionPendingRestoreId,
    forceVersionPendingRestoreIdValue: forceVersionPendingRestoreIdValue,
    versionPendingRenameId: versionPendingRenameId,
    forceVersionPendingRenameIdValue: forceVersionPendingRenameIdValue,
    projectVersionNotice: projectVersionNotice,
    forceProjectVersionNoticeValue: forceProjectVersionNoticeValue,
  );

  /// {@macro open_cine_prod_tools.MixinOcptProjectPackageState.copyProjectPackageState}
  @override
  OcptBudgetState copyProjectPackageState({
    OcptProjectPackagePreflight? projectPackagePendingExport,
    bool forceProjectPackagePendingExportValue = false,
    OcptProjectPackageNotice? projectPackageNotice,
    bool forceProjectPackageNoticeValue = false,
    OcptProjectPackageTarget? projectPackagePendingExportTarget,
    bool forceProjectPackagePendingExportTargetValue = false,
  }) => copyWith(
    projectPackagePendingExport: projectPackagePendingExport,
    forceProjectPackagePendingExportValue: forceProjectPackagePendingExportValue,
    projectPackageNotice: projectPackageNotice,
    forceProjectPackageNoticeValue: forceProjectPackageNoticeValue,
    projectPackagePendingExportTarget: projectPackagePendingExportTarget,
    forceProjectPackagePendingExportTargetValue: forceProjectPackagePendingExportTargetValue,
  );

  /// {@macro act_flutter_utility.BlocStateForMixin.props}
  @override
  List<Object?> get props => [
    ...super.props,
    isLoading,
    title,
    snapshot,
    currencyCode,
    view,
    toolsView,
    isSimplified,
    taxBasis,
    selection,
    filterAccountId,
    selectedShareId,
    expandedNodeIds,
    rightDockTab,
    lastRightDockTab,
    rightDockFraction,
    roles,
    people,
    elements,
    mileageRates,
    provisionAccountId,
    logisticsSetNameByDayId,
    reloadEpoch,
    selectionEpoch,
    selectionCause,
    pageSetup,
  ];
}
