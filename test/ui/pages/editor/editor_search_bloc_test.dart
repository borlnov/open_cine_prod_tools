// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_event.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_search_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_search_state.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// A router manager that is never asked to leave: the search bloc does not navigate.
class _InertRouterManager extends OcptRouterManager {}

/// An export manager that is never asked for anything.
class _InertExportManager extends OcptExportManager {
  /// Class constructor
  _InertExportManager() : super(fileSelectorManager: const FileSelectorManager());
}

/// Run the tests of [OcptEditorSearchBloc].
void main() {
  late OcptPropertiesManager propertiesManager;
  late OcptProjectsManager projectsManager;

  setUpAll(() async {
    OcptGlobalManager.instance;

    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();
    projectsManager = OcptProjectsManager(
      propertiesManager: propertiesManager,
      appLanguageCode: () => "en",
    );
    await projectsManager.initLifeCycle();
  });

  tearDownAll(() => projectsManager.disposeLifeCycle());

  /// Builds the search bloc on a mode bloc with no project open, which is all it needs: the search
  /// reads nothing of the mode.
  OcptEditorSearchBloc buildBloc() {
    final mode = OcptEditorBloc(
      projectsManager: projectsManager,
      propertiesManager: propertiesManager,
      routerManager: _InertRouterManager(),
      exportManager: _InertExportManager(),
    );
    addTearDown(mode.close);

    return OcptEditorSearchBloc(modeBloc: mode);
  }

  /// Waits for the first state of [bloc] matching [predicate] (the current one included).
  Future<OcptEditorSearchState> waitForState(
    OcptEditorSearchBloc bloc,
    bool Function(OcptEditorSearchState state) predicate,
  ) async {
    if (predicate(bloc.state)) {
      return bloc.state;
    }

    return bloc.stream.firstWhere(predicate).timeout(const Duration(seconds: 5));
  }

  group('find/replace', () {
    test('OcptEditorState.init starts with the bar closed and no search', () {
      const state = OcptEditorSearchState.init();

      expect(state.isOpen, isFalse);
      expect(state.isReplaceRowOpen, isFalse);
      expect(state.query, "");
      expect(state.matchCount, 0);
      expect(state.currentMatchIndex, isNull);
    });

    test(
      'Ctrl+F opens the bar with the replace row folded and bumps the focus request id',
      () async {
        final bloc = buildBloc();
        final focusRequestIdBefore = bloc.state.focusRequestId;

        bloc.add(const OcptEditorSearchOpenedEvent(withReplaceRow: false));
        final state = await waitForState(bloc, (state) => state.isOpen);

        expect(state.isReplaceRowOpen, isFalse);
        expect(state.focusRequestId, greaterThan(focusRequestIdBefore));

        await bloc.close();
      },
    );

    test('Ctrl+H opens the bar with the replace row unfolded', () async {
      final bloc = buildBloc();

      bloc.add(const OcptEditorSearchOpenedEvent(withReplaceRow: true));
      final state = await waitForState(bloc, (state) => state.isOpen);

      expect(state.isReplaceRowOpen, isTrue);

      await bloc.close();
    });

    test(
      'opening an already-open, replace-unfolded bar with Ctrl+F never folds the row back',
      () async {
        final bloc = buildBloc();

        bloc.add(const OcptEditorSearchOpenedEvent(withReplaceRow: true));
        await waitForState(bloc, (state) => state.isReplaceRowOpen);
        final focusRequestIdBefore = bloc.state.focusRequestId;

        bloc.add(const OcptEditorSearchOpenedEvent(withReplaceRow: false));
        final state = await waitForState(
          bloc,
          (state) => state.focusRequestId > focusRequestIdBefore,
        );

        expect(state.isReplaceRowOpen, isTrue);

        await bloc.close();
      },
    );

    test('the chevron folds and unfolds the replace row', () async {
      final bloc = buildBloc();

      bloc.add(const OcptEditorSearchReplaceRowToggledEvent());
      final openState = await waitForState(bloc, (state) => state.isReplaceRowOpen);
      expect(openState.isReplaceRowOpen, isTrue);

      bloc.add(const OcptEditorSearchReplaceRowToggledEvent());
      final closedState = await waitForState(bloc, (state) => !state.isReplaceRowOpen);
      expect(closedState.isReplaceRowOpen, isFalse);

      await bloc.close();
    });

    test('closing the bar clears the highlight but keeps the query, the replacement and both '
        'options, so reopening comes back to the same search', () async {
      final bloc = buildBloc();

      bloc.add(const OcptEditorSearchOpenedEvent(withReplaceRow: true));
      bloc.add(const OcptEditorSearchQueryChangedEvent(query: "MARIE"));
      bloc.add(const OcptEditorSearchReplacementChangedEvent(replacement: "JEANNE"));
      bloc.add(const OcptEditorSearchCaseSensitivityToggledEvent());
      bloc.add(const OcptEditorSearchWholeWordToggledEvent());
      bloc.add(const OcptEditorSearchMatchesReportedEvent(matchCount: 3));
      await waitForState(bloc, (state) => state.matchCount == 3);

      bloc.add(const OcptEditorSearchClosedEvent());
      final closedState = await waitForState(bloc, (state) => !state.isOpen);

      expect(closedState.matchCount, 0);
      expect(closedState.currentMatchIndex, isNull);
      expect(closedState.query, "MARIE");
      expect(closedState.replacement, "JEANNE");
      expect(closedState.isCaseSensitive, isTrue);
      expect(closedState.isWholeWord, isTrue);

      bloc.add(const OcptEditorSearchOpenedEvent(withReplaceRow: false));
      final reopenedState = await waitForState(bloc, (state) => state.isOpen);

      expect(reopenedState.query, "MARIE");
      expect(reopenedState.replacement, "JEANNE");
      expect(reopenedState.isCaseSensitive, isTrue);
      expect(reopenedState.isWholeWord, isTrue);

      await bloc.close();
    });

    test('a query change resets the current match index to 0', () async {
      final bloc = buildBloc();

      bloc.add(const OcptEditorSearchOpenedEvent(withReplaceRow: false));
      bloc.add(const OcptEditorSearchMatchesReportedEvent(matchCount: 5));
      await waitForState(bloc, (state) => state.matchCount == 5);
      bloc.add(const OcptEditorSearchNextRequestedEvent());
      await waitForState(bloc, (state) => state.currentMatchIndex == 1);

      bloc.add(const OcptEditorSearchQueryChangedEvent(query: "MARIE"));
      final state = await waitForState(bloc, (state) => state.query == "MARIE");

      expect(state.currentMatchIndex, 0);

      await bloc.close();
    });

    test('reporting zero matches clears the current match index back to null', () async {
      final bloc = buildBloc();

      bloc.add(const OcptEditorSearchOpenedEvent(withReplaceRow: false));
      bloc.add(const OcptEditorSearchMatchesReportedEvent(matchCount: 2));
      await waitForState(bloc, (state) => state.matchCount == 2);

      bloc.add(const OcptEditorSearchMatchesReportedEvent(matchCount: 0));
      final state = await waitForState(bloc, (state) => state.matchCount == 0);

      expect(state.currentMatchIndex, isNull);

      await bloc.close();
    });

    test('the current match index clamps down when a reported count shrinks', () async {
      final bloc = buildBloc();

      bloc.add(const OcptEditorSearchOpenedEvent(withReplaceRow: false));
      bloc.add(const OcptEditorSearchMatchesReportedEvent(matchCount: 5));
      await waitForState(bloc, (state) => state.matchCount == 5);
      bloc.add(const OcptEditorSearchNextRequestedEvent());
      bloc.add(const OcptEditorSearchNextRequestedEvent());
      bloc.add(const OcptEditorSearchNextRequestedEvent());
      bloc.add(const OcptEditorSearchNextRequestedEvent());
      final lastIndexState = await waitForState(bloc, (state) => state.currentMatchIndex == 4);
      expect(lastIndexState.currentMatchIndex, 4);

      // The count shrinks to 2 (indices 0 and 1 only): the current index clamps down into range
      // rather than pointing past the end of the new, shorter match list.
      bloc.add(const OcptEditorSearchMatchesReportedEvent(matchCount: 2));
      final clampedState = await waitForState(bloc, (state) => state.matchCount == 2);

      expect(clampedState.currentMatchIndex, 1);

      await bloc.close();
    });

    test('next/previous wrap around in both directions', () async {
      final bloc = buildBloc();

      bloc.add(const OcptEditorSearchOpenedEvent(withReplaceRow: false));
      bloc.add(const OcptEditorSearchMatchesReportedEvent(matchCount: 3));
      final firstState = await waitForState(bloc, (state) => state.matchCount == 3);
      expect(firstState.currentMatchIndex, 0);

      bloc.add(const OcptEditorSearchPreviousRequestedEvent());
      final wrappedBackState = await waitForState(bloc, (state) => state.currentMatchIndex == 2);
      expect(wrappedBackState.currentMatchIndex, 2);

      bloc.add(const OcptEditorSearchNextRequestedEvent());
      final nextState = await waitForState(bloc, (state) => state.currentMatchIndex == 0);
      expect(nextState.currentMatchIndex, 0);

      bloc.add(const OcptEditorSearchNextRequestedEvent());
      await waitForState(bloc, (state) => state.currentMatchIndex == 1);

      bloc.add(const OcptEditorSearchNextRequestedEvent());
      await waitForState(bloc, (state) => state.currentMatchIndex == 2);

      // One more step past the last index wraps back to the first.
      bloc.add(const OcptEditorSearchNextRequestedEvent());
      final wrappedToStartState = await waitForState(bloc, (state) => state.currentMatchIndex == 0);
      expect(wrappedToStartState.currentMatchIndex, 0);

      await bloc.close();
    });

    test('next/previous are a no-op while there is no match', () async {
      final bloc = buildBloc();

      bloc.add(const OcptEditorSearchOpenedEvent(withReplaceRow: false));
      await waitForState(bloc, (state) => state.isOpen);

      bloc.add(const OcptEditorSearchNextRequestedEvent());
      // No state change to wait for: give the handler a beat to run, then assert nothing moved.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(bloc.state.currentMatchIndex, isNull);

      await bloc.close();
    });

    test('the case-sensitivity and whole-word toggles flip their own flag only', () async {
      final bloc = buildBloc();

      bloc.add(const OcptEditorSearchCaseSensitivityToggledEvent());
      final caseState = await waitForState(bloc, (state) => state.isCaseSensitive);
      expect(caseState.isWholeWord, isFalse);

      bloc.add(const OcptEditorSearchWholeWordToggledEvent());
      final wholeWordState = await waitForState(bloc, (state) => state.isWholeWord);
      expect(wholeWordState.isCaseSensitive, isTrue);

      await bloc.close();
    });

    test(
      'a current-match-selected event sets the index directly, not relative to the previous one',
      () async {
        final bloc = buildBloc();

        bloc.add(const OcptEditorSearchOpenedEvent(withReplaceRow: false));
        bloc.add(const OcptEditorSearchMatchesReportedEvent(matchCount: 5));
        await waitForState(bloc, (state) => state.matchCount == 5);

        // Sets the index straight to 3, with no relationship to the current one (0): the event
        // exists precisely because the mounted surface, not the bloc, knows which match a replace
        // just landed on.
        bloc.add(const OcptEditorSearchCurrentMatchSelectedEvent(index: 3));
        final state = await waitForState(bloc, (state) => state.currentMatchIndex == 3);

        expect(state.currentMatchIndex, 3);

        // The report that follows a replace (a fresh match count) still clamps it, exactly as
        // any other match count report does.
        bloc.add(const OcptEditorSearchMatchesReportedEvent(matchCount: 2));
        final clampedState = await waitForState(bloc, (state) => state.matchCount == 2);
        expect(clampedState.currentMatchIndex, 1);

        await bloc.close();
      },
    );
  });

  group('the bloc as a view of the mode', () {
    /// Names every event of the hierarchy by an exhaustive switch, so an event added to it does not
    /// compile until this list, and the test below, know it.
    String nameOf(OcptEditorSearchEvent event) => switch (event) {
      OcptEditorSearchOpenedEvent() => "opened",
      OcptEditorSearchClosedEvent() => "closed",
      OcptEditorSearchReplaceRowToggledEvent() => "replace row",
      OcptEditorSearchQueryChangedEvent() => "query",
      OcptEditorSearchReplacementChangedEvent() => "replacement",
      OcptEditorSearchCaseSensitivityToggledEvent() => "case",
      OcptEditorSearchWholeWordToggledEvent() => "whole word",
      OcptEditorSearchMatchesReportedEvent() => "matches",
      OcptEditorSearchNextRequestedEvent() => "next",
      OcptEditorSearchPreviousRequestedEvent() => "previous",
      OcptEditorSearchCurrentMatchSelectedEvent() => "selected",
    };

    test('every event of its hierarchy has a handler', () async {
      final bloc = buildBloc();

      const events = <OcptEditorSearchEvent>[
        OcptEditorSearchOpenedEvent(withReplaceRow: false),
        OcptEditorSearchClosedEvent(),
        OcptEditorSearchReplaceRowToggledEvent(),
        OcptEditorSearchQueryChangedEvent(query: "ab"),
        OcptEditorSearchReplacementChangedEvent(replacement: "cd"),
        OcptEditorSearchCaseSensitivityToggledEvent(),
        OcptEditorSearchWholeWordToggledEvent(),
        OcptEditorSearchMatchesReportedEvent(matchCount: 3),
        OcptEditorSearchNextRequestedEvent(),
        OcptEditorSearchPreviousRequestedEvent(),
        OcptEditorSearchCurrentMatchSelectedEvent(index: 2),
      ];
      expect(events.map(nameOf).toSet(), hasLength(11), reason: "one event per name");

      // An event nobody handles is ignored silently, so each is proven by its effect.
      bloc.add(events[0]);
      await waitForState(bloc, (state) => state.isOpen);
      bloc.add(events[2]);
      await waitForState(bloc, (state) => state.isReplaceRowOpen);
      bloc.add(events[3]);
      await waitForState(bloc, (state) => state.query == "ab");
      bloc.add(events[4]);
      await waitForState(bloc, (state) => state.replacement == "cd");
      bloc.add(events[5]);
      await waitForState(bloc, (state) => state.isCaseSensitive);
      bloc.add(events[6]);
      await waitForState(bloc, (state) => state.isWholeWord);
      bloc.add(events[7]);
      await waitForState(bloc, (state) => state.matchCount == 3);
      bloc.add(events[8]);
      await waitForState(bloc, (state) => state.currentMatchIndex == 1);
      bloc.add(events[9]);
      await waitForState(bloc, (state) => state.currentMatchIndex == 0);
      bloc.add(events[10]);
      await waitForState(bloc, (state) => state.currentMatchIndex == 2);
      bloc.add(events[1]);
      await waitForState(bloc, (state) => !state.isOpen);

      await bloc.close();
    });

    test('is registered with the mode as a flusher, without any widget having read it', () async {
      final bloc = buildBloc();

      expect(bloc.modeBloc.pendingWritesFlusherCount, 1);

      await bloc.close();
    });
  });
}
