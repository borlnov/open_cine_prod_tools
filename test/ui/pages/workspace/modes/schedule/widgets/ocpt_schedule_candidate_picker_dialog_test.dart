// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_role_candidate.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_candidate_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_candidate_picker_dialog.dart';

/// A router manager whose [pop] only records the last call and its value: this dialog is pumped
/// directly, without a real GoRouter for it to operate on.
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

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve in tests.
Widget _wrapWithLocalization(Widget child) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: child,
);

/// Builds a person whose display name is [firstName], everything else neutral.
OcptPerson _buildPerson({required String id, required String firstName}) => OcptPerson(
  id: id,
  firstName: firstName,
  lastName: "",
  email: "",
  phone: "",
  addressLine1: "",
  addressLine2: "",
  postalCode: "",
  city: "",
  region: "",
  country: "",
  colorIndex: 0,
  birthDate: null,
  minorNotes: "",
  maxDailyPresenceMinutes: null,
  isTransportAutonomous: null,
  accommodationNotes: "",
  travelNotes: "",
  dietaryNotes: "",
  allergies: "",
  measurementHeight: "",
  measurementChest: "",
  measurementWaist: "",
  measurementHips: "",
  sizeTop: "",
  sizeBottom: "",
  sizeShoes: "",
  hmcNotes: "",
  imageRightsStatus: OcptImageRightsStatus.notApplicable,
  imageRightsDate: null,
  imageRightsAssetId: null,
  imageRightsDocument: null,
  photoAssetId: null,
  photo: null,
  notes: "",
  positions: const [],
  skills: const [],
  unavailabilities: const [],
);

/// Builds a part with the few fields these tests read.
OcptRole _buildRole({required String id, required String name}) => OcptRole(
  id: id,
  name: name,
  personId: null,
  kind: OcptRoleKind.speaking,
  isFromScreenplay: true,
  orphanedName: null,
  castingNotes: "",
  number: 1,
  episodeIds: const [],
);

