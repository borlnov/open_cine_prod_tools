// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_file_compatibility.dart';
import 'package:open_cine_prod_tools/models/ocpt_recent_project_model.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_status.dart';

/// A recent project enriched with whether its file can still be found on disk.
class OcptHomeRecentProjectEntry extends Equatable {
  /// The recent project, as persisted by the properties manager.
  final OcptRecentProjectModel project;

  /// Whether [project]'s file still exists on disk.
  ///
  /// When false, the project's card is shown greyed out and can't be opened, but can still be
  /// removed from the list.
  final bool exists;

  /// Class constructor
  const OcptHomeRecentProjectEntry({required this.project, required this.exists});

  /// Object properties
  @override
  List<Object?> get props => [project, exists];
}

/// The state of `OcptHomeBloc`.
class OcptHomeState extends BlocStateForMixin<OcptHomeState> {
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

  /// Class constructor
  const OcptHomeState({
    required this.recentProjects,
    required this.isBusy,
    required this.error,
    this.pendingFileCompatibility,
  });

  /// Init class constructor
  const OcptHomeState.init()
    : recentProjects = const [],
      isBusy = false,
      error = null,
      pendingFileCompatibility = null;

  /// {@macro act_flutter_utility.BlocStateForMixin.copyWith}
  ///
  /// [error] and [pendingFileCompatibility] are only replaced when a new one is given or their
  /// clear flag is true; otherwise the current one is kept, since null is a legitimate "nothing to
  /// report" value that a plain `?? this.error` couldn't distinguish from "not provided".
  @override
  OcptHomeState copyWith({
    List<OcptHomeRecentProjectEntry>? recentProjects,
    bool? isBusy,
    OcptProjectStatus? error,
    bool clearError = false,
    OcptProjectFileCompatibility? pendingFileCompatibility,
    bool clearPendingFileCompatibility = false,
  }) => OcptHomeState(
    recentProjects: recentProjects ?? this.recentProjects,
    isBusy: isBusy ?? this.isBusy,
    error: clearError ? null : (error ?? this.error),
    pendingFileCompatibility: clearPendingFileCompatibility
        ? null
        : (pendingFileCompatibility ?? this.pendingFileCompatibility),
  );

  /// Object properties
  @override
  List<Object?> get props => [
    ...super.props,
    recentProjects,
    isBusy,
    error,
    pendingFileCompatibility,
  ];
}
