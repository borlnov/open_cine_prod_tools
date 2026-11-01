// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_event.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_state.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_statistics_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/abs_ocpt_view_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_view_events.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_current_scene_index.dart';

/// This is the bloc class for the screenplay editor's counters: the script-wide statistics of the
/// status bar and the metadata panel, and the statistics of the scene the caret is in, shown by the
/// inspector.
///
/// It computes nothing of its own to compute from: it reads the mode's document, caret line and page
/// setup off the mode's state when it reacts, at three speeds.
///
/// - A new document (the mode's parse debounce) refreshes the scene's counters right away, which is
///   cheap relative to the script-wide pagination, and (re)starts this bloc's own debounce, so the
///   heavy pass behind `FountainScriptStatistics.of` only runs once typing pauses, never on every
///   parse tick. `FountainScriptComposer.compose` (which it calls to get the page count) measured
///   at ~14 ms per pass on a 141-page script, close enough to a frame budget that it must not run
///   on every 150 ms parse tick while the user is typing continuously.
/// - The caret landing on a different scene refreshes the scene's counters at once: moving the caret
///   is far rarer than typing a character.
/// - Any deliberate, infrequent change of what the mode shows (a load, an import, a title page
///   rewrite, a page setup change) recomputes both at once, dropping the pending debounce, so the
///   counters are up to date rather than waiting out the typing debounce.
class OcptEditorStatisticsBloc
    extends AbsOcptViewBloc<OcptEditorStatisticsState, OcptEditorState, OcptEditorBloc> {
  /// The default delay between the last parse tick and recomputing statistics.
  static const defaultStatisticsDebounce = Duration(milliseconds: 500);

  /// The delay between the last parse tick and recomputing statistics.
  final Duration _statisticsDebounce;

  /// The subscription to the mode's states, for what the epochs do not tell.
  late final StreamSubscription<OcptEditorState> _modeStates;

  /// The mode state [_onModeState] saw last, to tell what moved.
  OcptEditorState _previousModeState;

  /// Class constructor
  ///
  /// [statisticsDebounce] is only meant to be overridden by tests, to keep them fast and
  /// deterministic.
  OcptEditorStatisticsBloc({
    required super.modeBloc,
    Duration statisticsDebounce = defaultStatisticsDebounce,
  }) : _statisticsDebounce = statisticsDebounce,
       _previousModeState = modeBloc.state,
       super(const OcptEditorStatisticsState.init()) {
    _modeStates = modeBloc.stream.listen(_onModeState);
  }

  /// {@macro act_flutter_utility.BlocForMixin.registerMixinEvents}
  @override
  void registerMixinEvents() {
    super.registerMixinEvents();
    on<OcptEditorStatisticsRecomputeRequestedEvent>(_onStatisticsRecomputeRequested);
    on<OcptEditorStatisticsSceneRefreshRequestedEvent>(_onSceneRefreshRequested);
  }

  /// Recompute both counters at once and drop the pending debounce: the mode replaced what it
  /// shows (a load, an import, a title page rewrite, a new page setup).
  ///
  /// Does nothing while the mode has no document yet.
  @override
  Future<void> onModeStateChanged(
    OcptViewModeStateChangedEvent<OcptEditorState> event,
    Emitter<OcptEditorStatisticsState> emitter,
  ) async {
    if (!event.hasReloaded) {
      return;
    }

    cancelDebounce();
    final modeState = modeBloc.state;
    final document = modeState.document;
    if (document == null) {
      return;
    }

    final sceneStatistics = _sceneStatisticsOf(modeState);
    emitter(
      state.copyWithRecomputedStatistics(
        statistics: FountainScriptStatistics.of(document, modeState.pageSetup.toMetrics()),
        sceneStatistics: sceneStatistics,
      ),
    );
  }

  /// Turn what the mode's state moved, other than a reload, into a refresh of the scene's counters
  /// and a restart of the script-wide debounce.
  void _onModeState(OcptEditorState next) {
    final previous = _previousModeState;
    _previousModeState = next;

    final isReload = next.reloadEpoch > previous.reloadEpoch;
    if (isClosing || isReload) {
      return;
    }

    if (previous.document != next.document) {
      add(const OcptEditorStatisticsSceneRefreshRequestedEvent());
      restartDebounce(_statisticsDebounce, const OcptEditorStatisticsRecomputeRequestedEvent());
    } else if (next.document != null && previous.currentSceneIndex != next.currentSceneIndex) {
      add(const OcptEditorStatisticsSceneRefreshRequestedEvent());
    }
  }

  /// Recompute the statistics of the scene the caret is in, from the mode's current state.
  Future<void> _onSceneRefreshRequested(
    OcptEditorStatisticsSceneRefreshRequestedEvent event,
    Emitter<OcptEditorStatisticsState> emitter,
  ) async {
    if (modeBloc.state.document == null) {
      return;
    }

    final sceneStatistics = _sceneStatisticsOf(modeBloc.state);
    emitter(state.copyWithCaretScene(sceneStatistics: sceneStatistics));
  }

  /// Recompute statistics from the mode's current document and page setup, once the statistics
  /// debounce elapses. A no-op if nothing has been parsed yet.
  Future<void> _onStatisticsRecomputeRequested(
    OcptEditorStatisticsRecomputeRequestedEvent event,
    Emitter<OcptEditorStatisticsState> emitter,
  ) async {
    final modeState = modeBloc.state;
    final document = modeState.document;
    if (document == null) {
      return;
    }

    emitter(
      state.copyWithScriptStatistics(
        statistics: FountainScriptStatistics.of(document, modeState.pageSetup.toMetrics()),
      ),
    );
  }

  /// Compute the statistics of the scene [modeState]'s caret is in, or null if it precedes every
  /// scene or nothing is parsed.
  FountainSceneStatistics? _sceneStatisticsOf(OcptEditorState modeState) {
    final document = modeState.document;
    if (document == null) {
      return null;
    }

    final sceneIndex = currentSceneIndexFor(document.scenes, modeState.currentLine);
    return sceneIndex == null
        ? null
        : FountainSceneStatistics.of(document, modeState.pageSetup.toMetrics(), sceneIndex);
  }

  /// {@macro act_life_cycle.MixinWithLifeCycleDispose.disposeLifeCycle}
  @override
  Future<void> disposeLifeCycle() async {
    unawaited(_modeStates.cancel());
    return super.disposeLifeCycle();
  }
}
