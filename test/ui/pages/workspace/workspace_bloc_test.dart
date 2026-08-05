// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_workspace_reveal_request.dart';
import 'package:open_cine_prod_tools/types/ocpt_resources_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_workspace_mode.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/workspace_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/workspace_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/workspace_state.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  late OcptPropertiesManager propertiesManager;

  setUpAll(() async {
    OcptGlobalManager.instance;

    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();
  });

  setUp(() async {
    await propertiesManager.deleteAll();
  });

  /// Builds a bloc wired to the test properties manager.
  OcptWorkspaceBloc buildBloc() => OcptWorkspaceBloc(propertiesManager: propertiesManager);

  /// Waits for the first state of [bloc] matching [predicate] (the current one included).
  Future<OcptWorkspaceState> waitForState(
    OcptWorkspaceBloc bloc,
    bool Function(OcptWorkspaceState state) predicate,
  ) async {
    if (predicate(bloc.state)) {
      return bloc.state;
    }

    return bloc.stream.firstWhere(predicate).timeout(const Duration(seconds: 5));
  }

  test('defaults to the screenplay mode when nothing was ever persisted', () async {
    final bloc = buildBloc();

    final state = await waitForState(bloc, (state) => !state.isLoading);

    expect(state.mode, OcptWorkspaceMode.screenplay);
    await bloc.close();
  });

  test('loads the persisted workspace mode on entry', () async {
    await propertiesManager.workspaceMode.store(OcptWorkspaceMode.budget);
    final bloc = buildBloc();

    final state = await waitForState(bloc, (state) => !state.isLoading);

    expect(state.mode, OcptWorkspaceMode.budget);
    await bloc.close();
  });

  test('selecting a mode emits it and persists it', () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptWorkspaceModeSelectedEvent(mode: OcptWorkspaceMode.schedule));
    final state = await waitForState(bloc, (state) => state.mode == OcptWorkspaceMode.schedule);

    expect(state.mode, OcptWorkspaceMode.schedule);
    expect(await propertiesManager.workspaceMode.load(), OcptWorkspaceMode.schedule);
    await bloc.close();
  });

  test('selecting a mode carries the reveal request it was given', () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(
      const OcptWorkspaceModeSelectedEvent(
        mode: OcptWorkspaceMode.resources,
        revealRequest: OcptResourcesRevealRequest(
          tab: OcptResourcesTab.elements,
          recordId: "element-1",
        ),
      ),
    );
    final state = await waitForState(bloc, (state) => state.revealRequest != null);

    expect(state.mode, OcptWorkspaceMode.resources);
    expect(
      state.revealRequest,
      const OcptResourcesRevealRequest(tab: OcptResourcesTab.elements, recordId: "element-1"),
    );
    await bloc.close();
  });

  test('consuming the reveal request clears it without touching the mode', () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    bloc.add(
      const OcptWorkspaceModeSelectedEvent(
        mode: OcptWorkspaceMode.resources,
        revealRequest: OcptResourcesRevealRequest(tab: OcptResourcesTab.roles, recordId: "role-1"),
      ),
    );
    await waitForState(bloc, (state) => state.revealRequest != null);

    bloc.add(const OcptWorkspaceRevealRequestConsumedEvent());
    final state = await waitForState(bloc, (state) => state.revealRequest == null);

    expect(state.mode, OcptWorkspaceMode.resources);
    await bloc.close();
  });

  test('a plain mode switch clears a reveal request an earlier one left behind', () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    bloc.add(
      const OcptWorkspaceModeSelectedEvent(
        mode: OcptWorkspaceMode.resources,
        revealRequest: OcptResourcesRevealRequest(tab: OcptResourcesTab.roles, recordId: "role-1"),
      ),
    );
    await waitForState(bloc, (state) => state.revealRequest != null);

    bloc.add(const OcptWorkspaceModeSelectedEvent(mode: OcptWorkspaceMode.screenplay));
    final state = await waitForState(bloc, (state) => state.mode == OcptWorkspaceMode.screenplay);

    expect(state.revealRequest, isNull);
    await bloc.close();
  });
}
