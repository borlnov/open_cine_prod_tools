// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/ocpt_recent_project_model.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_file_verdict.dart';

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

  /// List the fields that decide equality.
  @override
  List<Object?> get props => [project, exists, verdict];
}
