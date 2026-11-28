// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:open_cine_prod_tools/constants/ocpt_localizations_delegates.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_page_zoom.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_preview_layout.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_zoom_area.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_zoom_control.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_zoom_key_activator.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_zoom_wheel.dart';

/// Wrap [child] in a localized app.
Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: const [Tr.delegate, ...ocptDesignLocalizationsDelegates],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: Center(child: child)),
);

/// Turn the wheel by [delta] over [at], with Ctrl held when [withCtrl] is.
Future<void> _wheel(WidgetTester tester, Offset at, double delta, {required bool withCtrl}) async {
  final pointer = TestPointer(1, PointerDeviceKind.mouse);
  await tester.sendEventToBinding(pointer.hover(at));
  if (withCtrl) {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  }
  await tester.sendEventToBinding(pointer.scroll(Offset(0, delta)));
  if (withCtrl) {
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  }
  await tester.pumpAndSettle();
}

/// Run the tests of the page zoom widgets.
void main() {
  group("OcptEditorZoomWheel", () {
    final listKey = GlobalKey();
    final controller = ScrollController();

    Widget list(List<(int, Offset)> requests) => _wrap(
      SizedBox(
        width: 300,
        height: 300,
        child: OcptEditorZoomWheel(
          onZoomStepRequested: (direction, position) => requests.add((direction, position)),
          child: ListView.builder(
            key: listKey,
            controller: controller,
            itemCount: 100,
            itemBuilder: (context, index) => SizedBox(height: 40, child: Text("Row $index")),
          ),
        ),
      ),
    );

    testWidgets("Ctrl + wheel steps once per notch, with the pointer position, and no scroll", (
      tester,
    ) async {
      final requests = <(int, Offset)>[];
      await tester.pumpWidget(list(requests));
      final center = tester.getCenter(find.byKey(listKey));

      await _wheel(tester, center, -60, withCtrl: true);
      await _wheel(tester, center, 60, withCtrl: true);

      expect(requests.map((request) => request.$1), [1, -1]);
      expect(requests.first.$2, const Offset(150, 150));
      expect(controller.offset, 0);
    });

    testWidgets("a plain wheel scrolls and steps nothing", (tester) async {
      final requests = <(int, Offset)>[];
      await tester.pumpWidget(list(requests));

      await _wheel(tester, tester.getCenter(find.byKey(listKey)), 60, withCtrl: false);

      expect(requests, isEmpty);
      expect(controller.offset, greaterThan(0));
    });

    testWidgets("with no callback the wheel is left to the scrolling, even with Ctrl", (
      tester,
    ) async {
      final inertController = ScrollController();
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 300,
            height: 300,
            child: OcptEditorZoomWheel(
              onZoomStepRequested: null,
              child: ListView.builder(
                key: listKey,
                controller: inertController,
                itemCount: 100,
                itemBuilder: (context, index) => SizedBox(height: 40, child: Text("Row $index")),
              ),
            ),
          ),
        ),
      );

      await _wheel(tester, tester.getCenter(find.byKey(listKey)), 60, withCtrl: true);

      expect(inertController.offset, greaterThan(0));
    });
  });

  group("OcptEditorZoomArea", () {
    Future<List<double>> pumpArea(
      WidgetTester tester, {
      required OcptPageZoom zoom,
      bool isZoomAvailable = true,
      List<double>? measured,
    }) async {
      final factors = <double>[];
      await tester.pumpWidget(
        _wrap(
          OcptEditorZoomArea(
            zoom: zoom,
            pageSetup: const OcptPageSetup.standard(),
            isZoomAvailable: isZoomAvailable,
            onFitFactorMeasured: (factor) => measured?.add(factor),
            onZoomStepRequested: (_) {},
            builder: (factor, onZoomStepRequested) {
              factors.add(factor);
              return Text(
                onZoomStepRequested == null ? "no wheel" : "wheel",
                textDirection: TextDirection.ltr,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      return factors;
    }

    testWidgets("a step is the factor as it is", (tester) async {
      final factors = await pumpArea(tester, zoom: OcptPageZoom.nearestStep(1.5));

      expect(factors.last, 1.5);
      expect(find.text("wheel"), findsOneWidget);
    });

    testWidgets("a compact window is at 100 % with no wheel, whatever the zoom", (tester) async {
      final factors = await pumpArea(
        tester,
        zoom: OcptPageZoom.nearestStep(1.5),
        isZoomAvailable: false,
      );

      expect(factors.last, 1);
      expect(find.text("no wheel"), findsOneWidget);
    });

    testWidgets("fit to width fills the area and follows a resize, within the bounds", (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.physicalSize = const Size(1000, 700);
      final measured = <double>[];

      final factors = await pumpArea(
        tester,
        zoom: const OcptPageZoom.fitToWidth(),
        measured: measured,
      );

      double sheetAt(double factor) => OcptEditorPreviewLayout(
        metrics: const OcptPageSetup.standard().toMetrics(),
        zoom: factor,
      ).pageWidth;

      // The sheet fills the area, a gutter kept on each side.
      expect(sheetAt(factors.last), closeTo(1000 - 32, 0.5));
      expect(measured.last, factors.last);

      tester.view.physicalSize = const Size(800, 700);
      await tester.pumpAndSettle();
      expect(sheetAt(factors.last), closeTo(800 - 32, 0.5));
      expect(measured.last, factors.last);

      tester.view.physicalSize = const Size(5000, 700);
      await tester.pumpAndSettle();
      expect(factors.last, 2);

      tester.view.physicalSize = const Size(200, 700);
      await tester.pumpAndSettle();
      expect(factors.last, 0.5);
    });
  });

  group("OcptEditorZoomControl", () {
    Future<Tr> pumpControl(
      WidgetTester tester, {
      double factor = 1,
      bool isFitToWidth = false,
      VoidCallback? onZoomOut,
      VoidCallback? onZoomIn,
      ValueChanged<OcptPageZoom>? onSelected,
    }) async {
      await tester.pumpWidget(
        _wrap(
          OcptEditorZoomControl(
            factor: factor,
            isFitToWidth: isFitToWidth,
            onZoomOutRequested: onZoomOut,
            onZoomInRequested: onZoomIn,
            onZoomSelected: onSelected ?? (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      return Tr.of(tester.element(find.byType(OcptEditorZoomControl)));
    }

    testWidgets("shows the percentage and calls back from its two buttons", (tester) async {
      var out = 0;
      var inward = 0;
      final tr = await pumpControl(
        tester,
        factor: 0.67,
        onZoomOut: () => out++,
        onZoomIn: () => inward++,
      );

      expect(find.text("67%"), findsOneWidget);
      await tester.tap(find.byTooltip(tr.editorZoomOutTooltip));
      await tester.tap(find.byTooltip(tr.editorZoomInTooltip));
      await tester.tap(find.byTooltip(tr.editorZoomInTooltip));

      expect((out, inward), (1, 2));
    });

    testWidgets("withholds a button with no callback, keeping the percentage in place", (
      tester,
    ) async {
      final tr = await pumpControl(tester, factor: 2, onZoomOut: () {});
      final withheld = tester.getCenter(find.text("200%"));

      expect(find.byTooltip(tr.editorZoomInTooltip), findsNothing);
      expect(find.byTooltip(tr.editorZoomOutTooltip), findsOneWidget);

      await pumpControl(tester, factor: 2, onZoomIn: () {}, onZoomOut: () {});
      expect(tester.getCenter(find.text("200%")), withheld);
    });

    testWidgets("the percentage opens the steps, the current one ticked, and the fit mode", (
      tester,
    ) async {
      final picked = <OcptPageZoom>[];
      final tr = await pumpControl(tester, factor: 1.25, onSelected: picked.add);

      await tester.tap(find.byTooltip(tr.editorZoomMenuTooltip));
      await tester.pumpAndSettle();

      // Exactly one entry is ticked: the others carry a transparent tick, to keep the labels
      // aligned.
      final ticked = tester
          .widgetList<Icon>(find.byIcon(Icons.check))
          .where((icon) => icon.color == null);
      expect(ticked, hasLength(1));
      for (final step in OcptPageZoom.steps) {
        expect(find.text("${OcptPageZoom.percentOf(step)}%"), findsWidgets);
      }

      await tester.tap(find.text("150%").last);
      await tester.pumpAndSettle();
      expect(picked.last, OcptPageZoom.nearestStep(1.5));

      await tester.tap(find.byTooltip(tr.editorZoomMenuTooltip));
      await tester.pumpAndSettle();
      await tester.tap(find.text(tr.editorZoomFitToWidth));
      await tester.pumpAndSettle();
      expect(picked.last, const OcptPageZoom.fitToWidth());
    });
  });

  group("OcptEditorZoomWheel steps and drags", () {
    /// Pump a wheel over a list and get the requests made by turning it [deltas] one event each.
    Future<List<int>> turn(WidgetTester tester, List<double> deltas) async {
      final requests = <int>[];
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 300,
            height: 300,
            child: OcptEditorZoomWheel(
              onZoomStepRequested: (direction, position) => requests.add(direction),
              child: ListView(children: const [SizedBox(height: 900)]),
            ),
          ),
        ),
      );
      final center = tester.getCenter(find.byType(ListView));
      for (final delta in deltas) {
        await _wheel(tester, center, delta, withCtrl: true);
      }

      return requests;
    }

    testWidgets("a Linux notch, 53 pixels, is one step", (tester) async {
      expect(await turn(tester, [-53, -53, -53]), [1, 1, 1]);
    });

    testWidgets("a 200 pixel notch is one step, never more", (tester) async {
      expect(await turn(tester, [-200, -200]), [1, 1]);
    });

    testWidgets("a smooth wheel's small events add up to a step each time they reach one", (
      tester,
    ) async {
      // The first event of a turn steps at once; the nine others, 72 pixels, make one more.
      expect(await turn(tester, List.filled(10, -8)), [1, 1]);
    });

    testWidgets("a touch drag still scrolls after the content grew while Ctrl was held", (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      Widget list(int itemCount) => _wrap(
        SizedBox(
          width: 300,
          height: 300,
          child: OcptEditorZoomWheel(
            onZoomStepRequested: (direction, position) {},
            child: ListView.builder(
              controller: controller,
              itemCount: itemCount,
              itemBuilder: (context, index) => SizedBox(height: 40, child: Text("Row $index")),
            ),
          ),
        ),
      );

      // Too short to scroll, so nothing may be dragged yet.
      await tester.pumpWidget(list(3));
      // A zoom (or a paste) makes it grow while the modifier is down...
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpWidget(list(100));
      await tester.pumpAndSettle();
      // ...and is released afterwards.
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

      await tester.drag(find.byType(ListView), const Offset(0, -200));
      await tester.pumpAndSettle();

      expect(controller.offset, greaterThan(0));
    });
  });

  group("OcptEditorZoomArea tree", () {
    testWidgets("keeps the page mounted from a step to the fit to width mode and back", (
      tester,
    ) async {
      var mounts = 0;
      Widget area(OcptPageZoom zoom) => _wrap(
        OcptEditorZoomArea(
          zoom: zoom,
          pageSetup: const OcptPageSetup.standard(),
          isZoomAvailable: true,
          onFitFactorMeasured: (_) {},
          onZoomStepRequested: (_) {},
          builder: (factor, onZoomStepRequested) =>
              _MountCounter(onMount: () => mounts++, factor: factor),
        ),
      );

      await tester.pumpWidget(area(const OcptPageZoom.actualSize()));
      final state = tester.state(find.byType(_MountCounter));
      await tester.pumpWidget(area(const OcptPageZoom.fitToWidth()));
      await tester.pumpWidget(area(OcptPageZoom.nearestStep(1.5)));

      expect(mounts, 1);
      expect(tester.state(find.byType(_MountCounter)), same(state));
    });
  });

  group("OcptEditorZoomKeyActivator", () {
    /// Tell whether the activator for [direction] accepts a key down of [key] producing
    /// [character], with Ctrl held.
    Future<bool> accepts(
      WidgetTester tester,
      int direction,
      LogicalKeyboardKey key,
      String? character,
    ) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      addTearDown(() => tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft));

      return OcptEditorZoomKeyActivator(direction).accepts(
        KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.digit6,
          logicalKey: key,
          character: character,
          timeStamp: Duration.zero,
        ),
        HardwareKeyboard.instance,
      );
    }

    testWidgets("on Windows, a digit6 with no character, the AZERTY minus, zooms out", (
      tester,
    ) async {
      expect(await accepts(tester, -1, LogicalKeyboardKey.digit6, null), isTrue);
      expect(await accepts(tester, -1, LogicalKeyboardKey.digit6, ""), isTrue);
      expect(await accepts(tester, 1, LogicalKeyboardKey.digit6, null), isFalse);
    });

    testWidgets("on Linux, a QWERTY Ctrl+6 carries its character and zooms nothing", (
      tester,
    ) async {
      for (final direction in [-1, 0, 1]) {
        expect(await accepts(tester, direction, LogicalKeyboardKey.digit6, "6"), isFalse);
      }
    });
  });
}

/// A page standing in for the real one, counting how many times it is mounted.
class _MountCounter extends StatefulWidget {
  /// Called when the state is created.
  final VoidCallback onMount;

  /// The factor the page is typeset at.
  final double factor;

  /// Class constructor
  const _MountCounter({required this.onMount, required this.factor});

  /// Create the state.
  @override
  State<_MountCounter> createState() => _MountCounterState();
}

/// The state of [_MountCounter].
class _MountCounterState extends State<_MountCounter> {
  /// Count the mount.
  @override
  void initState() {
    super.initState();
    widget.onMount();
  }

  /// Build the stand-in page.
  @override
  Widget build(BuildContext context) => Text("${widget.factor}");
}
