// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/constants/ocpt_crew_positions.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/types/ocpt_crew_department.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_resources_labels.dart';

/// The twenty ids the catalogue shipped with before it grew to cover the *Convention collective
/// nationale de la production cinématographique* — every one of them must still resolve, since an
/// id is never renamed or reused once shipped.
const _legacyIds = [
  'director',
  'firstAssistantDirector',
  'scriptSupervisor',
  'directorOfPhotography',
  'cameraOperator',
  'firstAssistantCamera',
  'gaffer',
  'electrician',
  'grip',
  'soundEngineer',
  'boomOperator',
  'setDecorator',
  'propsMaster',
  'setDresser',
  'makeupArtist',
  'hairStylist',
  'costumeDesigner',
  'productionManager',
  'productionAssistant',
  'lineProducer',
];

/// Wraps [builder] with the localization delegates so [Tr.of] lookups resolve.
Widget _wrapInApp(WidgetBuilder builder) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: Builder(builder: builder)),
);

void main() {
  test("every id is unique", () {
    final ids = ocptCrewPositions.map((position) => position.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test("every one of the twenty pre-existing ids is still present", () {
    final ids = ocptCrewPositions.map((position) => position.id).toSet();
    for (final legacyId in _legacyIds) {
      expect(ids.contains(legacyId), isTrue, reason: "$legacyId is missing from the catalogue");
    }
  });

  test("entries are grouped by department, contiguous, in OcptCrewDepartment's own order", () {
    final seenDepartments = <OcptCrewDepartment>{};
    OcptCrewDepartment? lastDepartment;

    for (final position in ocptCrewPositions) {
      if (position.department != lastDepartment) {
        expect(
          seenDepartments.contains(position.department),
          isFalse,
          reason: "${position.department} is split across two non-adjacent runs",
        );
        seenDepartments.add(position.department);
        lastDepartment = position.department;
      }
    }

    final departmentOrder = ocptCrewPositions.map((position) => position.department).toSet().toList();
    final expectedOrder = [
      for (final department in OcptCrewDepartment.values)
        if (departmentOrder.contains(department)) department,
    ];
    expect(departmentOrder, expectedOrder);
  });

  testWidgets("every id resolves through ocptCrewPositionLabel to something other than itself", (tester) async {
    await tester.pumpWidget(
      _wrapInApp((context) {
        final tr = Tr.of(context);
        for (final position in ocptCrewPositions) {
          final label = ocptCrewPositionLabel(tr, position.id);
          expect(label, isNot(position.id), reason: "${position.id} falls through the switch unresolved");
          expect(label, isNotEmpty);
        }
        return const SizedBox();
      }),
    );
  });

  testWidgets("every OcptCrewDepartment value resolves through ocptCrewDepartmentLabel", (tester) async {
    await tester.pumpWidget(
      _wrapInApp((context) {
        final tr = Tr.of(context);
        for (final department in OcptCrewDepartment.values) {
          expect(ocptCrewDepartmentLabel(tr, department), isNotEmpty);
        }
        return const SizedBox();
      }),
    );
  });
}
