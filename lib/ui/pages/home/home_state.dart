// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_file_compatibility.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_package_import_report.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_package_notice.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_package_report.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_package_target.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_package_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_screenplay_import_status.dart';
import 'package:open_cine_prod_tools/ui/pages/home/home_recent_project_entry.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_project_package_state.dart';

/// The state of `OcptHomeBloc`.
///
/// Mixes in [MixinOcptProjectPackageState] for a project card's own `Export…`: the same pair of
/// fields every production mode's state carries for the toolbar's `Export` panel, since the home
/// page runs the very same `MixinOcptProjectPackageBloc` flow over a project nothing has opened.
class OcptHomeState extends BlocStateForMixin<OcptHomeState>
    with MixinOcptProjectPackageState<OcptHomeState> {
  /// The recently opened projects, most recently opened first.
  final List<OcptHomeRecentProjectEntry> recentProjects;

  /// Whether a create/open operation is currently in progress.
  final bool isBusy;

  /// The status of the last create/open operation that failed, or null if none did (or if it was
  /// already dismissed).
  final OcptProjectStatus? error;

  /// What the probe found about a project file the user asked to open, while the page still has to
  /// state it; null the rest of the time.
  ///
  /// Only ever set for the two verdicts that stop an open in its tracks: an **older** file, whose
  /// migration has to be confirmed, and a **newer** one, which is refused. A file this build opens
  /// as it is never lands here — there is nothing to say about it.
  ///
  /// A **one-shot** field, like every question this app asks through its state: the page opens the
  /// dialog and dismisses it from the state straight away, so a later emission cannot open a second
  /// one behind the first.
  final OcptProjectFileCompatibility? pendingFileCompatibility;

  /// {@macro open_cine_prod_tools.MixinOcptProjectPackageState.projectPackagePendingExport}
  @override
  final OcptProjectPackagePreflight? projectPackagePendingExport;

  /// {@macro open_cine_prod_tools.MixinOcptProjectPackageState.projectPackageNotice}
  @override
  final OcptProjectPackageNotice? projectPackageNotice;

  /// {@macro open_cine_prod_tools.MixinOcptProjectPackageState.projectPackagePendingExportTarget}
  @override
  final OcptProjectPackageTarget? projectPackagePendingExportTarget;

  /// The status of the last project package import that failed, or null if none did (or it was
  /// already dismissed).
  ///
  /// A field of its own rather than reusing [error]: that one is an [OcptProjectStatus], a
  /// different enum entirely, and a project package import fails with an
  /// [OcptProjectPackageStatus] instead — the two must not be conflated into one field that could
  /// only ever hold one of them truthfully.
  final OcptProjectPackageStatus? projectPackageImportError;

  /// The status of the last screenplay import that failed to read the picked file, or null if
  /// none did (or it was already dismissed).
  ///
  /// A field of its own rather than reusing [error], for the very same reason
  /// [projectPackageImportError] is one: that field is an [OcptProjectStatus], and picking a file
  /// that cannot be read as a screenplay fails with an [OcptScreenplayImportStatus] instead. Only
  /// the failures worth stating land here — a cancelled dialog is a silent no-op.
  final OcptScreenplayImportStatus? screenplayImportError;

  /// What the last project package import landed the user with, while the page still has to state
  /// the skipped files (if any) and open the project itself; null the rest of the time.
  ///
  /// A **one-shot** field, like every question/report this state carries: the page reads it,
  /// dispatches `OcptHomeProjectPackageImportReportDismissedEvent` straight away, and only then
  /// acts on the copy it already holds — this bloc never opens the project it imports (see
  /// `OcptHomeImportProjectPackageRequestedEvent`'s own doc comment for why).
  final OcptProjectPackageImportReport? projectPackageImportReport;

  /// Class constructor
  const OcptHomeState({
    required this.recentProjects,
    required this.isBusy,
    required this.error,
    required this.pendingFileCompatibility,
    required this.projectPackagePendingExport,
    required this.projectPackageNotice,
    required this.projectPackagePendingExportTarget,
    required this.projectPackageImportError,
    required this.projectPackageImportReport,
    required this.screenplayImportError,
  });

  /// Init class constructor
  const OcptHomeState.init()
    : recentProjects = const [],
      isBusy = false,
      error = null,
      pendingFileCompatibility = null,
      projectPackagePendingExport = null,
      projectPackageNotice = null,
      projectPackagePendingExportTarget = null,
      projectPackageImportError = null,
      projectPackageImportReport = null,
      screenplayImportError = null;

  /// {@macro act_flutter_utility.BlocStateForMixin.copyWith}
  ///
  /// [error] and [pendingFileCompatibility] are only replaced when a new one is given or their
  /// force flag is true; otherwise the current one is kept, since null is a legitimate "nothing to
  /// report" value that a plain `?? this.error` couldn't distinguish from "not provided". The
  /// project package's own pairs — the export one through [copyProjectPackageState] below, the
  /// import one right here — and [screenplayImportError] follow the very same rule.
  @override
  OcptHomeState copyWith({
    List<OcptHomeRecentProjectEntry>? recentProjects,
    bool? isBusy,
    OcptProjectStatus? error,
    bool forceErrorValue = false,
    OcptProjectFileCompatibility? pendingFileCompatibility,
    bool forcePendingFileCompatibilityValue = false,
    OcptProjectPackagePreflight? projectPackagePendingExport,
    bool forceProjectPackagePendingExportValue = false,
    OcptProjectPackageNotice? projectPackageNotice,
    bool forceProjectPackageNoticeValue = false,
    OcptProjectPackageTarget? projectPackagePendingExportTarget,
    bool forceProjectPackagePendingExportTargetValue = false,
    OcptProjectPackageStatus? projectPackageImportError,
    bool forceProjectPackageImportErrorValue = false,
    OcptProjectPackageImportReport? projectPackageImportReport,
    bool forceProjectPackageImportReportValue = false,
    OcptScreenplayImportStatus? screenplayImportError,
    bool forceScreenplayImportErrorValue = false,
  }) => OcptHomeState(
    recentProjects: recentProjects ?? this.recentProjects,
    isBusy: isBusy ?? this.isBusy,
    error: error ?? (forceErrorValue ? null : this.error),
    pendingFileCompatibility:
        pendingFileCompatibility ??
        (forcePendingFileCompatibilityValue ? null : this.pendingFileCompatibility),
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
    projectPackageImportError:
        projectPackageImportError ??
        (forceProjectPackageImportErrorValue ? null : this.projectPackageImportError),
    projectPackageImportReport:
        projectPackageImportReport ??
        (forceProjectPackageImportReportValue ? null : this.projectPackageImportReport),
    screenplayImportError:
        screenplayImportError ??
        (forceScreenplayImportErrorValue ? null : this.screenplayImportError),
  );

  /// {@macro open_cine_prod_tools.MixinOcptProjectPackageState.copyProjectPackageState}
  @override
  OcptHomeState copyProjectPackageState({
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

  /// Copy this state with the [recentProjects] list read again.
  OcptHomeState copyWithRecentProjects({
    required List<OcptHomeRecentProjectEntry> recentProjects,
  }) => copyWith(recentProjects: recentProjects);

  /// Copy this state busy with a new action, and the previous error forgotten.
  OcptHomeState copyWithBusy() => copyWith(isBusy: true, forceErrorValue: true);

  /// Copy this state no longer busy.
  OcptHomeState copyWithIdle() => copyWith(isBusy: false);

  /// Copy this state no longer busy, the action having ended on [error].
  OcptHomeState copyWithFailure({required OcptProjectStatus error}) =>
      copyWith(isBusy: false, error: error);

  /// Copy this state no longer busy, with the [compatibility] verdict of the file to open pending
  /// the page's answer.
  OcptHomeState copyWithPendingFileCompatibility({
    required OcptProjectFileCompatibility compatibility,
  }) => copyWith(isBusy: false, pendingFileCompatibility: compatibility);

  /// Copy this state with the compatibility verdict the page has stated cleared.
  OcptHomeState copyWithFileCompatibilityStated() =>
      copyWith(forcePendingFileCompatibilityValue: true);

  /// Copy this state with the error dismissed.
  OcptHomeState copyWithErrorDismissed() => copyWith(forceErrorValue: true);

  /// Copy this state busy with a screenplay import, and the previous errors forgotten.
  OcptHomeState copyWithScreenplayImportStarted() =>
      copyWith(isBusy: true, forceErrorValue: true, forceScreenplayImportErrorValue: true);

  /// Copy this state no longer busy after the screenplay file was picked and read, with
  /// [screenplayImportError] stating why it could not be, if it is worth stating.
  OcptHomeState copyWithScreenplayImportRead({
    required OcptScreenplayImportStatus? screenplayImportError,
  }) => copyWith(isBusy: false, screenplayImportError: screenplayImportError);

  /// Copy this state with the screenplay import error dismissed.
  OcptHomeState copyWithScreenplayImportErrorDismissed() =>
      copyWith(forceScreenplayImportErrorValue: true);

  /// Copy this state busy with a project package import, and the previous errors forgotten.
  OcptHomeState copyWithProjectPackageImportStarted() =>
      copyWith(isBusy: true, forceErrorValue: true, forceProjectPackageImportErrorValue: true);

  /// Copy this state no longer busy, the project package import having ended on
  /// [projectPackageImportError].
  OcptHomeState copyWithProjectPackageImportFailed({
    required OcptProjectPackageStatus projectPackageImportError,
  }) => copyWith(isBusy: false, projectPackageImportError: projectPackageImportError);

  /// Copy this state no longer busy, the project package import having produced
  /// [projectPackageImportReport].
  OcptHomeState copyWithProjectPackageImported({
    required OcptProjectPackageImportReport projectPackageImportReport,
  }) => copyWith(isBusy: false, projectPackageImportReport: projectPackageImportReport);

  /// Copy this state with the project package import error dismissed.
  OcptHomeState copyWithProjectPackageImportErrorDismissed() =>
      copyWith(forceProjectPackageImportErrorValue: true);

  /// Copy this state with the project package import report dismissed.
  OcptHomeState copyWithProjectPackageImportReportDismissed() =>
      copyWith(forceProjectPackageImportReportValue: true);

  /// {@macro act_flutter_utility.BlocStateForMixin.props}
  @override
  List<Object?> get props => [
    ...super.props,
    recentProjects,
    isBusy,
    error,
    pendingFileCompatibility,
    projectPackageImportError,
    projectPackageImportReport,
    screenplayImportError,
  ];
}
