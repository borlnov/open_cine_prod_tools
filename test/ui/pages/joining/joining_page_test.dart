// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:typed_data';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:act_global_manager/act_global_manager.dart';
import 'package:act_platform_manager/act_platform_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/sync/ocpt_sync_manager.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_changeset_service.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_relay_invite.dart';
import 'package:open_cine_prod_tools/types/ocpt_route.dart';
import 'package:open_cine_prod_tools/ui/pages/joining/joining_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/joining/joining_page.dart';
import 'package:open_cine_prod_tools/ui/pages/joining/joining_state.dart';
import 'package:open_cine_prod_tools/ui/pages/joining/widgets/ocpt_joining_manual_view.dart';
import 'package:open_cine_prod_tools/ui/pages/joining/widgets/ocpt_joining_scanner_view.dart';
import 'package:open_cine_prod_tools/ui/pages/joining/widgets/ocpt_joining_status_overlay.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// Wraps [child] with the app theme and the localization delegates so `Tr.of` lookups resolve in
/// tests, exactly as `sharing_page_test.dart` already does.
Widget _wrapWithLocalization(Widget child) => MaterialApp(
  theme: ocptTheme.lightThemeData,
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: child,
);

/// A file saver manager that never actually shows a dialog — nothing in these tests presses the
/// "Rejoindre" button, but building an [OcptJoiningBloc] still needs one handed in explicitly
/// (`home_bloc_test.dart`'s own `_FakeFileSaverManager`), sidestepping the real one's
/// `globalGetIt()` lookup.
class _FakeFileSaverManager extends FileSaverManager {
  @override
  Future<String?> saveFileFromBytes({required String fileName, required Uint8List bytes}) async =>
      null;
}

/// An [OcptJoiningBloc] whose own protected `emit` is exposed as [pushTestState] — used to drive
/// `OcptJoiningView` straight to a chosen [OcptJoiningState] with no real join (and no camera)
/// involved at all, exactly what the blocking overlay's own tests need to reach the busy and
/// success states without wiring up the whole relay/snapshot machinery `joining_bloc_test.dart`
/// already covers on its own.
class _TestableJoiningBloc extends OcptJoiningBloc {
  _TestableJoiningBloc({
    required super.syncManager,
    required super.projectsManager,
    required super.routerManager,
    required super.fileSaverManager,
  });

  /// Pushes [state] directly onto the bloc's own stream, bypassing every event handler.
  void pushTestState(OcptJoiningState state) => emit(state);
}

/// A router manager whose [replace] only records the route it was called with — this page's own
/// tests don't build a real GoRouter for it to operate on, exactly `joining_bloc_test.dart`'s own
/// `_RecordingRouterManager`.
class _RecordingRouterManager extends OcptRouterManager {
  /// The last route [replace] was called with, or null if it never was.
  OcptRoute? replacedRoute;

  @override
  Future<Y?> replace<Y extends Object?>(
    OcptRoute route, {
    Map<String, String> pathParameters = const <String, String>{},
    Map<String, dynamic> queryParameters = const <String, dynamic>{},
    Object? extra,
  }) async {
    replacedRoute = route;
    return null;
  }
}

