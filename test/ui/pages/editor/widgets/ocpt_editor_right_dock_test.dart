// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/types/ocpt_editor_right_dock_tab.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_right_dock.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve in tests, matching
/// `ocpt_editor_syntax_guide_panel_test.dart`'s own helper.
Widget _wrapWithLocalization(Widget child) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: child),
);

/// Builds a dock with [activeTab] active and every tab available (raw mode), recording every tab
/// clicked into [selected] and every close click into [closed].
Widget _dock({
  required OcptEditorRightDockTab activeTab,
  required List<OcptEditorRightDockTab> selected,
  required List<void> closed,
  bool isPreviewTabAvailable = true,
}) => OcptEditorRightDock(
  activeTab: activeTab,
  isPreviewTabAvailable: isPreviewTabAvailable,
  previewChild: const Text('preview body'),
  inspectorChild: const Text('inspector body'),
  metadataChild: const Text('metadata body'),
  versionsChild: const Text('versions body'),
  onTabSelected: selected.add,
  onClose: () => closed.add(null),
);

void main() {
  testWidgets('renders one label per available tab, in mock-up order', (tester) async {
    await tester.pumpWidget(
      _wrapWithLocalization(
        _dock(activeTab: OcptEditorRightDockTab.preview, selected: [], closed: []),
      ),
    );

    final context = tester.element(find.byType(OcptEditorRightDock));
    final tr = Tr.of(context);

    expect(find.text(tr.editorRightDockPreviewTabLabel), findsOneWidget);
    expect(find.text(tr.editorRightDockSyntaxTabLabel), findsOneWidget);
    expect(find.text(tr.editorRightDockInspectorTabLabel), findsOneWidget);
    expect(find.text(tr.editorRightDockMetadataTabLabel), findsOneWidget);
    expect(find.text(tr.editorRightDockVersionsTabLabel), findsOneWidget);
  });

  testWidgets('the preview tab is skipped in styled mode (isPreviewTabAvailable: false)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrapWithLocalization(
        _dock(
          activeTab: OcptEditorRightDockTab.syntax,
          selected: [],
          closed: [],
          isPreviewTabAvailable: false,
        ),
      ),
    );

    final context = tester.element(find.byType(OcptEditorRightDock));
    final tr = Tr.of(context);

    expect(find.text(tr.editorRightDockPreviewTabLabel), findsNothing);
    expect(find.text(tr.editorRightDockSyntaxTabLabel), findsOneWidget);
  });

  testWidgets('renders the active tab body only', (tester) async {
    await tester.pumpWidget(
      _wrapWithLocalization(
        _dock(activeTab: OcptEditorRightDockTab.inspector, selected: [], closed: []),
      ),
    );

    expect(find.text('inspector body'), findsOneWidget);
    expect(find.text('metadata body'), findsNothing);
    expect(find.text('preview body'), findsNothing);
    expect(find.text('versions body'), findsNothing);
  });

  testWidgets('tapping a tab label dispatches its selection', (tester) async {
    final selected = <OcptEditorRightDockTab>[];
    await tester.pumpWidget(
      _wrapWithLocalization(
        _dock(activeTab: OcptEditorRightDockTab.preview, selected: selected, closed: []),
      ),
    );

    final context = tester.element(find.byType(OcptEditorRightDock));
    final tr = Tr.of(context);

    await tester.tap(find.text(tr.editorRightDockMetadataTabLabel));
    expect(selected, [OcptEditorRightDockTab.metadata]);

    await tester.tap(find.text(tr.editorRightDockInspectorTabLabel));
    expect(selected, [OcptEditorRightDockTab.metadata, OcptEditorRightDockTab.inspector]);

    await tester.tap(find.text(tr.editorRightDockSyntaxTabLabel));
    expect(selected, [
      OcptEditorRightDockTab.metadata,
      OcptEditorRightDockTab.inspector,
      OcptEditorRightDockTab.syntax,
    ]);

    // Tapping the already-active tab still dispatches it: the toggle-closes-the-dock semantics
    // live in the bloc, not this widget.
    await tester.tap(find.text(tr.editorRightDockPreviewTabLabel));
    expect(selected.last, OcptEditorRightDockTab.preview);
  });

  testWidgets('the close button dispatches onClose, not a tab selection', (tester) async {
    final selected = <OcptEditorRightDockTab>[];
    final closed = <void>[];
    await tester.pumpWidget(
      _wrapWithLocalization(
        _dock(activeTab: OcptEditorRightDockTab.preview, selected: selected, closed: closed),
      ),
    );

    await tester.tap(find.byIcon(Icons.close));
    expect(closed, hasLength(1));
    expect(selected, isEmpty);
  });
}
