// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_package_manifest.dart';
import 'package:open_cine_prod_tools/ui/pages/home/widgets/ocpt_project_package_skipped_files_dialog.dart';

/// The navigator [_buildHost] wires its `MaterialApp` to, so [_RecordingRouterManager.pop] has a
/// real navigator to dismiss the dialog through — this file has no `GoRouter` for
/// `OcptRouterManager`'s own `pop` to operate on.
final _navigatorKey = GlobalKey<NavigatorState>();

/// A router manager whose [pop] dismisses through [_navigatorKey] instead of a real `GoRouter`,
/// which this file has none of.
class _RecordingRouterManager extends OcptRouterManager {
  @override
  void pop<Y extends Object?>([Y? result]) => _navigatorKey.currentState?.pop<Y>(result);
}

/// Builds a button that shows [OcptProjectPackageSkippedFilesDialog] for [skippedAssets] when
/// pressed, themed and localized as the app does.
Widget _buildHost(List<OcptSkippedAsset> skippedAssets) => MaterialApp(
  navigatorKey: _navigatorKey,
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Builder(
    builder: (context) => ElevatedButton(
      onPressed: () => OcptProjectPackageSkippedFilesDialog.show(
        context,
        skippedAssets: skippedAssets,
      ),
      child: const Text('show'),
    ),
  ),
);

void main() {
  setUpAll(() {
    OcptGlobalManager.instance.managers.registerSingleton<OcptRouterManager>(
      _RecordingRouterManager(),
    );
  });

  testWidgets('names every skipped file by its own label', (tester) async {
    const skippedAssets = [
      OcptSkippedAsset(assetId: '1', label: 'Town hall permit', originalPath: '/tmp/permit.pdf'),
      OcptSkippedAsset(assetId: '2', label: '', originalPath: '/tmp/headshot.jpg'),
    ];

    await tester.pumpWidget(_buildHost(skippedAssets));
    await tester.tap(find.text('show'));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(OcptProjectPackageSkippedFilesDialog));
    final tr = Tr.of(context);

    expect(find.text(tr.homeImportSkippedFilesTitle), findsOneWidget);
    // A row with no label of its own is named by the file its path ends on.
    expect(
      find.text(tr.homeImportSkippedFilesMessage(2, 'Town hall permit, headshot.jpg')),
      findsOneWidget,
    );
  });

  testWidgets('the close button dismisses the dialog', (tester) async {
    const skippedAssets = [
      OcptSkippedAsset(assetId: '1', label: 'Town hall permit', originalPath: '/tmp/permit.pdf'),
    ];

    await tester.pumpWidget(_buildHost(skippedAssets));
    await tester.tap(find.text('show'));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(OcptProjectPackageSkippedFilesDialog));
    await tester.tap(find.text(Tr.of(context).homeImportSkippedFilesCloseAction));
    await tester.pumpAndSettle();

    expect(find.byType(OcptProjectPackageSkippedFilesDialog), findsNothing);
  });
}
