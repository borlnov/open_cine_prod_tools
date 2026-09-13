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
import 'package:open_cine_prod_tools/managers/logging/ocpt_file_logging_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_diagnostics_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_diagnostics_entry.dart';
import 'package:open_cine_prod_tools/ui/pages/diagnostics/ocpt_diagnostics_page.dart';

/// A router manager whose [pop] only records the call — this page test pumps
/// [OcptDiagnosticsPage] directly, without a real GoRouter for it to operate on, exactly
/// `settings_page_test.dart`'s own `_RecordingRouterManager`.
class _RecordingRouterManager extends OcptRouterManager {
  /// Whether [pop] was called.
  bool popped = false;

  @override
  void pop<Y extends Object?>([Y? result]) {
    popped = true;
  }
}

/// A file logging manager reporting a fixed [logFilePath], overridden directly since nothing here
/// wants to run the real per-platform file setup `initLifeCycle` would otherwise attempt.
class _FakeFileLoggingManager extends OcptFileLoggingManager {
  /// Class constructor
  _FakeFileLoggingManager(this._path);

  /// The path [logFilePath] reports.
  final String? _path;

  @override
  String? get logFilePath => _path;
}

/// Wraps [child] with the app theme and the localization delegates so `Tr.of` lookups resolve.
Widget _wrap(Widget child) => MaterialApp(
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

void main() {
  late _RecordingRouterManager routerManager;
  late OcptDiagnosticsManager diagnosticsManager;
  String? clipboardText;

  setUpAll(() {
    // OcptGlobalManager and OcptDiagnosticsEntry both log through appLogger(), which requires a
    // global manager instance to be set; merely accessing it creates the (otherwise unused)
    // singleton, exactly as every other manager/widget test in this app does.
    OcptGlobalManager.instance;
  });

  setUp(() async {
    final managers = globalGetIt();

    if (managers.isRegistered<OcptRouterManager>()) {
      await managers.unregister<OcptRouterManager>();
    }
    routerManager = _RecordingRouterManager();
    managers.registerSingleton<OcptRouterManager>(routerManager);

    if (managers.isRegistered<OcptDiagnosticsManager>()) {
      await managers.unregister<OcptDiagnosticsManager>();
    }
    diagnosticsManager = OcptDiagnosticsManager();
    managers.registerSingleton<OcptDiagnosticsManager>(diagnosticsManager);

    if (managers.isRegistered<OcptFileLoggingManager>()) {
      await managers.unregister<OcptFileLoggingManager>();
    }

    // `Clipboard.setData` has no built-in mock handler on this SDK: without one it never
    // completes, exactly `ocpt_diagnostics_log_list_test.dart`'s own reasoning.
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
    if (managers.isRegistered<OcptRouterManager>()) {
      await managers.unregister<OcptRouterManager>();
    }
    if (managers.isRegistered<OcptDiagnosticsManager>()) {
      await managers.unregister<OcptDiagnosticsManager>();
    }
    if (managers.isRegistered<OcptFileLoggingManager>()) {
      await managers.unregister<OcptFileLoggingManager>();
    }
    await diagnosticsManager.disposeLifeCycle();
  });

  testWidgets("shows every recorded entry, with the title and the back button", (tester) async {
    diagnosticsManager.record(category: OcptDiagnosticsCategory.hosting, message: 'starting hosting');
    diagnosticsManager.record(category: OcptDiagnosticsCategory.sync, message: 'in sync');

    await tester.pumpWidget(_wrap(const OcptDiagnosticsPage()));

    final tr = Tr.of(tester.element(find.byType(OcptDiagnosticsPage)));
    expect(find.text(tr.diagnosticsLogTitle), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
    expect(find.textContaining('starting hosting'), findsOneWidget);
    expect(find.textContaining('in sync'), findsOneWidget);
  });

  testWidgets("the back button pops through the router manager", (tester) async {
    await tester.pumpWidget(_wrap(const OcptDiagnosticsPage()));

    await tester.tap(find.byType(BackButton));
    await tester.pump();

    expect(routerManager.popped, isTrue);
  });

  testWidgets("the copy and clear actions still wire up to the diagnostics manager", (
    tester,
  ) async {
    diagnosticsManager.record(category: OcptDiagnosticsCategory.hosting, message: 'starting hosting');

    await tester.pumpWidget(_wrap(const OcptDiagnosticsPage()));

    final tr = Tr.of(tester.element(find.byType(OcptDiagnosticsPage)));
    await tester.tap(find.byTooltip(tr.diagnosticsCopyTooltip));
    await tester.pump();
    expect(clipboardText, contains('starting hosting'));

    await tester.tap(find.byTooltip(tr.diagnosticsClearTooltip));
    await tester.pump();
    expect(diagnosticsManager.entries, isEmpty);
    expect(find.text(tr.diagnosticsEmpty), findsOneWidget);
  });

  testWidgets("shows the log file path and a copy-path button when file logging is enabled", (
    tester,
  ) async {
    final managers = globalGetIt();
    managers.registerSingleton<OcptFileLoggingManager>(
      _FakeFileLoggingManager('/home/user/.local/share/open_cine_prod_tools/logs/app.log'),
    );

    await tester.pumpWidget(_wrap(const OcptDiagnosticsPage()));

    final tr = Tr.of(tester.element(find.byType(OcptDiagnosticsPage)));
    expect(find.text(tr.diagnosticsLogFileLabel), findsOneWidget);
    expect(
      find.text('/home/user/.local/share/open_cine_prod_tools/logs/app.log'),
      findsOneWidget,
    );
    expect(find.text(tr.diagnosticsLogFileDisabled), findsNothing);

    await tester.tap(find.byTooltip(tr.diagnosticsLogFileCopyPath));
    await tester.pump();
    expect(clipboardText, '/home/user/.local/share/open_cine_prod_tools/logs/app.log');
  });

  testWidgets("shows the disabled message when no log file path is available", (tester) async {
    await tester.pumpWidget(_wrap(const OcptDiagnosticsPage()));

    final tr = Tr.of(tester.element(find.byType(OcptDiagnosticsPage)));
    expect(find.text(tr.diagnosticsLogFileDisabled), findsOneWidget);
    expect(find.byTooltip(tr.diagnosticsLogFileCopyPath), findsNothing);
  });

  testWidgets(
    "tolerates a completely bare manager environment, with no error",
    (tester) async {
      final managers = globalGetIt();
      await managers.unregister<OcptDiagnosticsManager>();

      await tester.pumpWidget(_wrap(const OcptDiagnosticsPage()));

      final tr = Tr.of(tester.element(find.byType(OcptDiagnosticsPage)));
      expect(find.text(tr.diagnosticsEmpty), findsOneWidget);
      expect(find.text(tr.diagnosticsLogFileDisabled), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
