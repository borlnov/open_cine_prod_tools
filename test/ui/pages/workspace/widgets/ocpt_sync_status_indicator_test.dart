// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/sync/ocpt_sync_manager.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_changeset_service.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_sync_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_route.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_sync_status_indicator.dart';

/// An [OcptSyncManager] whose [syncStatus]/[syncStatusChanges] are fully under this file's own
/// control — never a real session, never any network — so a test seeds the widget's first frame
/// through the getter (mirroring `OcptSyncSession.status`'s own contract) and then drives further
/// frames through [emit], mirroring `syncStatusChanges` (the lifecycle-spanning stream the
/// indicator listens to).
class _FakeSyncManager extends OcptSyncManager {
  _FakeSyncManager(this.status) : super(changesetService: const OcptChangesetService());

  /// What [syncStatus] returns — the seed a fresh listener reads before the stream ever emits.
  OcptSyncStatus? status;

  final _controller = StreamController<OcptSyncStatus?>.broadcast();

  /// Every call `syncNow()` recorded, oldest first.
  int syncNowCallCount = 0;

  @override
  OcptSyncStatus? get syncStatus => status;

  @override
  Stream<OcptSyncStatus?> get syncStatusChanges => _controller.stream;

  /// Pushes [next] onto [syncStatusChanges], as a session starting or a run would; a null is a
  /// session stopping.
  void emit(OcptSyncStatus? next) {
    status = next;
    _controller.add(next);
  }

  @override
  Future<void> syncNow() async {
    syncNowCallCount++;
  }

  Future<void> disposeStream() => _controller.close();
}

/// An [OcptRouterManager] recording the last route [push] was asked to navigate to, instead of
/// driving a real `GoRouter` — mirrors `resources_mode_test.dart`'s own `_RecordingRouterManager`.
class _RecordingRouterManager extends OcptRouterManager {
  OcptRoute? pushedRoute;

  @override
  Future<Y?> push<Y extends Object?>(
    OcptRoute route, {
    Map<String, String> pathParameters = const <String, String>{},
    Map<String, dynamic> queryParameters = const <String, dynamic>{},
    Object? extra,
  }) async {
    pushedRoute = route;
    return null;
  }
}

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: Align(alignment: Alignment.topLeft, child: child)),
);

