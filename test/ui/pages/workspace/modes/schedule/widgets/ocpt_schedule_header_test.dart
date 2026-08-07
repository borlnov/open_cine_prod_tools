// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/types/ocpt_first_weekday.dart';
import 'package:open_cine_prod_tools/types/ocpt_schedule_agenda_color_mode.dart';
import 'package:open_cine_prod_tools/types/ocpt_schedule_agenda_mode.dart';
import 'package:open_cine_prod_tools/types/ocpt_schedule_centre_view.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_header.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve, inside a sized box
/// standing in for the mode's own content column.
Widget _wrapInApp(Widget child) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: SizedBox(width: 900, height: 300, child: child)),
);

/// Builds a header showing the agenda, with [colorMode] as its own current "Colour by" selection —
/// the shape every test below starts from.
Widget _buildHeader({
  required OcptScheduleCentreView centreView,
  OcptScheduleAgendaColorMode colorMode = OcptScheduleAgendaColorMode.location,
  ValueChanged<OcptScheduleAgendaColorMode>? onColorModeSelected,
}) => _wrapInApp(
  OcptScheduleHeader(
    centreView: centreView,
    onCentreViewSelected: (_) {},
    agendaMode: OcptScheduleAgendaMode.strip,
    onAgendaModeSelected: (_) {},
    agendaColorMode: colorMode,
    onAgendaColorModeSelected: onColorModeSelected ?? (_) {},
    agendaAnchorDate: DateTime(2026, 8, 3),
    onAgendaAnchorDateChanged: (_) {},
    firstWeekday: OcptFirstWeekday.monday,
  ),
);

void main() {
  testWidgets("the Colour by control is hidden outside the agenda view", (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildHeader(centreView: OcptScheduleCentreView.day),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptScheduleHeader)));
    expect(find.text(tr.scheduleAgendaColorByLabel), findsNothing);
  });

  testWidgets(
    "the Colour by control shows with the agenda view, defaulting to Location",
    (tester) async {
      await tester.pumpWidget(
        _buildHeader(centreView: OcptScheduleCentreView.agenda),
      );
      await tester.pumpAndSettle();

      final tr = Tr.of(tester.element(find.byType(OcptScheduleHeader)));
      expect(find.text(tr.scheduleAgendaColorByLabel), findsOneWidget);
      expect(find.text(tr.scheduleAgendaColorModeLocation), findsOneWidget);
      expect(find.text(tr.scheduleAgendaColorModeEffect), findsOneWidget);
      // Nothing to teach a reader while every day is tinted by its own location.
      expect(find.text(tr.scheduleAgendaEffectLegendMixed), findsNothing);
    },
  );

  testWidgets("tapping the Effect segment reports the switch", (tester) async {
    final selections = <OcptScheduleAgendaColorMode>[];
    await tester.pumpWidget(
      _buildHeader(
        centreView: OcptScheduleCentreView.agenda,
        onColorModeSelected: selections.add,
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptScheduleHeader)));
    await tester.tap(find.text(tr.scheduleAgendaColorModeEffect));
    await tester.pump();

    expect(selections, [OcptScheduleAgendaColorMode.effect]);
  });

  testWidgets(
    "the effect legend shows all five readings, only under Colour by effect",
    (tester) async {
      await tester.pumpWidget(
        _buildHeader(
          centreView: OcptScheduleCentreView.agenda,
          colorMode: OcptScheduleAgendaColorMode.effect,
        ),
      );
      await tester.pumpAndSettle();

      final tr = Tr.of(tester.element(find.byType(OcptScheduleHeader)));
      expect(
        find.text(tr.scheduleAgendaEffectLegendInteriorDay),
        findsOneWidget,
      );
      expect(
        find.text(tr.scheduleAgendaEffectLegendInteriorNight),
        findsOneWidget,
      );
      expect(
        find.text(tr.scheduleAgendaEffectLegendExteriorDay),
        findsOneWidget,
      );
      expect(
        find.text(tr.scheduleAgendaEffectLegendExteriorNight),
        findsOneWidget,
      );
      expect(find.text(tr.scheduleAgendaEffectLegendMixed), findsOneWidget);
    },
  );
}
