// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/sync/ocpt_sync_manager.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_changeset_service.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_presence_frame.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_presence_roster.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_presence_indicator.dart';

/// An [OcptSyncManager] whose [presenceRoster]/[presenceRosterChanges] are fully under this file's
/// own control — never a real presence service — so a test seeds the widget's first frame through
/// the getter (mirroring `OcptPresenceService.roster`'s own contract) and then drives further
/// frames through [emit], mirroring `presenceRosterChanges` (the lifecycle-spanning stream the
/// indicator listens to).
class _FakePresenceSyncManager extends OcptSyncManager {
  _FakePresenceSyncManager(this.roster) : super(changesetService: const OcptChangesetService());

  /// What [presenceRoster] returns — the seed a fresh listener reads before the stream ever emits.
  OcptPresenceRoster? roster;

  final _controller = StreamController<OcptPresenceRoster?>.broadcast();

  @override
  OcptPresenceRoster? get presenceRoster => roster;

  @override
  Stream<OcptPresenceRoster?> get presenceRosterChanges => _controller.stream;

  /// Pushes [next] onto [presenceRosterChanges], as a presence service starting or a heartbeat run
  /// would; a null is the session stopping.
  void emit(OcptPresenceRoster? next) {
    roster = next;
    _controller.add(next);
  }

  Future<void> disposeStream() => _controller.close();
}