void main() {
  late OcptPropertiesManager propertiesManager;

  setUpAll(() async {
    // OcptGlobalManager and OcptPropertiesManager both log through appLogger(), which requires a
    // global manager instance to be set; merely accessing it creates the (otherwise unused)
    // singleton, exactly as `sharing_page_test.dart` does.
    OcptGlobalManager.instance;

    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();
  });

  setUp(() async {
    await propertiesManager.deleteAll();

    final managers = globalGetIt();
    if (managers.isRegistered<OcptRouterManager>()) {
      await managers.unregister<OcptRouterManager>();
    }
    managers.registerSingleton<OcptRouterManager>(OcptRouterManager());

    // `OcptJoiningView` reads this directly (not through the bloc) to pick its default tab and to
    // gate the real camera scanner off desktop — registered here as a plain desktop instance,
    // exactly as every other export/platform-gated test of this app leaves it: never mobile.
    if (managers.isRegistered<PlatformManager>()) {
      await managers.unregister<PlatformManager>();
    }
    managers.registerSingleton<PlatformManager>(PlatformManager());
  });

  /// Pumps [OcptJoiningView] backed by a bare [OcptJoiningBloc] — nothing here ever dispatches an
  /// event that would reach [OcptSyncManager]/[OcptProjectsManager], so both are built with the
  /// lightest possible wiring, exactly like their own "no `globalGetIt()` needed at all" test
  /// constructions.
  Future<void> pumpView(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final bloc = OcptJoiningBloc(
      syncManager: OcptSyncManager(changesetService: const OcptChangesetService()),
      projectsManager: OcptProjectsManager(propertiesManager: propertiesManager, appLanguageCode: () => "en"),
      routerManager: OcptRouterManager(),
      fileSaverManager: _FakeFileSaverManager(),
    );
    addTearDown(bloc.close);

    await tester.pumpWidget(
      _wrapWithLocalization(
        BlocProvider<OcptJoiningBloc>.value(value: bloc, child: const OcptJoiningView()),
      ),
    );
    // Bounded pumps rather than `pumpAndSettle()`: the segmented control and the manual form
    // animate in on first build, and the busy state (not reached by these tests) would otherwise
    // draw an indeterminate spinner that keeps scheduling frames forever
    // (`compact-breakpoint-vs-default-test-surface`'s own sibling pitfall).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets("renders the manual entry tab by default, with no overflow, on desktop", (
    tester,
  ) async {
    await pumpView(tester);

    expect(find.byType(OcptJoiningManualView), findsOneWidget);
    expect(find.byType(OcptJoiningScannerView), findsNothing);
    expect(tester.takeException(), isNull);

    final tr = Tr.of(tester.element(find.byType(OcptJoiningView)));
    expect(find.text(tr.joiningPageTitle), findsOneWidget);
    expect(find.text(tr.joiningTabScanner), findsOneWidget);
    expect(find.text(tr.joiningTabManual), findsOneWidget);
    expect(find.text(tr.joiningManualCardTitle), findsOneWidget);
    expect(find.text(tr.joiningInviteLinkHelperText), findsOneWidget);
    expect(find.text(tr.joiningJoinAction), findsOneWidget);
  });

  testWidgets("pasting an invite link and pressing Join submits it, with no overflow", (
    tester,
  ) async {
    await pumpView(tester);

    final tr = Tr.of(tester.element(find.byType(OcptJoiningView)));
    final inviteLink = OcptRelayInvite(
      relayBaseUri: Uri.parse("https://relay.example.org/"),
      projectId: "project-abc",
      token: "token-1",
    ).toInviteString();

    await tester.enterText(find.byType(TextField), inviteLink);
    await tester.tap(find.text(tr.joiningJoinAction));
    // A bounded pump only: `_FakeFileSaverManager.saveFileFromBytes` resolves to null (a
    // cancelled destination picker), which `OcptJoiningBloc._join` treats as a silent no-op —
    // exactly `joining_bloc_test.dart`'s own "a cancelled desktop destination picker" case — so
    // there is no busy state or snack bar left to settle here.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(tester.takeException(), isNull);
  });

  testWidgets("switching to the scanner tab shows the camera-unavailable card on desktop", (
    tester,
  ) async {
    await pumpView(tester);

    final tr = Tr.of(tester.element(find.byType(OcptJoiningView)));
    await tester.tap(find.text(tr.joiningTabScanner));
    await tester.pump();

    expect(find.byType(OcptJoiningScannerView), findsNothing);
    expect(find.byType(OcptJoiningManualView), findsNothing);
    expect(find.text(tr.joiningScannerUnavailableTitle), findsOneWidget);
    expect(find.text(tr.joiningScannerUnavailableMessage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets("the blocking overlay shows while joining and Annuler cancels it", (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final bloc = _TestableJoiningBloc(
      syncManager: OcptSyncManager(changesetService: const OcptChangesetService()),
      projectsManager: OcptProjectsManager(propertiesManager: propertiesManager, appLanguageCode: () => "en"),
      routerManager: OcptRouterManager(),
      fileSaverManager: _FakeFileSaverManager(),
    );
    addTearDown(bloc.close);

    await tester.pumpWidget(
      _wrapWithLocalization(
        BlocProvider<OcptJoiningBloc>.value(value: bloc, child: const OcptJoiningView()),
      ),
    );
    await tester.pump();

    bloc.pushTestState(
      const OcptJoiningState(isJoining: true, joinFailed: false, joinStep: OcptJoinStep.downloading),
    );
    // Two pumps: `pushTestState` calls `Bloc.emit` directly (bypassing any event handler's own
    // await chain), so the stream's async delivery to `BlocConsumer`'s subscription needs one pump
    // to flush before the resulting `setState` is itself picked up by a second.
    await tester.pump();
    await tester.pump();

    final tr = Tr.of(tester.element(find.byType(OcptJoiningView)));
    expect(find.byType(OcptJoiningStatusOverlay), findsOneWidget);
    expect(find.text(tr.joiningStepDownloading), findsOneWidget);
    expect(find.text(tr.joiningCancelAction), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text(tr.joiningCancelAction));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(bloc.state.isJoining, isFalse);
    expect(find.text(tr.joiningCancelAction), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets("the success state shows Ouvrir, which replaces the workspace", (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final routerManager = _RecordingRouterManager();
    final bloc = _TestableJoiningBloc(
      syncManager: OcptSyncManager(changesetService: const OcptChangesetService()),
      projectsManager: OcptProjectsManager(propertiesManager: propertiesManager, appLanguageCode: () => "en"),
      routerManager: routerManager,
      fileSaverManager: _FakeFileSaverManager(),
    );
    addTearDown(bloc.close);

    await tester.pumpWidget(
      _wrapWithLocalization(
        BlocProvider<OcptJoiningBloc>.value(value: bloc, child: const OcptJoiningView()),
      ),
    );
    await tester.pump();

    bloc.pushTestState(const OcptJoiningState(isJoining: false, joinFailed: false, joinSucceeded: true));
    // See the sibling "blocking overlay" test's own comment for why this needs two pumps.
    await tester.pump();
    await tester.pump();

    final tr = Tr.of(tester.element(find.byType(OcptJoiningView)));
    expect(find.text(tr.joiningSuccessTitle), findsOneWidget);
    expect(find.text(tr.joiningOpenAction), findsOneWidget);
    expect(routerManager.replacedRoute, isNull);

    await tester.tap(find.text(tr.joiningOpenAction));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(routerManager.replacedRoute, OcptRoute.workspace);
    expect(tester.takeException(), isNull);
  });
}
