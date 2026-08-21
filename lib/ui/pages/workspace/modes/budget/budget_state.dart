// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_project_info_table.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_package_notice.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_package_report.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_working_copy_state.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_centre_view.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_tax_basis.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_version_notice_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_project_package_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_project_versions_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_alerts.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_journal.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_totals.dart';

/// The key [OcptBudgetState.pendingFieldEdits] is stored under: which poste or line, and which of
/// its own [OcptBudgetField]s — mirrors `OcptSchedulePendingFieldKey`.
typedef OcptBudgetPendingFieldKey = (String targetId, OcptBudgetField field);

/// The state of `OcptBudgetBloc`.
///
/// [pendingFieldEdits] is this mode's own single pending-edit map, over every free-text field of
/// every poste and every line — see `OcptBudgetField`'s own doc comment for why one flat map rather
/// than one per entity kind. [centreView], [isSimplified] and [taxBasis] are **not persisted**: the
/// schedule mode's own agenda mode is the precedent, only [rightDockFraction] and
/// [lastRightDockTab] surviving a relaunch.
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

  /// Which of the two centre views is currently shown.
  final OcptBudgetCentreView centreView;

  /// Whether the header's simplified/detailed switch currently reads simplified.
  final bool isSimplified;

  /// Which basis the header's excluding/including-tax toggle currently reads every amount in.
  final OcptBudgetTaxBasis taxBasis;

  /// The id of the currently selected poste, or null while none is.
  final String? selectedPosteId;

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

  /// What has actually been paid against each poste of [snapshot], empty while nothing is loaded —
  /// the dashboard's own `Paid` KPI reads this rather than recomputing it.
  Map<String, OcptBudgetCoveredTotal> get paidByPosteId => snapshot?.paidByPosteId ?? const {};

  /// What is committed against each poste of [snapshot], empty while nothing is loaded — the
  /// dashboard's own `Committed` KPI reads this rather than recomputing it.
  Map<String, OcptBudgetCoveredTotal> get committedByPosteId =>
      snapshot?.committedByPosteId ?? const {};

  /// The dashboard's own two alerts, empty while nothing is loaded or the project raises neither.
  List<OcptBudgetAlert> get alerts => snapshot?.alerts ?? const [];

  /// The project's default VAT rate, in basis points, or null while nobody has recorded one.
  int? get defaultVatRateBasisPoints => snapshot?.defaultVatRateBasisPoints;

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
    required this.centreView,
    required this.isSimplified,
    required this.taxBasis,
    required this.selectedPosteId,
    required this.expandedLineId,
    required this.rightDockTab,
    required this.lastRightDockTab,
    required this.rightDockFraction,
    required this.pendingFieldEdits,
    required this.projectVersions,
    required this.previewedVersionId,
    required this.workingCopy,
    required this.versionPendingDeletionId,
    required this.versionPendingRestoreId,
    required this.versionPendingRenameId,
    required this.projectVersionNotice,
    required this.projectPackagePendingExport,
    required this.projectPackageNotice,
  });

  /// Init class constructor
  const OcptBudgetState.init()
    : isLoading = true,
      title = "",
      snapshot = null,
      currencyCode = ocptDefaultCurrencyCode,
      centreView = OcptBudgetCentreView.dashboard,
      isSimplified = false,
      taxBasis = OcptBudgetTaxBasis.includingTax,
      selectedPosteId = null,
      expandedLineId = null,
      rightDockTab = null,
      lastRightDockTab = OcptBudgetRightDockTab.inspector,
      rightDockFraction = OcptWorkspaceDock.rightDefaultFraction,
      pendingFieldEdits = const {},
      projectVersions = const [],
      previewedVersionId = null,
      workingCopy = null,
      versionPendingDeletionId = null,
      versionPendingRestoreId = null,
      versionPendingRenameId = null,
      projectVersionNotice = null,
      projectPackagePendingExport = null,
      projectPackageNotice = null;

  /// {@macro act_flutter_utility.BlocStateForMixin.copyWith}
  ///
  /// [snapshot] is only replaced when a new one is given, exactly as `OcptScheduleState.snapshot`.
  /// [selectedPosteId], [expandedLineId] and [rightDockTab] all legitimately go back to null while
  /// the mode is alive, so each has its own clear flag. [pendingFieldEdits] is always replaced
  /// wholesale — the caller (the bloc's own field-edit handler) always computes the full next map.
  @override
  OcptBudgetState copyWith({
    bool? isLoading,
    String? title,
    OcptBudgetSnapshot? snapshot,
    String? currencyCode,
    OcptBudgetCentreView? centreView,
    bool? isSimplified,
    OcptBudgetTaxBasis? taxBasis,
    String? selectedPosteId,
    bool clearSelectedPosteId = false,
    String? expandedLineId,
    bool clearExpandedLineId = false,
    OcptBudgetRightDockTab? rightDockTab,
    bool clearRightDockTab = false,
    OcptBudgetRightDockTab? lastRightDockTab,
    double? rightDockFraction,
    Map<OcptBudgetPendingFieldKey, String>? pendingFieldEdits,
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
  }) => OcptBudgetState(
    isLoading: isLoading ?? this.isLoading,
    title: title ?? this.title,
    snapshot: snapshot ?? this.snapshot,
    currencyCode: currencyCode ?? this.currencyCode,
    centreView: centreView ?? this.centreView,
    isSimplified: isSimplified ?? this.isSimplified,
    taxBasis: taxBasis ?? this.taxBasis,
    selectedPosteId: clearSelectedPosteId ? null : (selectedPosteId ?? this.selectedPosteId),
    expandedLineId: clearExpandedLineId ? null : (expandedLineId ?? this.expandedLineId),
    rightDockTab: clearRightDockTab ? null : (rightDockTab ?? this.rightDockTab),
    lastRightDockTab: lastRightDockTab ?? this.lastRightDockTab,
    rightDockFraction: rightDockFraction ?? this.rightDockFraction,
    pendingFieldEdits: pendingFieldEdits ?? this.pendingFieldEdits,
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
    centreView,
    isSimplified,
    taxBasis,
    selectedPosteId,
    expandedLineId,
    rightDockTab,
    lastRightDockTab,
    rightDockFraction,
    pendingFieldEdits,
  ];
}