/// Builds a frame for [deviceId] on [platform], optionally with [modeKey], every heartbeat kept at
/// `0` since none of these tests care about it.
OcptPresenceFrame _frame({required String deviceId, required String platform, String? modeKey}) =>
    OcptPresenceFrame(deviceId: deviceId, platform: platform, modeKey: modeKey, heartbeat: 0);

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
    await tester.pump();
  }

  testWidgets("renders nothing when no sync manager is registered", (tester) async {
    await pumpIndicator(tester, const OcptPresenceIndicator());

    expect(find.byType(OcptPresenceIndicator), findsOneWidget);
    expect(
      tester.getSize(find.byType(OcptPresenceIndicator)),
      Size.zero,
      reason: "a SizedBox.shrink() takes no space at all",
    );
  });

  testWidgets("renders nothing while the presence roster is null (an unpaired project)", (
    tester,
  ) async {
    final syncManager = _FakePresenceSyncManager(null);
    addTearDown(syncManager.disposeStream);

    await pumpIndicator(tester, OcptPresenceIndicator(syncManager: syncManager));

    expect(find.byType(OcptPresenceIndicator), findsOneWidget);
    expect(tester.getSize(find.byType(OcptPresenceIndicator)), Size.zero);
  });

  testWidgets("a single-self roster shows one ringed avatar", (tester) async {
    final self = _frame(deviceId: "self-device", platform: "windows");
    final syncManager = _FakePresenceSyncManager(
      OcptPresenceRoster(participants: [self], selfDeviceId: self.deviceId),
    );
    addTearDown(syncManager.disposeStream);

    await pumpIndicator(tester, OcptPresenceIndicator(syncManager: syncManager));

    expect(find.text("W"), findsOneWidget);

    final decoratedBoxes = tester
        .widgetList<Container>(find.byType(Container))
        .where((container) => container.decoration is BoxDecoration)
        .map((container) => container.decoration! as BoxDecoration)
        .where((decoration) => decoration.shape == BoxShape.circle);
    final context = tester.element(find.byType(OcptPresenceIndicator));
    final accent = Theme.of(context).colorScheme.primary;

    expect(
      decoratedBoxes.any((decoration) => decoration.border?.top.color == accent),
      isTrue,
      reason: "the self avatar carries a ring in the app's own accent colour",
    );
  });

  testWidgets("three participants show three avatars and no overflow disc", (tester) async {
    final self = _frame(deviceId: "self-device", platform: "windows");
    final peerA = _frame(deviceId: "peer-a", platform: "macos");
    final peerB = _frame(deviceId: "peer-b", platform: "linux");
    final syncManager = _FakePresenceSyncManager(
      OcptPresenceRoster(participants: [self, peerA, peerB], selfDeviceId: self.deviceId),
    );
    addTearDown(syncManager.disposeStream);

    await pumpIndicator(tester, OcptPresenceIndicator(syncManager: syncManager));

    expect(find.text("W"), findsOneWidget);
    expect(find.text("M"), findsOneWidget);
    expect(find.text("L"), findsOneWidget);
    expect(find.textContaining("+"), findsNothing);
  });

  testWidgets("four or more participants fold the rest into a +N disc", (tester) async {
    final self = _frame(deviceId: "self-device", platform: "windows");
    final peerA = _frame(deviceId: "peer-a", platform: "macos");
    final peerB = _frame(deviceId: "peer-b", platform: "linux");
    final peerC = _frame(deviceId: "peer-c", platform: "android");
    final syncManager = _FakePresenceSyncManager(
      OcptPresenceRoster(
        participants: [self, peerA, peerB, peerC],
        selfDeviceId: self.deviceId,
      ),
    );
    addTearDown(syncManager.disposeStream);

    await pumpIndicator(tester, OcptPresenceIndicator(syncManager: syncManager));

    expect(find.text("W"), findsOneWidget);
    expect(find.text("M"), findsOneWidget);
    expect(find.text("L"), findsOneWidget);
    expect(find.text("A"), findsNothing, reason: "the fourth peer folds into the +N disc instead");
    expect(find.text("+1"), findsOneWidget);
  });

  testWidgets("self sorts first and carries the Vous badge in the popover", (tester) async {
    final self = _frame(deviceId: "self-device", platform: "windows");
    final peer = _frame(deviceId: "peer-a", platform: "macos");
    final syncManager = _FakePresenceSyncManager(
      OcptPresenceRoster(participants: [self, peer], selfDeviceId: self.deviceId),
    );
    addTearDown(syncManager.disposeStream);

    await pumpIndicator(tester, OcptPresenceIndicator(syncManager: syncManager));
    final tr = Tr.of(tester.element(find.byType(OcptPresenceIndicator)));

    await tester.tap(find.byType(OcptPresenceIndicator));
    await tester.pump();

    expect(find.text(tr.workspacePresenceSelfBadge), findsOneWidget);

    final firstRowLabel = tester.getTopLeft(find.textContaining("Windows ·"));
    final secondRowLabel = tester.getTopLeft(find.textContaining("Macos ·"));
    expect(
      firstRowLabel.dy,
      lessThan(secondRowLabel.dy),
      reason: "self is the roster's own first participant, so its row sits above the peer's",
    );
  });

  testWidgets("the popover lists a header, the online count and each participant's mode", (
    tester,
  ) async {
    final self = _frame(deviceId: "self-device", platform: "windows", modeKey: "screenplay");
    final peer = _frame(deviceId: "peer-a", platform: "macos", modeKey: "budget");
    final syncManager = _FakePresenceSyncManager(
      OcptPresenceRoster(participants: [self, peer], selfDeviceId: self.deviceId),
    );
    addTearDown(syncManager.disposeStream);

    await pumpIndicator(tester, OcptPresenceIndicator(syncManager: syncManager));
    final tr = Tr.of(tester.element(find.byType(OcptPresenceIndicator)));

    await tester.tap(find.byType(OcptPresenceIndicator));
    await tester.pump();

    expect(find.text(tr.workspacePresencePopoverHeader), findsOneWidget);
    expect(find.text(tr.workspacePresenceOnlineCount(2)), findsOneWidget);
    expect(find.textContaining("Windows ·"), findsOneWidget);
    expect(find.textContaining("Macos ·"), findsOneWidget);
    expect(find.text(tr.workspaceModeScreenplay), findsOneWidget);
    expect(find.text(tr.workspaceModeBudget), findsOneWidget);
  });

  testWidgets("an unknown or absent modeKey shows no mode label for that row, and never throws", (
    tester,
  ) async {
    final self = _frame(deviceId: "self-device", platform: "windows");
    final peer = _frame(deviceId: "peer-a", platform: "macos", modeKey: "not-a-real-mode");
    final syncManager = _FakePresenceSyncManager(
      OcptPresenceRoster(participants: [self, peer], selfDeviceId: self.deviceId),
    );
    addTearDown(syncManager.disposeStream);

    await pumpIndicator(tester, OcptPresenceIndicator(syncManager: syncManager));
    final tr = Tr.of(tester.element(find.byType(OcptPresenceIndicator)));

    await tester.tap(find.byType(OcptPresenceIndicator));
    await tester.pump();

    expect(find.textContaining("Windows ·"), findsOneWidget);
    expect(find.textContaining("Macos ·"), findsOneWidget);
    for (final label in [
      tr.workspaceModeScreenplay,
      tr.workspaceModeBreakdown,
      tr.workspaceModeShotList,
      tr.workspaceModeResources,
      tr.workspaceModeSchedule,
      tr.workspaceModeBudget,
    ]) {
      expect(find.text(label), findsNothing);
    }
  });

  testWidgets("a presenceRosterStream emission redraws the cluster", (tester) async {
    final self = _frame(deviceId: "self-device", platform: "windows");
    final syncManager = _FakePresenceSyncManager(
      OcptPresenceRoster(participants: [self], selfDeviceId: self.deviceId),
    );
    addTearDown(syncManager.disposeStream);

    await pumpIndicator(tester, OcptPresenceIndicator(syncManager: syncManager));
    expect(find.text("W"), findsOneWidget);
    expect(find.text("M"), findsNothing);

    final peer = _frame(deviceId: "peer-a", platform: "macos");
    syncManager.emit(
      OcptPresenceRoster(participants: [self, peer], selfDeviceId: self.deviceId),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text("W"), findsOneWidget);
    expect(find.text("M"), findsOneWidget);
  });
}