/// Builds a candidacy with the few fields these tests read.
OcptRoleCandidate _buildCandidacy({
  required String id,
  required String roleId,
  required String firstName,
  OcptRoleCandidateStatus status = OcptRoleCandidateStatus.seen,
}) => OcptRoleCandidate(
  id: id,
  roleId: roleId,
  person: _buildPerson(id: "person-$id", firstName: firstName),
  status: status,
  auditionedOn: null,
  notes: "",
);

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

  /// Pumps [OcptScheduleCandidatePickerDialog] directly (no `showDialog`/`.show`).
  Future<void> pumpDialog(
    WidgetTester tester, {
    required List<OcptRoleCandidate> roleCandidates,
    Map<String, OcptRole> roleById = const {},
    Set<String> plannedCandidacyIds = const {},
  }) async {
    await tester.pumpWidget(
      _wrapWithLocalization(
        OcptScheduleCandidatePickerDialog(
          roleCandidates: roleCandidates,
          roleById: roleById,
          plannedCandidacyIds: plannedCandidacyIds,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets("every candidacy is listed, grouped under the part it is for", (tester) async {
    await pumpDialog(
      tester,
      roleCandidates: [
        _buildCandidacy(id: "candidacy-1", roleId: "role-1", firstName: "Camille"),
        _buildCandidacy(id: "candidacy-2", roleId: "role-1", firstName: "Alice"),
        _buildCandidacy(id: "candidacy-3", roleId: "role-2", firstName: "Bruno"),
      ],
      roleById: {
        "role-1": _buildRole(id: "role-1", name: "MARIE"),
        "role-2": _buildRole(id: "role-2", name: "PAUL"),
      },
    );

    expect(find.text("MARIE"), findsOneWidget);
    expect(find.text("PAUL"), findsOneWidget);
    // Within a part, the candidates read in display-name order: the casting director's own ranking
    // is a reading of the role sheet, not of a running order.
    expect(
      tester.getCenter(find.text("Alice")).dy,
      lessThan(tester.getCenter(find.text("Camille")).dy),
    );
    expect(find.text("Bruno"), findsOneWidget);
  });

  testWidgets("picking a candidacy pops the dialog with its id", (tester) async {
    await pumpDialog(
      tester,
      roleCandidates: [_buildCandidacy(id: "candidacy-1", roleId: "role-1", firstName: "Camille")],
      roleById: {"role-1": _buildRole(id: "role-1", name: "MARIE")},
    );

    await tester.tap(find.text("Camille"));
    await tester.pumpAndSettle();

    expect(routerManager.popped, isTrue);
    expect(routerManager.poppedValue, "candidacy-1");
  });

  testWidgets("the search matches a candidate's name and the part alike", (tester) async {
    await pumpDialog(
      tester,
      roleCandidates: [
        _buildCandidacy(id: "candidacy-1", roleId: "role-1", firstName: "Camille"),
        _buildCandidacy(id: "candidacy-2", roleId: "role-2", firstName: "Bruno"),
      ],
      roleById: {
        "role-1": _buildRole(id: "role-1", name: "MARIE"),
        "role-2": _buildRole(id: "role-2", name: "PAUL"),
      },
    );

    await tester.enterText(find.byType(TextField), "paul");
    await tester.pumpAndSettle();

    expect(find.text("Bruno"), findsOneWidget);
    expect(find.text("Camille"), findsNothing);

    await tester.enterText(find.byType(TextField), "camille");
    await tester.pumpAndSettle();

    expect(find.text("Camille"), findsOneWidget);
    expect(find.text("Bruno"), findsNothing);
  });

  testWidgets("a search matching nothing shows the no-results hint", (tester) async {
    await pumpDialog(
      tester,
      roleCandidates: [_buildCandidacy(id: "candidacy-1", roleId: "role-1", firstName: "Camille")],
      roleById: {"role-1": _buildRole(id: "role-1", name: "MARIE")},
    );

    await tester.enterText(find.byType(TextField), "zzz");
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptScheduleCandidatePickerDialog)));
    expect(find.text(tr.scheduleCandidatePickerNoResultsHint), findsOneWidget);
  });

  testWidgets("a project with no candidacy at all shows its own hint", (tester) async {
    await pumpDialog(tester, roleCandidates: const []);

    final tr = Tr.of(tester.element(find.byType(OcptScheduleCandidatePickerDialog)));
    expect(find.text(tr.scheduleCandidatePickerEmptyHint), findsOneWidget);
  });

  testWidgets("a candidacy already planned on the day is marked, and stays clickable", (tester) async {
    await pumpDialog(
      tester,
      roleCandidates: [_buildCandidacy(id: "candidacy-1", roleId: "role-1", firstName: "Camille")],
      roleById: {"role-1": _buildRole(id: "role-1", name: "MARIE")},
      plannedCandidacyIds: const {"candidacy-1"},
    );

    final tr = Tr.of(tester.element(find.byType(OcptScheduleCandidatePickerDialog)));
    expect(find.byTooltip(tr.scheduleCandidatePickerAlreadyPlannedTooltip), findsOneWidget);

    // The mark is information, never a bar: seeing somebody twice in one session is legitimate.
    await tester.tap(find.text("Camille"));
    await tester.pumpAndSettle();

    expect(routerManager.poppedValue, "candidacy-1");
  });

  testWidgets("a candidacy whose part is gone is grouped under the unnamed-role fallback", (tester) async {
    await pumpDialog(
      tester,
      roleCandidates: [_buildCandidacy(id: "candidacy-1", roleId: "role-gone", firstName: "Camille")],
    );

    final tr = Tr.of(tester.element(find.byType(OcptScheduleCandidatePickerDialog)));
    expect(find.text(tr.resourcesRoleUnnamed), findsOneWidget);
    expect(find.text("Camille"), findsOneWidget);
  });

  testWidgets("cancelling pops the dialog with nothing", (tester) async {
    await pumpDialog(
      tester,
      roleCandidates: [_buildCandidacy(id: "candidacy-1", roleId: "role-1", firstName: "Camille")],
      roleById: {"role-1": _buildRole(id: "role-1", name: "MARIE")},
    );

    final tr = Tr.of(tester.element(find.byType(OcptScheduleCandidatePickerDialog)));
    await tester.tap(find.text(tr.scheduleCandidatePickerCancelAction));
    await tester.pumpAndSettle();

    expect(routerManager.popped, isTrue);
    expect(routerManager.poppedValue, isNull);
  });
}
