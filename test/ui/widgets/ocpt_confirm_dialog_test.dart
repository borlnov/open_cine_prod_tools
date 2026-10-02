// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_confirm_dialog.dart';

/// A router manager whose [pop] only records the last call and its value — mirrors
/// `ocpt_crew_position_picker_dialog_test.dart`'s own double.
class _RecordingRouterManager extends OcptRouterManager {
  /// Whether [pop] was called.
  bool popped = false;

  /// The value [pop] was last called with.
  Object? poppedValue;

  @override
  void pop<Y extends Object?>([Y? result]) {
    popped = true;
    poppedValue = result;
  }
}

void main() {
  late _RecordingRouterManager routerManager;

  setUpAll(() {
    OcptGlobalManager.instance;
  });

  setUp(() async {
    final managers = globalGetIt();
    if (managers.isRegistered<OcptRouterManager>()) {
      await managers.unregister<OcptRouterManager>();
    }

    routerManager = _RecordingRouterManager();
    managers.registerSingleton<OcptRouterManager>(routerManager);
  });

  /// Pumps [child] directly (no `showDialog`/`.show`), mirroring
  /// `ocpt_crew_position_picker_dialog_test.dart`.
  Future<void> pumpDialog(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(MaterialApp(home: child));
    await tester.pumpAndSettle();
  }

  group('OcptConfirmDialog.show (unchanged, two buttons, bool result)', () {
    testWidgets('cancel pops nothing (a plain pop())', (tester) async {
      await pumpDialog(
        tester,
        const OcptConfirmDialog(
          title: 'Delete this?',
          message: 'This cannot be undone.',
          cancelLabel: 'Cancel',
          confirmLabel: 'Delete',
        ),
      );

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(routerManager.popped, isTrue);
      expect(routerManager.poppedValue, isNull);
      // Never a third button when alternativeLabel is withheld.
      expect(find.byType(TextButton), findsOneWidget);
    });

    testWidgets('confirm pops true', (tester) async {
      await pumpDialog(
        tester,
        const OcptConfirmDialog(
          title: 'Delete this?',
          message: 'This cannot be undone.',
          cancelLabel: 'Cancel',
          confirmLabel: 'Delete',
        ),
      );

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(routerManager.poppedValue, true);
    });

    testWidgets('isDestructive false paints the confirm button plainly', (tester) async {
      await pumpDialog(
        tester,
        const OcptConfirmDialog(
          title: 'Replace this?',
          message: 'The previous value is lost.',
          cancelLabel: 'Cancel',
          confirmLabel: 'Replace',
          isDestructive: false,
        ),
      );

      final filledButton = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(filledButton.style, isNull);
    });
  });

  group('OcptConfirmDialog with alternativeLabel (three buttons, enum result)', () {
    Widget dialog() => const OcptConfirmDialog(
      title: 'Delete this set element?',
      message: 'It is used by 3 sequences.',
      cancelLabel: 'Cancel',
      confirmLabel: 'Delete everywhere',
      alternativeLabel: 'Remove from sequence 7',
    );

    testWidgets('shows all three buttons', (tester) async {
      await pumpDialog(tester, dialog());

      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Remove from sequence 7'), findsOneWidget);
      expect(find.text('Delete everywhere'), findsOneWidget);
      expect(find.byType(TextButton), findsNWidgets(2));
    });

    testWidgets('cancel pops OcptConfirmDialogResult.cancelled', (tester) async {
      await pumpDialog(tester, dialog());

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(routerManager.poppedValue, OcptConfirmDialogResult.cancelled);
    });

    testWidgets('the alternative button pops OcptConfirmDialogResult.alternative', (tester) async {
      await pumpDialog(tester, dialog());

      await tester.tap(find.text('Remove from sequence 7'));
      await tester.pumpAndSettle();

      expect(routerManager.poppedValue, OcptConfirmDialogResult.alternative);
    });

    testWidgets('confirm pops OcptConfirmDialogResult.confirmed', (tester) async {
      await pumpDialog(tester, dialog());

      await tester.tap(find.text('Delete everywhere'));
      await tester.pumpAndSettle();

      expect(routerManager.poppedValue, OcptConfirmDialogResult.confirmed);
    });
  });
}