void main() {
  /// Widens the test surface well past the default 800px (`compact-breakpoint-vs-default-test
  /// -surface.md`'s own pitfall) and pumps [indicator].
  Future<void> pumpIndicator(WidgetTester tester, Widget indicator) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrap(indicator));
    // Bounded: `pumpAndSettle()` spins forever on the syncing state's own indeterminate spinner.
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets("renders nothing while no sync session is running (an unpaired project)", (
    tester,
  ) async {
    final syncManager = _FakeSyncManager(null);
    addTearDown(syncManager.disposeStream);

    await pumpIndicator(tester, OcptSyncStatusIndicator(syncManager: syncManager));

    expect(find.byType(OcptSyncStatusIndicator), findsOneWidget);
    expect(
      tester.getSize(find.byType(OcptSyncStatusIndicator)),
      Size.zero,
      reason: "a SizedBox.shrink() takes no space at all",
    );
  });

  testWidgets("seeds its first frame from the syncStatus getter: in sync", (tester) async {
    final syncManager = _FakeSyncManager(const OcptSyncStatusInSync());
    addTearDown(syncManager.disposeStream);

    await pumpIndicator(tester, OcptSyncStatusIndicator(syncManager: syncManager));

    final tr = Tr.of(tester.element(find.byType(OcptSyncStatusIndicator)));
    expect(find.text(tr.workspaceSyncStatusInSync), findsOneWidget);
  });

  testWidgets("seeds its first frame from the syncStatus getter: syncing", (tester) async {
    final syncManager = _FakeSyncManager(const OcptSyncStatusSyncing());
    addTearDown(syncManager.disposeStream);

    await pumpIndicator(tester, OcptSyncStatusIndicator(syncManager: syncManager));

    final tr = Tr.of(tester.element(find.byType(OcptSyncStatusIndicator)));
    expect(find.text(tr.workspaceSyncStatusSyncing), findsOneWidget);
  });

  testWidgets("seeds its first frame from the syncStatus getter: offline with a pending count", (
    tester,
  ) async {
    final syncManager = _FakeSyncManager(const OcptSyncStatusOffline(pendingEditCount: 3));
    addTearDown(syncManager.disposeStream);

    await pumpIndicator(tester, OcptSyncStatusIndicator(syncManager: syncManager));

    final tr = Tr.of(tester.element(find.byType(OcptSyncStatusIndicator)));
    expect(find.text(tr.workspaceSyncStatusOfflinePending(3)), findsOneWidget);
  });

  testWidgets("seeds its first frame from the syncStatus getter: a relay error", (tester) async {
    final syncManager = _FakeSyncManager(const OcptSyncStatusError("bad token"));
    addTearDown(syncManager.disposeStream);

    await pumpIndicator(tester, OcptSyncStatusIndicator(syncManager: syncManager));

    final tr = Tr.of(tester.element(find.byType(OcptSyncStatusIndicator)));
    expect(find.text(tr.workspaceSyncStatusError), findsOneWidget);
  });

  testWidgets("a syncStatusStream emission moves the badge to the new state", (tester) async {
    final syncManager = _FakeSyncManager(const OcptSyncStatusInSync());
    addTearDown(syncManager.disposeStream);

    await pumpIndicator(tester, OcptSyncStatusIndicator(syncManager: syncManager));
    final tr = Tr.of(tester.element(find.byType(OcptSyncStatusIndicator)));
    expect(find.text(tr.workspaceSyncStatusInSync), findsOneWidget);

    syncManager.emit(const OcptSyncStatusOffline(pendingEditCount: 1));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text(tr.workspaceSyncStatusInSync), findsNothing);
    expect(find.text(tr.workspaceSyncStatusOfflinePending(1)), findsOneWidget);
  });

  testWidgets("appears when a session starts after the indicator was built, and hides when it "
      "stops", (tester) async {
    // The real ordering: the workspace builds this indicator, then opens a paired project which
    // starts the session moments later. The badge has to appear on that later status, not stay
    // blank because there was no session to read at build time.
    final syncManager = _FakeSyncManager(null);
    addTearDown(syncManager.disposeStream);

    await pumpIndicator(tester, OcptSyncStatusIndicator(syncManager: syncManager));
    expect(
      tester.getSize(find.byType(OcptSyncStatusIndicator)),
      Size.zero,
      reason: "nothing to show until the session starts",
    );

    syncManager.emit(const OcptSyncStatusInSync());
    await tester.pump(const Duration(milliseconds: 50));
    final tr = Tr.of(tester.element(find.byType(OcptSyncStatusIndicator)));
    expect(find.text(tr.workspaceSyncStatusInSync), findsOneWidget);

    // The session stopping closes the manager-level stream out with a null; the badge goes away.
    syncManager.emit(null);
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text(tr.workspaceSyncStatusInSync), findsNothing);
    expect(tester.getSize(find.byType(OcptSyncStatusIndicator)), Size.zero);
  });

  testWidgets("a tap opens the panel, and Synchroniser maintenant calls syncNow", (tester) async {
    final syncManager = _FakeSyncManager(const OcptSyncStatusInSync());
    addTearDown(syncManager.disposeStream);

    await pumpIndicator(tester, OcptSyncStatusIndicator(syncManager: syncManager));
    final tr = Tr.of(tester.element(find.byType(OcptSyncStatusIndicator)));

    await tester.tap(find.byType(OcptSyncStatusIndicator));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text(tr.workspaceSyncActionSyncNow), findsOneWidget);
    expect(find.text(tr.workspaceSyncActionShowQr), findsOneWidget);
    expect(find.text(tr.workspaceSyncActionRepair), findsOneWidget);

    await tester.tap(find.text(tr.workspaceSyncActionSyncNow));
    await tester.pump(const Duration(milliseconds: 50));

    expect(syncManager.syncNowCallCount, 1);
  });

  testWidgets(
    "Afficher le QR d'invitation and Ré-appairer… both navigate to the Partager route",
    (tester) async {
      final syncManager = _FakeSyncManager(const OcptSyncStatusInSync());
      addTearDown(syncManager.disposeStream);
      final router = _RecordingRouterManager();

      await pumpIndicator(
        tester,
        OcptSyncStatusIndicator(syncManager: syncManager, routerManager: router),
      );
      final tr = Tr.of(tester.element(find.byType(OcptSyncStatusIndicator)));

      await tester.tap(find.byType(OcptSyncStatusIndicator));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text(tr.workspaceSyncActionShowQr));
      await tester.pump(const Duration(milliseconds: 50));

      expect(router.pushedRoute, OcptRoute.sharing);

      router.pushedRoute = null;
      await tester.tap(find.byType(OcptSyncStatusIndicator));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text(tr.workspaceSyncActionRepair));
      await tester.pump(const Duration(milliseconds: 50));

      expect(router.pushedRoute, OcptRoute.sharing);
    },
  );

  testWidgets("Changer de relais… navigates to the repointing route", (tester) async {
    final syncManager = _FakeSyncManager(const OcptSyncStatusInSync());
    addTearDown(syncManager.disposeStream);
    final router = _RecordingRouterManager();

    await pumpIndicator(
      tester,
      OcptSyncStatusIndicator(syncManager: syncManager, routerManager: router),
    );
    final tr = Tr.of(tester.element(find.byType(OcptSyncStatusIndicator)));

    await tester.tap(find.byType(OcptSyncStatusIndicator));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text(tr.workspaceSyncActionSwitchRelay), findsOneWidget);

    await tester.tap(find.text(tr.workspaceSyncActionSwitchRelay));
    await tester.pump(const Duration(milliseconds: 50));

    expect(router.pushedRoute, OcptRoute.repointing);
  });

  testWidgets("under a read-only preview every action is withheld (a null callback)", (
    tester,
  ) async {
    final syncManager = _FakeSyncManager(const OcptSyncStatusInSync());
    addTearDown(syncManager.disposeStream);
    final router = _RecordingRouterManager();

    await pumpIndicator(
      tester,
      OcptSyncStatusIndicator(syncManager: syncManager, routerManager: router, isReadOnly: true),
    );
    final tr = Tr.of(tester.element(find.byType(OcptSyncStatusIndicator)));

    await tester.tap(find.byType(OcptSyncStatusIndicator));
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.text(tr.workspaceSyncActionSyncNow));
    await tester.pump(const Duration(milliseconds: 50));

    expect(syncManager.syncNowCallCount, 0);

    // The menu stays open across both taps above (neither action has a callback to close it on),
    // so `Changer de relais…` is reached from the very same open panel, with no need to reopen it.
    await tester.tap(find.text(tr.workspaceSyncActionSwitchRelay));
    await tester.pump(const Duration(milliseconds: 50));

    expect(router.pushedRoute, isNull);
  });
}
