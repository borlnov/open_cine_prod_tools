// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:fountain_kit/fountain_kit.dart';

/// The state of `OcptEditorStatisticsBloc`: the at-a-glance counters of the editor.
class OcptEditorStatisticsState extends BlocStateForMixin<OcptEditorStatisticsState> {
  /// The at-a-glance counters (page/scene/character/word/sign counts) shown in the editor's
  /// status bar, computed from the mode's document at its page setup's metrics.
  ///
  /// Lags the document slightly further behind the text than the parse debounce alone: recomputing
  /// it paginates the whole screenplay, which is too heavy to run on every parse tick while typing
  /// continuously (see `OcptEditorStatisticsBloc`'s own debounce).
  final FountainScriptStatistics statistics;

  /// The [FountainSceneStatistics] of the scene the caret is in, or null while nothing is parsed
  /// yet or the caret precedes every scene.
  ///
  /// Unlike the scene the caret is in itself, this doesn't recompute on every caret move: composing
  /// the whole document to derive [FountainSceneStatistics.pageEighths] is the same "too heavy for
  /// every frame" cost [statistics] already documents, so it is only recomputed on the mode's
  /// 150 ms parse debounce, or when a caret move actually lands on a different scene.
  final FountainSceneStatistics? sceneStatistics;

  /// Class constructor
  const OcptEditorStatisticsState({required this.statistics, required this.sceneStatistics});

  /// Init class constructor
  const OcptEditorStatisticsState.init()
    : statistics = FountainScriptStatistics.empty,
      sceneStatistics = null;

  /// {@macro act_flutter_utility.BlocStateForMixin.copyWith}
  ///
  /// [statistics] never goes back to [FountainScriptStatistics.empty] once set, so it needs no force
  /// flag; [sceneStatistics] goes back to null when the caret precedes every scene, through
  /// [forceSceneStatisticsValue].
  @override
  OcptEditorStatisticsState copyWith({
    FountainScriptStatistics? statistics,
    FountainSceneStatistics? sceneStatistics,
    bool forceSceneStatisticsValue = false,
  }) => OcptEditorStatisticsState(
    statistics: statistics ?? this.statistics,
    sceneStatistics: sceneStatistics ?? (forceSceneStatisticsValue ? null : this.sceneStatistics),
  );

  /// Object properties
  @override
  List<Object?> get props => [...super.props, statistics, sceneStatistics];
}
