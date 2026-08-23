// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_project_info_table.dart';
import 'package:open_cine_prod_tools/models/ocpt_asset_ref.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_allowance.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_mileage_rate.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_resource.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_revenue.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_share.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_element.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_package_notice.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_package_report.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_working_copy_state.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_document.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_selection.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_sub_page.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_tax_basis.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_version_notice_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_project_package_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_project_versions_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_alerts.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_element_link.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_journal.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_regie.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_shares.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_totals.dart';

/// The key [OcptBudgetState.pendingFieldEdits] is stored under: which poste or line, and which of
/// its own [OcptBudgetField]s — mirrors `OcptSchedulePendingFieldKey`.
typedef OcptBudgetPendingFieldKey = (String targetId, OcptBudgetField field);

/// The kind of transient notice [OcptBudgetIoNotice] carries — one shared pair reused across the
/// mode's four exports (three PDFs and one XLSX), exactly as `OcptScheduleIoNoticeKind` shares its
/// own `fileExportSucceeded`/`exportFailed` pair across the schedule mode's own heterogeneous
/// documents rather than growing one kind per document.
enum OcptBudgetIoNoticeKind {
  /// One of the four exports was written successfully.
  fileExportSucceeded,

  /// One of the four exports failed outright (an exception was thrown while rendering or writing
  /// it). A cancelled save dialog is a silent no-op instead, exactly as every other export in the
  /// app treats it.
  exportFailed,
}

/// A transient notice, produced by `OcptBudgetBloc`, reporting the outcome of one of the mode's
/// four exports, shown as a SnackBar then dismissed. Modelled on `OcptScheduleIoNotice`.
class OcptBudgetIoNotice extends Equatable {
  /// The outcome this notice reports.
  final OcptBudgetIoNoticeKind kind;

  /// The path the export was written to, only set when [kind] is [OcptBudgetIoNoticeKind
  /// .fileExportSucceeded].
  final String? path;

  /// Class constructor
  const OcptBudgetIoNotice({required this.kind, this.path});

  /// Object properties
  @override
  List<Object?> get props => [kind, path];
}

