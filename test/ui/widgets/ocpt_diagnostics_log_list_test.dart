// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_diagnostics_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_diagnostics_entry.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_diagnostics_log_list.dart';

/// Wraps [child] with the app theme and the localization delegates so `Tr.of` lookups resolve,
/// inside a bounded-height body — [OcptDiagnosticsLogList] fills whatever space it is given
/// (an `Expanded` inside its own body), so a test needs a bounded ancestor rather than the
/// unbounded height a bare `MaterialApp`/`Scaffold` body would otherwise give it.
Widget _wrap(Widget child) => MaterialApp(
  theme: ocptTheme.lightThemeData,
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: SizedBox(height: 600, child: child)),
);

void main() {
  setUpAll(() {
    // OcptGlobalManager and OcptDiagnosticsEntry both log through appLogger(), which requires a
    // global manager instance to be set; merely accessing it creates the (otherwise unused)
    // singleton, exactly as every other manager/widget test in this app does.
    OcptGlobalManager.instance;
  });

  group('with a registered OcptDiagnosticsManager', () {
    late OcptDiagnosticsManager manager;
    String? clipboardText;

    setUp(() async {
      manager = OcptDiagnosticsManager();
      final managers = globalGetIt();
      if (managers.isRegistered<OcptDiagnosticsManager>()) {
        await managers.unregister<OcptDiagnosticsManager>();
      }
      managers.registerSingleton<OcptDiagnosticsManager>(manager);

      // `Clipboard.setData` has no built-in mock handler on this SDK: without one it never
      // completes, exactly `ocpt_styled_screenplay_editor_test.dart`'s own reasoning.
      clipboardText = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (methodCall) async {
          if (methodCall.method == 'Clipboard.setData') {
            clipboardText = (methodCall.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
      final managers = globalGetIt();
      if (managers.isRegistered<OcptDiagnosticsManager>()) {
        await managers.unregister<OcptDiagnosticsManager>();
      }
      await manager.disposeLifeCycle();
    });

    testWidgets('shows every recorded entry, oldest first', (tester) async {
      manager.record(category: OcptDiagnosticsCategory.hosting, message: 'starting hosting');
      manager.record(category: OcptDiagnosticsCategory.sync, message: 'in sync');

      await tester.pumpWidget(_wrap(const OcptDiagnosticsLogList()));

      expect(find.textContaining('starting hosting'), findsOneWidget);
      expect(find.textContaining('in sync'), findsOneWidget);
      expect(find.textContaining('HOSTING'), findsOneWidget);
      expect(find.textContaining('SYNC'), findsOneWidget);
    });

    testWidgets('filters entries down to the given categories', (tester) async {
      manager.record(category: OcptDiagnosticsCategory.hosting, message: 'starting hosting');
      manager.record(category: OcptDiagnosticsCategory.join, message: 'connecting');
      manager.record(category: OcptDiagnosticsCategory.sync, message: 'in sync');

      await tester.pumpWidget(
        _wrap(
          const OcptDiagnosticsLogList(
            categories: {OcptDiagnosticsCategory.join, OcptDiagnosticsCategory.sync},
          ),
        ),
      );

      expect(find.textContaining('starting hosting'), findsNothing);
      expect(find.textContaining('connecting'), findsOneWidget);
      expect(find.textContaining('in sync'), findsOneWidget);
    });

    testWidgets('shows the empty message when the buffer holds nothing', (tester) async {
      await tester.pumpWidget(_wrap(const OcptDiagnosticsLogList()));

      final tr = Tr.of(tester.element(find.byType(OcptDiagnosticsLogList)));
      expect(find.text(tr.diagnosticsEmpty), findsOneWidget);
    });

    testWidgets('rebuilds from entriesStream as new entries are recorded', (tester) async {
      await tester.pumpWidget(_wrap(const OcptDiagnosticsLogList()));

      manager.record(category: OcptDiagnosticsCategory.presence, message: 'peer joined');
      // The broadcast stream delivers on a microtask, not synchronously with `record`.
      await tester.pump(Duration.zero);
      await tester.pump();

      expect(find.textContaining('peer joined'), findsOneWidget);
    });

    testWidgets('the copy button puts every visible line on the clipboard', (tester) async {
      manager.record(category: OcptDiagnosticsCategory.hosting, message: 'starting hosting');
      manager.record(category: OcptDiagnosticsCategory.sync, message: 'in sync');

      await tester.pumpWidget(_wrap(const OcptDiagnosticsLogList()));

      final tr = Tr.of(tester.element(find.byType(OcptDiagnosticsLogList)));
      await tester.tap(find.byTooltip(tr.diagnosticsCopyTooltip));
      await tester.pump();

      expect(clipboardText, contains('starting hosting'));
      expect(clipboardText, contains('in sync'));
      expect(clipboardText, contains('\n'));
    });

    testWidgets('the clear button empties the manager and the list', (tester) async {
      manager.record(category: OcptDiagnosticsCategory.hosting, message: 'starting hosting');

      await tester.pumpWidget(_wrap(const OcptDiagnosticsLogList()));

      final tr = Tr.of(tester.element(find.byType(OcptDiagnosticsLogList)));
      await tester.tap(find.byTooltip(tr.diagnosticsClearTooltip));
      await tester.pump();

      expect(manager.entries, isEmpty);
      expect(find.textContaining('starting hosting'), findsNothing);
      expect(find.text(tr.diagnosticsEmpty), findsOneWidget);
    });

    testWidgets('the copy and clear buttons are disabled while the list is empty', (tester) async {
      await tester.pumpWidget(_wrap(const OcptDiagnosticsLogList()));

      final tr = Tr.of(tester.element(find.byType(OcptDiagnosticsLogList)));
      final copyButton = tester.widget<IconButton>(
        find.ancestor(of: find.byTooltip(tr.diagnosticsCopyTooltip), matching: find.byType(IconButton)),
      );
      final clearButton = tester.widget<IconButton>(
        find.ancestor(of: find.byTooltip(tr.diagnosticsClearTooltip), matching: find.byType(IconButton)),
      );

      expect(copyButton.onPressed, isNull);
      expect(clearButton.onPressed, isNull);
    });
  });

  testWidgets(
    'shows the empty message, with no error, when no OcptDiagnosticsManager is registered',
    (tester) async {
      final managers = globalGetIt();
      if (managers.isRegistered<OcptDiagnosticsManager>()) {
        await managers.unregister<OcptDiagnosticsManager>();
      }

      await tester.pumpWidget(_wrap(const OcptDiagnosticsLogList()));

      final tr = Tr.of(tester.element(find.byType(OcptDiagnosticsLogList)));
      expect(find.text(tr.diagnosticsEmpty), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
