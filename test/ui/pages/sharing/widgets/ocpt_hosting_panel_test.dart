// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_presence_frame.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_presence_roster.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_reconcile_outcome.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_relay_host_state.dart';
import 'package:open_cine_prod_tools/ui/pages/sharing/hosting_state.dart';
import 'package:open_cine_prod_tools/ui/pages/sharing/widgets/ocpt_hosting_panel.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_enrolment_qr_code.dart';

/// Wraps [child] with the app theme and the localization delegates so `Tr.of` lookups resolve,
/// exactly `sharing_page_test.dart`'s own `_wrapWithLocalization`.
Widget _wrap(Widget child) => MaterialApp(
  theme: ocptTheme.lightThemeData,
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  final onlineHostState = OcptRelayHostOnline(
    lanBaseUri: Uri.parse("http://192.168.1.42:53187"),
    enrolmentSecret: "enrolment-secret",
  );

  final onlineState = OcptHostingState(
    isLoading: false,
    hostState: onlineHostState,
    hostOnLaunch: false,
    canSetAutoRestart: true,
    presenceRoster: const OcptPresenceRoster(
      participants: [
        OcptPresenceFrame(deviceId: "device-abc", platform: "macos", modeKey: null, heartbeat: 1),
        OcptPresenceFrame(deviceId: "device-xyz", platform: "windows", modeKey: null, heartbeat: 1),
      ],
      selfDeviceId: "device-abc",
    ),
    isReconciling: false,
    reconcileOutcome: null,
    reconcileInviteInvalid: false,
  );

  const stoppedState = OcptHostingState(
    isLoading: false,
    hostState: OcptRelayHostStopped(),
    hostOnLaunch: false,
    canSetAutoRestart: false,
    presenceRoster: null,
    isReconciling: false,
    reconcileOutcome: null,
    reconcileInviteInvalid: false,
  );

  /// Pumps [OcptHostingPanel] over [state], on a surface wide and tall enough that nothing in the
  /// online state's own column overflows before the panel's own `SingleChildScrollView` gets a
  /// chance to handle it.
  Future<void> pumpPanel(
    WidgetTester tester,
    OcptHostingState state, {
    ValueChanged<bool>? onStartStopRequested,
    ValueChanged<bool>? onAutoRestartChanged,
    ValueChanged<String>? onReconcileRequested,
    VoidCallback? onReconcileDismissed,
  }) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrap(
        OcptHostingPanel(
          state: state,
          onStartStopRequested: onStartStopRequested ?? (_) {},
          onAutoRestartChanged: onAutoRestartChanged ?? (_) {},
          onReconcileRequested: onReconcileRequested ?? (_) {},
          onReconcileDismissed: onReconcileDismissed ?? () {},
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets("an online state renders the address, the QR, the peers and the reconcile action", (
    tester,
  ) async {
    await pumpPanel(tester, onlineState);

    final tr = Tr.of(tester.element(find.byType(OcptHostingPanel)));

    expect(find.text(onlineHostState.lanBaseUri.toString()), findsOneWidget);
    expect(find.byType(OcptEnrolmentQrCode), findsOneWidget);
    expect(find.text(tr.hostingPeersLabel), findsOneWidget);
    expect(find.textContaining("macos"), findsNothing);
    expect(find.textContaining("Macos"), findsOneWidget);
    expect(find.text(tr.hostingReconcileAction), findsOneWidget);
    expect(tester.takeException(), isNull);

    final switchWidget = tester.widget<Switch>(find.byType(Switch));
    expect(switchWidget.value, isTrue);
  });

  testWidgets("an empty peer list shows the no-peers line instead of the wrap", (tester) async {
    await pumpPanel(tester, onlineState.copyWith(clearPresenceRoster: true));

    final tr = Tr.of(tester.element(find.byType(OcptHostingPanel)));
    expect(find.text(tr.hostingNoPeers), findsOneWidget);
  });

  testWidgets("a stopped state hides the online-only block and switches the switch off", (
    tester,
  ) async {
    await pumpPanel(tester, stoppedState);

    final tr = Tr.of(tester.element(find.byType(OcptHostingPanel)));

    expect(find.byType(OcptEnrolmentQrCode), findsNothing);
    expect(find.text(tr.hostingAddressLabel), findsNothing);
    expect(find.text(tr.hostingPeersLabel), findsNothing);
    expect(find.text(tr.hostingReconcileAction), findsNothing);
    expect(tester.takeException(), isNull);

    final switchWidget = tester.widget<Switch>(find.byType(Switch));
    expect(switchWidget.value, isFalse);
  });

  testWidgets("the auto-restart checkbox is disabled when canSetAutoRestart is false", (
    tester,
  ) async {
    await pumpPanel(tester, stoppedState);

    final checkbox = tester.widget<CheckboxListTile>(find.byType(CheckboxListTile));
    expect(checkbox.onChanged, isNull);
  });

  testWidgets("the auto-restart checkbox is enabled and toggles when canSetAutoRestart is true", (
    tester,
  ) async {
    bool? toggled;
    await pumpPanel(tester, onlineState, onAutoRestartChanged: (value) => toggled = value);

    final checkbox = tester.widget<CheckboxListTile>(find.byType(CheckboxListTile));
    expect(checkbox.onChanged, isNotNull);

    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();

    expect(toggled, isTrue);
  });

  testWidgets("toggling the switch reports the value it was set to", (tester) async {
    bool? requestedStart;
    await pumpPanel(tester, stoppedState, onStartStopRequested: (value) => requestedStart = value);

    await tester.tap(find.byType(Switch));
    await tester.pump();

    expect(requestedStart, isTrue);
  });

  testWidgets("opening the reconcile form reveals the invite field and the run button", (
    tester,
  ) async {
    await pumpPanel(tester, onlineState);

    final tr = Tr.of(tester.element(find.byType(OcptHostingPanel)));
    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.text(tr.hostingReconcileAction));
    await tester.pump();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text(tr.hostingReconcileRun), findsOneWidget);
  });

  testWidgets("running the reconcile form reports the typed invite text", (tester) async {
    String? requestedInvite;
    await pumpPanel(tester, onlineState, onReconcileRequested: (text) => requestedInvite = text);

    final tr = Tr.of(tester.element(find.byType(OcptHostingPanel)));
    await tester.tap(find.text(tr.hostingReconcileAction));
    await tester.pump();

    await tester.enterText(find.byType(TextField), "ocpt://join?r=https%3A%2F%2Fr.example%2F&p=p&t=t");
    await tester.tap(find.text(tr.hostingReconcileRun));
    await tester.pump();

    expect(requestedInvite, "ocpt://join?r=https%3A%2F%2Fr.example%2F&p=p&t=t");
  });

  testWidgets("a successful reconcile outcome shows the pushed/pulled result line", (tester) async {
    await pumpPanel(
      tester,
      onlineState.copyWith(reconcileOutcome: const OcptReconcileSucceeded(pushed: 3, pulled: 0)),
    );

    final tr = Tr.of(tester.element(find.byType(OcptHostingPanel)));
    expect(find.text(tr.hostingReconcileResult(3, 0)), findsOneWidget);
  });

  testWidgets("a failed reconcile outcome shows the generic failure line", (tester) async {
    await pumpPanel(
      tester,
      onlineState.copyWith(reconcileOutcome: const OcptReconcileFailed("boom")),
    );

    final tr = Tr.of(tester.element(find.byType(OcptHostingPanel)));
    expect(find.text(tr.hostingReconcileFailed), findsOneWidget);
  });

  testWidgets("an invalid invite shows the dedicated invalid-invite line", (tester) async {
    await pumpPanel(tester, onlineState.copyWith(reconcileInviteInvalid: true));

    final tr = Tr.of(tester.element(find.byType(OcptHostingPanel)));
    expect(find.text(tr.hostingReconcileInvalidInvite), findsOneWidget);
  });

  testWidgets("a failed host state shows the discreet status line", (tester) async {
    await pumpPanel(
      tester,
      stoppedState.copyWith(hostState: const OcptRelayHostFailed("could not bind")),
    );

    final tr = Tr.of(tester.element(find.byType(OcptHostingPanel)));
    expect(find.text(tr.hostingStatusFailed), findsOneWidget);
  });
}