/// The state of `OcptBudgetBloc`.
///
/// [pendingFieldEdits] is this mode's own single pending-edit map, over every free-text field of
/// every poste and every line — see `OcptBudgetField`'s own doc comment for why one flat map rather
/// than one per entity kind. [document], [reading], [subPage], [isSimplified] and [taxBasis] are
/// **not persisted**: the schedule mode's own agenda mode is the precedent, only
/// [rightDockFraction] and [lastRightDockTab] surviving a relaunch.
class OcptBudgetState extends BlocStateForMixin<OcptBudgetState>
    with MixinOcptProjectVersionsState<OcptBudgetState>, MixinOcptProjectPackageState<OcptBudgetState> {
  /// Whether the quote read is still being loaded from the project database.
  final bool isLoading;

  /// The title shown in the toolbar: the name of the project currently open.
  final String title;

  /// The whole quote read, as last loaded from the project database (the ten CNC postes seeded on
  /// first read), or null while nothing has been read yet.
  final OcptBudgetSnapshot? snapshot;

  /// The project's currency, an ISO 4217 code, as last loaded — [ocptDefaultCurrencyCode] before
  /// the first read lands, mirroring `OcptResourcesState.currencyCode`.
  final String currencyCode;

  /// Which of the mode's three documents is currently shown.
  final OcptBudgetDocument document;

  /// Which order [document]'s own rows are currently read in — meaningful for
  /// [OcptBudgetDocument.expenses] alone today, since the other two documents offer only
  /// [OcptBudgetDocumentReading.byTree] (`OcptBudgetDocumentReading`'s own doc comment).
  final OcptBudgetDocumentReading reading;

  /// The sub-page of [document] currently shown, or null while at its own top level — the
  /// breadcrumb's own "you are here", and the only thing it draws past `Expenses` while non-null.
  final OcptBudgetSubPage? subPage;

  /// Whether the header's simplified/detailed switch currently reads simplified.
  final bool isSimplified;

  /// Which basis the header's excluding/including-tax toggle currently reads every amount in.
  final OcptBudgetTaxBasis taxBasis;

  /// What is currently selected for the right dock's own fiche, once it exists — replaces the
  /// separate `selectedPosteId`/`selectedResourceId` id fields this state used to carry: see
  /// `OcptBudgetSelection`'s own doc comment for why one field now answers both. [selectedPosteId]
  /// and [selectedResourceId] below are the narrow getters every dock panel already reads, resolved
  /// off this one field so neither had to learn about the sealed type for this milestone.
  final OcptBudgetSelection? selection;

  /// The id of the currently selected poste, or null while [selection] does not name one.
  ///
  /// **A selection, and nothing else.** It drives the right dock's inspector and the row's own
  /// highlight; it narrows no view. It used to be the cash journal's filter too, one field doing
  /// two jobs, and that conflation was the fault: clicking a row in the quote silently filtered a
  /// view the reader was not even looking at, and they found out on arriving there. What narrows a
  /// view is [filterPosteId], which is only ever set by a gesture that says so.
  String? get selectedPosteId => switch (selection) {
    OcptBudgetPosteSelection(:final posteId) => posteId,
    _ => null,
  };

  /// The poste every view of the mode is currently narrowed to, or null for the whole project.
  ///
  /// **Mode-wide on purpose**, unlike [selectedPosteId]: it is set once, from the header, and holds
  /// across every view — which is what makes it worth having, since following one poste through
  /// the quote, what is owed on it and what has moved against it is the reading it exists for.
  /// The three views with no poste dimension at all (the financing plan, the régie, the revenue
  /// sharing) say so rather than pretending to honour it.
  final String? filterPosteId;

  /// The id of the currently selected financing resource, or null while [selection] does not name
  /// one — the financing view's own selection, read exactly as [selectedPosteId] is, but drawn as a
  /// plain highlight rather than opening a dock tab: see `OcptBudgetFinancing`'s own class doc
  /// comment for why this view carries no inspector of its own.
  String? get selectedResourceId => switch (selection) {
    OcptBudgetResourceSelection(:final resourceId) => resourceId,
    _ => null,
  };

  /// The id of the currently selected revenue sharing taking, or null while none is — the sharing
  /// view's own left-column selection, read and written exactly as [selectedResourceId] is, and for
  /// the same reason drawn as a plain highlight rather than opening a dock tab.
  final String? selectedRevenueId;

  /// The id of the currently selected revenue sharing share, or null while none is — the sharing
  /// view's own right-column selection, mirroring [selectedRevenueId].
  final String? selectedShareId;

  /// The id of the quote line whose card is currently expanded in the poste inspector, or null
  /// while none is — at most one line is ever expanded at a time.
  final String? expandedLineId;

  /// The right dock's currently active tab, or null if the dock is closed.
  final OcptBudgetRightDockTab? rightDockTab;

  /// The tab the toolbar's right-dock toggle reopens a closed dock on: the last one explicitly
  /// selected, mirroring `OcptScheduleState.lastRightDockTab`.
  final OcptBudgetRightDockTab lastRightDockTab;

  /// The right dock's width, as a fraction of the mode's content row width. Persisted through
  /// `OcptPropertiesManager.budgetRightDockFraction`. There is no left fraction: this mode has no
  /// left dock.
  final double rightDockFraction;

  /// Every free-text field still sitting in the field-edit debounce, keyed by which poste or line
  /// and which of its own fields. [fieldValueOf] is what a field reads instead of its own stored
  /// value while an edit is pending here.
  final Map<OcptBudgetPendingFieldKey, String> pendingFieldEdits;

  /// Every live role of the project, as last loaded — read by `OcptBudgetRegie` alone, to resolve a
  /// traveller's own convocation (a role's own [OcptRole.name] for a cast row, its
  /// [OcptRole.personId] to join a role back to the human playing it) and to tell cast from extras.
  /// Not part of [snapshot]: unlike the catering pass's own [OcptBudgetSnapshot.regieDays], this is
  /// the raw read the view resolves a display string
  /// from, exactly as `OcptScheduleState` carries its own roles beside its snapshot rather than
  /// inside it.
  final List<OcptRole> roles;

  /// Every live person of the project's address book, as last loaded — read by `OcptBudgetRegie`
  /// alone, for the same reason [roles] is: a traveller's own display name and declared crew
  /// position.
  final List<OcptPerson> people;

  /// Every live element of the breakdown's own catalogue, as last loaded — [elementLinkCounts] is
  /// the dashboard's own aggregate reading of it, and [unpricedElements] is what
  /// `OcptBudgetPosteInspector`'s own `+ From breakdown` picker offers. Not part of [snapshot]: the
  /// picker needs the whole catalogue, not a figure derived from it, exactly the reason [roles] and
  /// [people] already sit beside it rather than inside it.
  final List<OcptElement> elements;

  /// Every live mileage rate of the project, as last loaded — read by
  /// `OcptBudgetAllowanceDialog` alone, for its `Use this person's own rate` pre-fill. Not part of
  /// [snapshot]: the dialog needs the catalogue itself, not a figure derived from it, exactly the
  /// reason [roles] and [people] already sit beside it rather than inside it.
  final List<OcptBudgetMileageRate> mileageRates;

  /// The poste the régie view's own provisioning would write into, or null while this project's
  /// quote holds no poste at all.
  ///
  /// Defaults to the CNC nomenclature's own `Transports, défraiements, régie` poste when the
  /// project still has it, and to the first poste otherwise — a production is free to have renamed,
  /// split or deleted it, so this is a *preference among the postes that exist*, never an
  /// assumption that one of them does.
  final String? provisionPosteId;

  /// The decor name `OcptBudgetRegie` prints under each shooting day, keyed by the day's own id —
  /// the first location or set the day's own slots name, resolved once at load time out of the
  /// project's own locations catalogue (`OcptLocationsService.loadLocations`, read for this alone).
  /// A day with no key here names neither in any of its slots, which the view reads as nothing
  /// rather than a placeholder.
  final Map<String, String> regieDecorNameByDayId;

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

  /// The page setup the mode's own three PDF exports are pre-filled with: the open project's own
  /// page format, paired with the app-wide margins preference — loaded exactly as
  /// `OcptResourcesState.pageSetup` is, this mode carrying no screenplay of its own to typeset.
  final OcptPageSetup pageSetup;

  /// A transient notice reporting the outcome of one of the mode's four exports, shown as a
  /// SnackBar then dismissed, or null while none is pending.
  final OcptBudgetIoNotice? ioNotice;

  /// Every live poste of [snapshot], in display order (empty while nothing is loaded).
  List<OcptBudgetPoste> get postes => snapshot?.postes ?? const [];

  /// The number of live postes — the status bar's own first counter.
  int get posteCount => snapshot?.posteCount ?? 0;

  /// The total number of quote lines across every poste — the status bar's own second counter.
  int get lineCount => snapshot?.lineCount ?? 0;

  /// Every live journal entry of [snapshot], in chronological order (empty while nothing is
  /// loaded).
  List<OcptBudgetEntry> get entries => snapshot?.entries ?? const [];

  /// Every live commitment of [snapshot], in due-date order (empty while nothing is loaded).
  List<OcptBudgetCommitment> get commitments => snapshot?.commitments ?? const [];

  /// Every live financing resource of [snapshot], in `sortKey` order (empty while nothing is
  /// loaded).
  List<OcptBudgetResource> get resources => snapshot?.resources ?? const [];

  /// The number of live financing resources — mirrors [posteCount].
  int get resourceCount => snapshot?.resourceCount ?? 0;

  /// What has actually come in against each financing resource of [snapshot], keyed by its own id
  /// — empty while nothing is loaded. `OcptBudgetFinancing` reads this map itself, raw, for the one
  /// reading `receivedCentsOf` cannot answer — see [OcptBudgetSnapshot.receivedCentsOf]'s own doc
  /// comment.
  Map<String, OcptBudgetCoveredTotal> get receivedByResourceId => snapshot?.receivedByResourceId ?? const {};

  /// The cash journal's own debit, credit and balance — a zero-everything total while nothing is
  /// loaded, mirroring [postes]' own empty default.
  OcptBudgetCashTotals get cashTotals =>
      snapshot?.cashTotals ??
      const OcptBudgetCashTotals(debitCents: 0, creditCents: 0, coveredEntryCount: 0, entryCount: 0);

  /// `posteId`'s own paid total, in cents, tax-inclusive — 0 while [snapshot] is null or carries no
  /// entry against it. See `OcptBudgetSnapshot.paidCentsOf`'s own doc comment for why this is now
  /// honestly zero rather than a stand-in for an unknown figure.
  int paidCentsOf(String posteId) => snapshot?.paidCentsOf(posteId) ?? 0;

  /// `posteId`'s own committed total, in cents, tax-inclusive — 0 while [snapshot] is null or
  /// carries no commitment against it. See [paidCentsOf]'s own doc comment for the same reading.
  int committedCentsOf(String posteId) => snapshot?.committedCentsOf(posteId) ?? 0;

  /// `resourceId`'s own received total, in cents, tax-inclusive — 0 while [snapshot] is null or
  /// carries no entry against it. See [OcptBudgetSnapshot.receivedCentsOf]'s own doc comment for
  /// why this `?? 0` is the ordinary reading, and why the financing view reads [receivedByResourceId]
  /// itself for the one row kind that needs the other one.
  int receivedCentsOf(String resourceId) => snapshot?.receivedCentsOf(resourceId) ?? 0;

  /// Every live taking of [snapshot], in `sortKey` order (empty while nothing is loaded).
  List<OcptBudgetRevenue> get revenues => snapshot?.revenues ?? const [];

  /// The number of live takings — mirrors [resourceCount].
  int get revenueCount => snapshot?.revenueCount ?? 0;

  /// Every live share of [snapshot], in `sortKey` order (empty while nothing is loaded).
  List<OcptBudgetShare> get shares => snapshot?.shares ?? const [];

  /// The number of live shares — mirrors [resourceCount].
  int get shareCount => snapshot?.shareCount ?? 0;

  /// What has actually come in against each taking of [snapshot], keyed by its own id — empty
  /// while nothing is loaded. `OcptBudgetSharing` reads this map itself, raw, for the one reading
  /// [receivedRevenueCentsOf] cannot answer — mirrors [receivedByResourceId].
  Map<String, OcptBudgetCoveredTotal> get receivedByRevenueId => snapshot?.receivedByRevenueId ?? const {};

  /// What has actually been paid against each share of [snapshot], keyed by its own id — mirrors
  /// [receivedByRevenueId].
  Map<String, OcptBudgetCoveredTotal> get paidByShareId => snapshot?.paidByShareId ?? const {};

  /// What there is to share, and what stands between the takings and it — a zero-everything pot
  /// while nothing is loaded, mirroring [cashTotals]' own empty default.
  OcptBudgetSharingPot get sharingPot =>
      snapshot?.sharingPot ??
      const OcptBudgetSharingPot(
        received: OcptBudgetCoveredTotal(amountCents: 0, coveredLineCount: 0, lineCount: 0),
        reimbursableCents: 0,
        repaid: OcptBudgetCoveredTotal(amountCents: 0, coveredLineCount: 0, lineCount: 0),
      );

  /// The split of [sharingPot] across [shares], empty while nothing is loaded.
  List<OcptBudgetShareSplit> get shareSplits => snapshot?.shareSplits ?? const [];

  /// [resources]' own reimbursable ones, grouped by lender — empty while nothing is loaded. The
  /// `Repaying the contributions` card's own detail: who is owed what.
  List<OcptBudgetRepaymentLine> get repaymentLines => snapshot?.repaymentLines ?? const [];

  /// `revenueId`'s own received total, in cents, tax-inclusive — 0 while [snapshot] is null or
  /// carries no entry against it. Mirrors [receivedCentsOf].
  int receivedRevenueCentsOf(String revenueId) => snapshot?.receivedRevenueCentsOf(revenueId) ?? 0;

  /// `shareId`'s own paid total, in cents, tax-inclusive — 0 while [snapshot] is null or carries no
  /// entry against it. Mirrors [receivedCentsOf].
  int paidShareCentsOf(String shareId) => snapshot?.paidShareCentsOf(shareId) ?? 0;

  /// What has actually been paid against each poste of [snapshot], empty while nothing is loaded —
  /// the dashboard's own `Paid` KPI reads this rather than recomputing it.
  Map<String, OcptBudgetCoveredTotal> get paidByPosteId => snapshot?.paidByPosteId ?? const {};

  /// The total of every debit that names no poste at all — spending outside the quote,
  /// `OcptBudgetSnapshot.offQuotePaidTotal`'s own doc comment. Zero and complete while nothing is
  /// loaded, mirroring [cashTotals]' own empty default. The dashboard's own `Paid` KPI and the
  /// cost-tracking table's own total row both fold this in alongside [paidByPosteId].
  OcptBudgetCoveredTotal get offQuotePaidTotal =>
      snapshot?.offQuotePaidTotal ??
      const OcptBudgetCoveredTotal(amountCents: 0, coveredLineCount: 0, lineCount: 0);

  /// What is committed against each poste of [snapshot], empty while nothing is loaded — the
  /// dashboard's own `Committed` KPI reads this rather than recomputing it.
  Map<String, OcptBudgetCoveredTotal> get committedByPosteId =>
      snapshot?.committedByPosteId ?? const {};

  /// The dashboard's own two alerts, empty while nothing is loaded or the project raises neither.
  List<OcptBudgetAlert> get alerts => snapshot?.alerts ?? const [];

  /// How many of [elements] a live quote line already prices, and how many are not — the
  /// dashboard's own "what feeds this budget" card's own breakdown row, derived here rather than in
  /// that widget, exactly as [paidByPosteId] is derived here rather than in the cost-tracking table.
  OcptBudgetElementLinkCounts get elementLinkCounts =>
      ocptBudgetElementLinkCountsOf(postes: postes, elements: elements);

  /// Every one of [elements] no live quote line prices yet — what
  /// `OcptBudgetPosteInspector`'s own `+ From breakdown` picker offers.
  List<OcptElement> get unpricedElements =>
      ocptBudgetUnpricedElementsOf(postes: postes, elements: elements);

  /// Every live shooting day's own catering reading, empty while nothing is loaded or the project
  /// holds no shooting day — `OcptBudgetRegie`'s own left column.
  List<OcptBudgetRegieDay> get regieDays => snapshot?.regieDays ?? const [];

  /// [regieDays] folded into one total — a zero-everything, fully-covered total while nothing is
  /// loaded, mirroring [cashTotals]' own empty default.
  OcptBudgetRegieTotals get regieTotals =>
      snapshot?.regieTotals ??
      const OcptBudgetRegieTotals(
        headCount: 0,
        mealCount: 0,
        buffetCount: 0,
        cost: OcptBudgetCoveredTotal(amountCents: 0, coveredLineCount: 0, lineCount: 0),
      );

  /// Every live defrayal, empty while nothing is loaded or the production has defrayed nobody —
  /// `OcptBudgetRegie`'s own right column.
  List<OcptBudgetAllowance> get allowances => snapshot?.allowances ?? const [];

  /// Every live voucher, keyed by the `budget_entries` row it evidences — empty while nothing is
  /// loaded or no entry carries one.
  Map<String, OcptAssetRef> get receiptsByEntryId => snapshot?.receiptsByEntryId ?? const {};

  /// The project's default VAT rate, in basis points, or null while nobody has recorded one.
  int? get defaultVatRateBasisPoints => snapshot?.defaultVatRateBasisPoints;

  /// The project's own meal price, in cents, or null while nobody has recorded one —
  /// `OcptBudgetRegie`'s own caption.
  int? get mealPriceCents => snapshot?.mealPriceCents;

  /// The project's own buffet price, in cents, or null while nobody has recorded one — mirrors
  /// [mealPriceCents].
  int? get buffetPriceCents => snapshot?.buffetPriceCents;

  /// The selected poste, or null while none is selected (or the selected one disappeared from a
  /// freshly loaded [snapshot]).
  OcptBudgetPoste? get selectedPoste {
    final selectedPosteId = this.selectedPosteId;
    if (selectedPosteId == null) {
      return null;
    }

    for (final poste in postes) {
      if (poste.id == selectedPosteId) {
        return poste;
      }
    }

    return null;
  }

  /// The selected financing resource, or null while none is selected (or the selected one
  /// disappeared from a freshly loaded [snapshot]) — mirrors [selectedPoste].
  OcptBudgetResource? get selectedResource {
    final selectedResourceId = this.selectedResourceId;
    if (selectedResourceId == null) {
      return null;
    }

    for (final resource in resources) {
      if (resource.id == selectedResourceId) {
        return resource;
      }
    }

    return null;
  }

  /// The selected taking, or null while none is selected (or the selected one disappeared from a
  /// freshly loaded [snapshot]) — mirrors [selectedResource].
  OcptBudgetRevenue? get selectedRevenue {
    final selectedRevenueId = this.selectedRevenueId;
    if (selectedRevenueId == null) {
      return null;
    }

    for (final revenue in revenues) {
      if (revenue.id == selectedRevenueId) {
        return revenue;
      }
    }

    return null;
  }

  /// The selected share, or null while none is selected (or the selected one disappeared from a
  /// freshly loaded [snapshot]) — mirrors [selectedResource].
  OcptBudgetShare? get selectedShare {
    final selectedShareId = this.selectedShareId;
    if (selectedShareId == null) {
      return null;
    }

    for (final share in shares) {
      if (share.id == selectedShareId) {
        return share;
      }
    }

    return null;
  }

  /// [targetId]'s current value for [field] — a pending edit still sitting in [pendingFieldEdits],
  /// or [storedValue] (the record's own value, read off the call site) otherwise, exactly as
  /// `OcptScheduleState.fieldValueOf` resolves a day's, a slot's or a block's own fields.
  String fieldValueOf(String targetId, OcptBudgetField field, String storedValue) =>
      pendingFieldEdits[(targetId, field)] ?? storedValue;

  /// Class constructor
  const OcptBudgetState({
    required this.isLoading,
    required this.title,
    required this.snapshot,
    required this.currencyCode,
    required this.document,
    required this.reading,
    required this.subPage,
    required this.isSimplified,
    required this.taxBasis,
    required this.selection,
    required this.filterPosteId,
    required this.selectedRevenueId,
    required this.selectedShareId,
    required this.expandedLineId,
    required this.rightDockTab,
    required this.lastRightDockTab,
    required this.rightDockFraction,
    required this.pendingFieldEdits,
    required this.roles,
    required this.people,
    required this.elements,
    required this.mileageRates,
    required this.provisionPosteId,
    required this.regieDecorNameByDayId,
    required this.projectVersions,
    required this.previewedVersionId,
    required this.workingCopy,
    required this.versionPendingDeletionId,
    required this.versionPendingRestoreId,
    required this.versionPendingRenameId,
    required this.projectVersionNotice,
    required this.projectPackagePendingExport,
    required this.projectPackageNotice,
    required this.pageSetup,
    required this.ioNotice,
  });

  /// Init class constructor
  const OcptBudgetState.init()
    : isLoading = true,
      title = "",
      snapshot = null,
      currencyCode = ocptDefaultCurrencyCode,
      // The mode opens on the same default it always has — the read-only overview — carried today
      // as expenses's own dashboard sub-page rather than a standalone fourth document.
      document = OcptBudgetDocument.expenses,
      reading = OcptBudgetDocumentReading.byTree,
      subPage = OcptBudgetSubPage.dashboard,
      isSimplified = false,
      taxBasis = OcptBudgetTaxBasis.includingTax,
      selection = null,
      filterPosteId = null,
      selectedRevenueId = null,
      selectedShareId = null,
      expandedLineId = null,
      rightDockTab = null,
      lastRightDockTab = OcptBudgetRightDockTab.inspector,
      rightDockFraction = OcptWorkspaceDock.rightDefaultFraction,
      pendingFieldEdits = const {},
      roles = const [],
      people = const [],
      elements = const [],
      mileageRates = const [],
      provisionPosteId = null,
      regieDecorNameByDayId = const {},
      projectVersions = const [],
      previewedVersionId = null,
      workingCopy = null,
      versionPendingDeletionId = null,
      versionPendingRestoreId = null,
      versionPendingRenameId = null,
      projectVersionNotice = null,
      projectPackagePendingExport = null,
      projectPackageNotice = null,
      pageSetup = const OcptPageSetup.standard(),
      ioNotice = null;

  /// {@macro act_flutter_utility.BlocStateForMixin.copyWith}
  ///
  /// [snapshot] is only replaced when a new one is given, exactly as `OcptScheduleState.snapshot`.
  /// [selection], [filterPosteId], [subPage], [expandedLineId] and [rightDockTab] all legitimately
  /// go back to null while the mode is alive, so each has its own clear flag. [pendingFieldEdits]
  /// is always replaced wholesale — the caller (the bloc's own field-edit handler) always computes
  /// the full next map.
  @override
  OcptBudgetState copyWith({
    bool? isLoading,
    String? title,
    OcptBudgetSnapshot? snapshot,
    String? currencyCode,
    OcptBudgetDocument? document,
    OcptBudgetDocumentReading? reading,
    OcptBudgetSubPage? subPage,
    bool clearSubPage = false,
    bool? isSimplified,
    OcptBudgetTaxBasis? taxBasis,
    OcptBudgetSelection? selection,
    bool clearSelection = false,
    String? filterPosteId,
    bool clearFilterPosteId = false,
    String? selectedRevenueId,
    bool clearSelectedRevenueId = false,
    String? selectedShareId,
    bool clearSelectedShareId = false,
    String? expandedLineId,
    bool clearExpandedLineId = false,
    OcptBudgetRightDockTab? rightDockTab,
    bool clearRightDockTab = false,
    OcptBudgetRightDockTab? lastRightDockTab,
    double? rightDockFraction,
    Map<OcptBudgetPendingFieldKey, String>? pendingFieldEdits,
    List<OcptRole>? roles,
    List<OcptPerson>? people,
    List<OcptElement>? elements,
    List<OcptBudgetMileageRate>? mileageRates,
    String? provisionPosteId,
    Map<String, String>? regieDecorNameByDayId,
    List<OcptProjectVersion>? projectVersions,
    String? previewedVersionId,
    bool clearPreviewedVersionId = false,
    OcptProjectWorkingCopyState? workingCopy,
    bool clearWorkingCopy = false,
    String? versionPendingDeletionId,
    bool clearVersionPendingDeletionId = false,
    String? versionPendingRestoreId,
    bool clearVersionPendingRestoreId = false,
    String? versionPendingRenameId,
    bool clearVersionPendingRenameId = false,
    OcptProjectVersionNoticeKind? projectVersionNotice,
    bool clearProjectVersionNotice = false,
    OcptProjectPackagePreflight? projectPackagePendingExport,
    bool clearProjectPackagePendingExport = false,
    OcptProjectPackageNotice? projectPackageNotice,
    bool clearProjectPackageNotice = false,
    OcptPageSetup? pageSetup,
    OcptBudgetIoNotice? ioNotice,
    bool clearIoNotice = false,
  }) => OcptBudgetState(
    isLoading: isLoading ?? this.isLoading,
    title: title ?? this.title,
    snapshot: snapshot ?? this.snapshot,
    currencyCode: currencyCode ?? this.currencyCode,
    document: document ?? this.document,
    reading: reading ?? this.reading,
    subPage: clearSubPage ? null : (subPage ?? this.subPage),
    isSimplified: isSimplified ?? this.isSimplified,
    taxBasis: taxBasis ?? this.taxBasis,
    selection: clearSelection ? null : (selection ?? this.selection),
    filterPosteId: clearFilterPosteId ? null : (filterPosteId ?? this.filterPosteId),
    selectedRevenueId: clearSelectedRevenueId ? null : (selectedRevenueId ?? this.selectedRevenueId),
    selectedShareId: clearSelectedShareId ? null : (selectedShareId ?? this.selectedShareId),
    expandedLineId: clearExpandedLineId ? null : (expandedLineId ?? this.expandedLineId),
    rightDockTab: clearRightDockTab ? null : (rightDockTab ?? this.rightDockTab),
    lastRightDockTab: lastRightDockTab ?? this.lastRightDockTab,
    rightDockFraction: rightDockFraction ?? this.rightDockFraction,
    pendingFieldEdits: pendingFieldEdits ?? this.pendingFieldEdits,
    roles: roles ?? this.roles,
    people: people ?? this.people,
    elements: elements ?? this.elements,
    mileageRates: mileageRates ?? this.mileageRates,
    provisionPosteId: provisionPosteId ?? this.provisionPosteId,
    regieDecorNameByDayId: regieDecorNameByDayId ?? this.regieDecorNameByDayId,
    projectVersions: projectVersions ?? this.projectVersions,
    previewedVersionId: clearPreviewedVersionId ? null : (previewedVersionId ?? this.previewedVersionId),
    workingCopy: clearWorkingCopy ? null : (workingCopy ?? this.workingCopy),
    versionPendingDeletionId: clearVersionPendingDeletionId
        ? null
        : (versionPendingDeletionId ?? this.versionPendingDeletionId),
    versionPendingRestoreId: clearVersionPendingRestoreId
        ? null
        : (versionPendingRestoreId ?? this.versionPendingRestoreId),
    versionPendingRenameId: clearVersionPendingRenameId
        ? null
        : (versionPendingRenameId ?? this.versionPendingRenameId),
    projectVersionNotice: clearProjectVersionNotice
        ? null
        : (projectVersionNotice ?? this.projectVersionNotice),
    projectPackagePendingExport: clearProjectPackagePendingExport
        ? null
        : (projectPackagePendingExport ?? this.projectPackagePendingExport),
    projectPackageNotice: clearProjectPackageNotice
        ? null
        : (projectPackageNotice ?? this.projectPackageNotice),
    pageSetup: pageSetup ?? this.pageSetup,
    ioNotice: clearIoNotice ? null : (ioNotice ?? this.ioNotice),
  );

  /// {@macro open_cine_prod_tools.MixinOcptProjectVersionsState.copyProjectVersionsState}
  @override
  OcptBudgetState copyProjectVersionsState({
    List<OcptProjectVersion>? projectVersions,
    String? previewedVersionId,
    bool clearPreviewedVersionId = false,
    OcptProjectWorkingCopyState? workingCopy,
    bool clearWorkingCopy = false,
    String? versionPendingDeletionId,
    bool clearVersionPendingDeletionId = false,
    String? versionPendingRestoreId,
    bool clearVersionPendingRestoreId = false,
    String? versionPendingRenameId,
    bool clearVersionPendingRenameId = false,
    OcptProjectVersionNoticeKind? projectVersionNotice,
    bool clearProjectVersionNotice = false,
  }) => copyWith(
    projectVersions: projectVersions,
    previewedVersionId: previewedVersionId,
    clearPreviewedVersionId: clearPreviewedVersionId,
    workingCopy: workingCopy,
    clearWorkingCopy: clearWorkingCopy,
    versionPendingDeletionId: versionPendingDeletionId,
    clearVersionPendingDeletionId: clearVersionPendingDeletionId,
    versionPendingRestoreId: versionPendingRestoreId,
    clearVersionPendingRestoreId: clearVersionPendingRestoreId,
    versionPendingRenameId: versionPendingRenameId,
    clearVersionPendingRenameId: clearVersionPendingRenameId,
    projectVersionNotice: projectVersionNotice,
    clearProjectVersionNotice: clearProjectVersionNotice,
  );

  /// {@macro open_cine_prod_tools.MixinOcptProjectPackageState.copyProjectPackageState}
  @override
  OcptBudgetState copyProjectPackageState({
    OcptProjectPackagePreflight? projectPackagePendingExport,
    bool clearProjectPackagePendingExport = false,
    OcptProjectPackageNotice? projectPackageNotice,
    bool clearProjectPackageNotice = false,
  }) => copyWith(
    projectPackagePendingExport: projectPackagePendingExport,
    clearProjectPackagePendingExport: clearProjectPackagePendingExport,
    projectPackageNotice: projectPackageNotice,
    clearProjectPackageNotice: clearProjectPackageNotice,
  );

  /// Object properties
  @override
  List<Object?> get props => [
    ...super.props,
    isLoading,
    title,
    snapshot,
    currencyCode,
    document,
    reading,
    subPage,
    isSimplified,
    taxBasis,
    selection,
    filterPosteId,
    selectedRevenueId,
    selectedShareId,
    expandedLineId,
    rightDockTab,
    lastRightDockTab,
    rightDockFraction,
    pendingFieldEdits,
    roles,
    people,
    elements,
    mileageRates,
    provisionPosteId,
    regieDecorNameByDayId,
    pageSetup,
    ioNotice,
  ];
}
