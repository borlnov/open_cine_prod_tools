// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/widgets/ocpt_breakdown_tag_popover.dart';
import 'package:open_cine_prod_tools/utils/ocpt_breakdown_search.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve, inside a `Stack` large
/// enough that a tap "outside" the popover has somewhere to land.
Widget _wrapInApp(Widget child) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(
    body: Stack(children: [const SizedBox.expand(), Align(alignment: Alignment.topLeft, child: child)]),
  ),
);

/// Wraps [child] in an app with no `Stack` of its own — what the anchor tests need, the popover
/// being painted into the app's own overlay rather than beside its caller.
Widget _wrapAnchorInApp(Widget child) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: child),
);

/// Names the word the anchor tests hang the popover off, so their assertions can measure it.
const Key _anchorWordKey = Key("anchor-word");

/// Builds a candidate of [kind] named [name], tagged in [taggedSceneCount] scenes. [category]
/// defaults to [OcptElementCategory.prop] for an element candidate (the popover's own palette
/// lookup requires one) and stays null for a role or a set, exactly as a real candidate would.
OcptBreakdownSearchCandidate _candidate({
  required OcptBreakdownTargetKind kind,
  required String name,
  String id = "id-1",
  OcptElementCategory? category,
  int taggedSceneCount = 0,
}) => OcptBreakdownSearchCandidate(
  kind: kind,
  id: id,
  name: name,
  category: category ?? (kind == OcptBreakdownTargetKind.element ? OcptElementCategory.prop : null),
  taggedSceneCount: taggedSceneCount,
);

