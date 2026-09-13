// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_file_compatibility.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_package_notice.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_package_report.dart';
import 'package:open_cine_prod_tools/models/ocpt_recent_project_model.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_file_verdict.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_package_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_screenplay_import_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_project_package_state.dart';

/// A recent project enriched with whether its file can still be found on disk.
class OcptHomeRecentProjectEntry extends Equatable {
  /// The recent project, as persisted by the properties manager.
  final OcptRecentProjectModel project;

  /// Whether [project]'s file still exists on disk.
  ///
  /// When false, the project's card is shown greyed out and can't be opened, but can still be
  /// removed from the list.
  final bool exists;

  /// What a read-only probe of [project]'s file found about its format, or null when [exists] is
  /// false (there is nothing to probe) or the probe was never run.
  ///
  /// Only ever shown as a badge for [OcptProjectFileVerdict.newer] and
  /// [OcptProjectFileVerdict.foreignDevBuild]: those two are the verdicts opening the project
  /// would refuse outright, which is worth flagging on the card itself rather than only once the
  /// user has tried to open it. [OcptProjectFileVerdict.older] is a normal, offered migration and
  /// draws nothing; [OcptProjectFileVerdict.current] and [OcptProjectFileVerdict.unreadable] draw
  /// nothing either — the former has nothing to say, the latter is not this gate's business.
  final OcptProjectFileVerdict? verdict;

  /// Class constructor
  const OcptHomeRecentProjectEntry({required this.project, required this.exists, this.verdict});

  /// Object properties
  @override
  List<Object?> get props => [project, exists, verdict];
}

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
    this.pendingFileCompatibility,
    this.projectPackagePendingExport,
    this.projectPackageNotice,
    this.projectPackageImportError,
    this.projectPackageImportReport,
    this.screenplayImportError,
  });

  /// Init class constructor
  const OcptHomeState.init()
    : recentProjects = const [],
      isBusy = false,
      error = null,
      pendingFileCompatibility = null,
      projectPackagePendingExport = null,
      projectPackageNotice = null,
      projectPackageImportError = null,
      projectPackageImportReport = null,
      screenplayImportError = null;

  /// {@macro act_flutter_utility.BlocStateForMixin.copyWith}
  ///
  /// [error] and [pendingFileCompatibility] are only replaced when a new one is given or their
  /// clear flag is true; otherwise the current one is kept, since null is a legitimate "nothing to
  /// report" value that a plain `?? this.error` couldn't distinguish from "not provided". The
  /// project package's own pairs — the export one through [copyProjectPackageState] below, the
  /// import one right here — and [screenplayImportError] follow the very same rule.
  @override
  OcptHomeState copyWith({
    List<OcptHomeRecentProjectEntry>? recentProjects,
    bool? isBusy,
    OcptProjectStatus? error,
    bool clearError = false,
    OcptProjectFileCompatibility? pendingFileCompatibility,
    bool clearPendingFileCompatibility = false,
    OcptProjectPackagePreflight? projectPackagePendingExport,
    bool clearProjectPackagePendingExport = false,
    OcptProjectPackageNotice? projectPackageNotice,
    bool clearProjectPackageNotice = false,
    OcptProjectPackageStatus? projectPackageImportError,
    bool clearProjectPackageImportError = false,
    OcptProjectPackageImportReport? projectPackageImportReport,
    bool clearProjectPackageImportReport = false,
    OcptScreenplayImportStatus? screenplayImportError,
    bool clearScreenplayImportError = false,
  }) => OcptHomeState(
    recentProjects: recentProjects ?? this.recentProjects,
    isBusy: isBusy ?? this.isBusy,
    error: clearError ? null : (error ?? this.error),
    pendingFileCompatibility: clearPendingFileCompatibility
        ? null
        : (pendingFileCompatibility ?? this.pendingFileCompatibility),
    projectPackagePendingExport: clearProjectPackagePendingExport
        ? null
        : (projectPackagePendingExport ?? this.projectPackagePendingExport),
    projectPackageNotice: clearProjectPackageNotice
        ? null
        : (projectPackageNotice ?? this.projectPackageNotice),
    projectPackageImportError: clearProjectPackageImportError
        ? null
        : (projectPackageImportError ?? this.projectPackageImportError),
    projectPackageImportReport: clearProjectPackageImportReport
        ? null
        : (projectPackageImportReport ?? this.projectPackageImportReport),
    screenplayImportError: clearScreenplayImportError
        ? null
        : (screenplayImportError ?? this.screenplayImportError),
  );

  /// {@macro open_cine_prod_tools.MixinOcptProjectPackageState.copyProjectPackageState}
  @override
  OcptHomeState copyProjectPackageState({
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
    recentProjects,
    isBusy,
    error,
    pendingFileCompatibility,
    projectPackageImportError,
    projectPackageImportReport,
    screenplayImportError,
  ];
}
