// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <benoit.rolandeau@allcircuits.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:equatable/equatable.dart';
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

  /// Class constructor
  const OcptHomeState({required this.recentProjects, required this.isBusy, required this.error});

  /// Init class constructor
  const OcptHomeState.init() : recentProjects = const [], isBusy = false, error = null;

  /// {@macro act_flutter_utility.BlocStateForMixin.copyWith}
  ///
  /// [error] is only replaced when a new one is given or [clearError] is true; otherwise the
  /// current one is kept, since null is a legitimate "no error" value that a plain `?? this.error`
  /// couldn't distinguish from "not provided".
  @override
  OcptHomeState copyWith({
    List<OcptHomeRecentProjectEntry>? recentProjects,
    bool? isBusy,
    OcptProjectStatus? error,
    bool clearError = false,
  }) => OcptHomeState(
    recentProjects: recentProjects ?? this.recentProjects,
    isBusy: isBusy ?? this.isBusy,
    error: clearError ? null : (error ?? this.error),
  );

  /// Object properties
  @override
  List<Object?> get props => [...super.props, recentProjects, isBusy, error];
}