void main() {
  /// Pumps a scrolling column with [topInset] of empty space above the anchored word, inside a
  /// window [windowHeight] tall, and reports the word's own rect and the popover's.
  Future<(Rect word, Rect popover)> pumpAnchoredPopover(
    WidgetTester tester, {
    required double topInset,
    double windowHeight = 600,
  }) async {
    await tester.binding.setSurfaceSize(Size(800, windowHeight));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrapAnchorInApp(
        SingleChildScrollView(
          child: Column(
            children: [
              SizedBox(height: topInset),
              OcptBreakdownTagPopoverAnchor(
                popover: OcptBreakdownTagPopover(
                  taggedText: "crown",
                  candidates: const [],
                  onCandidateSelected: (_) {},
                  onCategorySelected: (_, __) {},
                  onOpenInResourcesRequested: () {},
                  onClose: () {},
                ),
                child: const Text("crown", key: _anchorWordKey),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
    // The popover is only shown from the frame after the word is laid out — the very frame its own
    // placement is measured in.
    await tester.pumpAndSettle();

    return (
      tester.getRect(find.byKey(_anchorWordKey)),
      tester.getRect(find.byType(OcptBreakdownTagPopover)),
    );
  }

  testWidgets("the popover opens under the word while the window has the room for it", (
    tester,
  ) async {
    final (word, popover) = await pumpAnchoredPopover(tester, topInset: 20);

    expect(popover.top, greaterThanOrEqualTo(word.bottom));
    expect(popover.bottom, lessThanOrEqualTo(600));
  });

  testWidgets("the popover opens above the word when the window has no room under it", (
    tester,
  ) async {
    final (word, popover) = await pumpAnchoredPopover(tester, topInset: 500);

    expect(popover.bottom, lessThanOrEqualTo(word.top));
    expect(popover.top, greaterThanOrEqualTo(0));
  });

  testWidgets("the popover is capped to the room the window leaves it", (tester) async {
    final (word, popover) = await pumpAnchoredPopover(
      tester,
      topInset: 300,
      windowHeight: 400,
    );

    // Neither side is tall enough for the whole panel, so it is squeezed into the better one and
    // scrolls the rest rather than hanging off the window.
    expect(popover.bottom, lessThanOrEqualTo(word.top));
    expect(popover.top, greaterThanOrEqualTo(0));
    expect(popover.height, lessThan(400));
  });

  testWidgets("shows the passage in quotes, pre-filled and focused in the search field", (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrapInApp(
        OcptBreakdownTagPopover(
          taggedText: "desk lamp",
          candidates: const [],
          onCandidateSelected: (_) {},
          onCategorySelected: (_, __) {},
          onOpenInResourcesRequested: () {},
          onClose: () {},
        ),
      ),
    );

    expect(find.text('"desk lamp"'), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, "desk lamp");
    expect(field.focusNode?.hasFocus, isTrue);
  });

  testWidgets("the × button closes the popover", (tester) async {
    var closed = false;
    await tester.pumpWidget(
      _wrapInApp(
        OcptBreakdownTagPopover(
          taggedText: "desk lamp",
          candidates: const [],
          onCandidateSelected: (_) {},
          onCategorySelected: (_, __) {},
          onOpenInResourcesRequested: () {},
          onClose: () => closed = true,
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(closed, isTrue);
  });

  testWidgets("Escape closes the popover", (tester) async {
    var closed = false;
    await tester.pumpWidget(
      _wrapInApp(
        OcptBreakdownTagPopover(
          taggedText: "desk lamp",
          candidates: const [],
          onCandidateSelected: (_) {},
          onCategorySelected: (_, __) {},
          onOpenInResourcesRequested: () {},
          onClose: () => closed = true,
        ),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(closed, isTrue);
  });

  testWidgets("a tap outside the popover closes it", (tester) async {
    var closed = false;
    await tester.pumpWidget(
      _wrapInApp(
        OcptBreakdownTagPopover(
          taggedText: "desk lamp",
          candidates: const [],
          onCandidateSelected: (_) {},
          onCategorySelected: (_, __) {},
          onOpenInResourcesRequested: () {},
          onClose: () => closed = true,
        ),
      ),
    );

    await tester.binding.setSurfaceSize(const Size(900, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pump();

    await tester.tapAt(const Offset(850, 850));
    await tester.pump();

    expect(closed, isTrue);
  });

  testWidgets("matches are grouped Roles, Sets, then Elements, each showing its own scene count", (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrapInApp(
        OcptBreakdownTagPopover(
          // An empty query matches every candidate, so all three groups show without typing.
          taggedText: "",
          candidates: [
            _candidate(kind: OcptBreakdownTargetKind.element, name: "Desk lamp", id: "el-1"),
            _candidate(
              kind: OcptBreakdownTargetKind.role,
              name: "LÉA",
              id: "role-1",
              taggedSceneCount: 2,
            ),
            _candidate(kind: OcptBreakdownTargetKind.set, name: "Kitchen", id: "set-1"),
          ],
          onCandidateSelected: (_) {},
          onCategorySelected: (_, __) {},
          onOpenInResourcesRequested: () {},
          onClose: () {},
        ),
      ),
    );

    final tr = await Tr.delegate.load(const Locale("en", "GB"));
    // Group titles are rendered upper-cased.
    final rolesTitleY = tester
        .getTopLeft(find.text(tr.breakdownPopoverRolesGroupTitle.toUpperCase()))
        .dy;
    final setsTitleY = tester
        .getTopLeft(find.text(tr.breakdownPopoverSetsGroupTitle.toUpperCase()))
        .dy;
    final elementsTitleY = tester
        .getTopLeft(find.text(tr.breakdownPopoverElementsGroupTitle.toUpperCase()))
        .dy;

    expect(rolesTitleY, lessThan(setsTitleY));
    expect(setsTitleY, lessThan(elementsTitleY));
    expect(find.text("LÉA"), findsOneWidget);
    expect(find.text("Kitchen"), findsOneWidget);
    expect(find.text("Desk lamp"), findsOneWidget);
    expect(find.text(tr.breakdownInspectorSceneCountLabel(2)), findsOneWidget);
  });

  testWidgets("typing into the field filters the matches live", (tester) async {
    await tester.pumpWidget(
      _wrapInApp(
        OcptBreakdownTagPopover(
          // An empty query matches every candidate, so both show before any typing.
          taggedText: "",
          candidates: [
            _candidate(kind: OcptBreakdownTargetKind.element, name: "Desk lamp", id: "el-1"),
            _candidate(kind: OcptBreakdownTargetKind.element, name: "Rug", id: "el-2"),
          ],
          onCandidateSelected: (_) {},
          onCategorySelected: (_, __) {},
          onOpenInResourcesRequested: () {},
          onClose: () {},
        ),
      ),
    );

    expect(find.text("Desk lamp"), findsOneWidget);
    expect(find.text("Rug"), findsOneWidget);

    await tester.enterText(find.byType(TextField), "rug");
    await tester.pump();

    expect(find.text("Desk lamp"), findsNothing);
    expect(find.text("Rug"), findsOneWidget);
  });

  testWidgets("clicking a match links it", (tester) async {
    OcptBreakdownSearchCandidate? linked;
    final candidate = _candidate(kind: OcptBreakdownTargetKind.element, name: "Desk lamp");

    await tester.pumpWidget(
      _wrapInApp(
        OcptBreakdownTagPopover(
          taggedText: "lamp",
          candidates: [candidate],
          onCandidateSelected: (picked) => linked = picked,
          onCategorySelected: (_, __) {},
          onOpenInResourcesRequested: () {},
          onClose: () {},
        ),
      ),
    );

    await tester.tap(find.text("Desk lamp"));
    await tester.pump();

    expect(linked, candidate);
  });

  testWidgets("clicking a category chip creates with the field's current text", (tester) async {
    (OcptElementCategory, String)? created;

    await tester.pumpWidget(
      _wrapInApp(
        OcptBreakdownTagPopover(
          taggedText: "desk lamp",
          candidates: const [],
          onCandidateSelected: (_) {},
          onCategorySelected: (category, name) => created = (category, name),
          onOpenInResourcesRequested: () {},
          onClose: () {},
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), "Desk lamp, 1960s");
    await tester.pump();

    // The category grid sits inside the popover's own internal scroll view, so its chips are not
    // always laid out within the visible viewport; invoking the `InkWell` found by its label text
    // directly is more robust here than a simulated tap that would first need to scroll it into
    // view.
    final tr = await Tr.delegate.load(const Locale("en", "GB"));
    final inkWell = tester.widget<InkWell>(
      find.ancestor(of: find.text(tr.resourcesElementCategoryProp), matching: find.byType(InkWell)),
    );
    inkWell.onTap!();
    await tester.pump();

    expect(created, (OcptElementCategory.prop, "Desk lamp, 1960s"));
  });

  testWidgets("Open in Resources is offered when the search names no role and no set", (
    tester,
  ) async {
    var requested = false;

    await tester.pumpWidget(
      _wrapInApp(
        OcptBreakdownTagPopover(
          taggedText: "lamp",
          candidates: [_candidate(kind: OcptBreakdownTargetKind.element, name: "Desk lamp")],
          onCandidateSelected: (_) {},
          onCategorySelected: (_, __) {},
          onOpenInResourcesRequested: () => requested = true,
          onClose: () {},
        ),
      ),
    );

    final tr = await Tr.delegate.load(const Locale("en", "GB"));
    final finder = find.text(tr.breakdownOpenInResourcesAction);
    expect(finder, findsOneWidget);

    // Sits inside the popover's own internal scroll view, below the category grid — invoking the
    // button found this way is more robust than a simulated tap that would first need to scroll it
    // into view.
    final button = tester.widget<OutlinedButton>(
      find.ancestor(of: finder, matching: find.byType(OutlinedButton)),
    );
    button.onPressed!();
    await tester.pump();
    expect(requested, isTrue);
  });

  testWidgets("Open in Resources is withheld once a role or a set is among the matches", (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrapInApp(
        OcptBreakdownTagPopover(
          // An empty query matches every candidate, so the role below is among the results.
          taggedText: "",
          candidates: [_candidate(kind: OcptBreakdownTargetKind.role, name: "LÉA")],
          onCandidateSelected: (_) {},
          onCategorySelected: (_, __) {},
          onOpenInResourcesRequested: () {},
          onClose: () {},
        ),
      ),
    );

    final tr = await Tr.delegate.load(const Locale("en", "GB"));
    expect(find.text(tr.breakdownOpenInResourcesAction), findsNothing);
  });
}
