// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_asset_ref.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_mileage_rate.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_person_position.dart';
import 'package:open_cine_prod_tools/models/ocpt_person_skill.dart';
import 'package:open_cine_prod_tools/models/ocpt_person_unavailability.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_max_daily_presence.dart';
import 'package:open_cine_prod_tools/types/ocpt_day_part_slot.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_person_editable_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_person_sheet.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_sheet_field.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_budget_labels.dart';

/// Builds a minimal [OcptPerson] for these tests, every free-text field left blank except the ones
/// a case cares about.
OcptPerson testPerson({
  String id = "p1",
  String firstName = "",
  String lastName = "",
  String email = "",
  int colorIndex = 0,
  DateTime? birthDate,
  String minorNotes = "",
  int? maxDailyPresenceMinutes,
  bool? isTransportAutonomous,
  int? commuteKmMilli,
  String? mileageRateId,
  String accommodationNotes = "",
  String travelNotes = "",
  String dietaryNotes = "",
  String allergies = "",
  String measurementHeight = "",
  String measurementChest = "",
  String measurementWaist = "",
  String measurementHips = "",
  String sizeTop = "",
  String sizeBottom = "",
  String sizeShoes = "",
  String hmcNotes = "",
  OcptImageRightsStatus imageRightsStatus = OcptImageRightsStatus.notApplicable,
  DateTime? imageRightsDate,
  OcptAssetRef? photo,
  OcptAssetRef? imageRightsDocument,
  String notes = "",
  List<OcptPersonPosition> positions = const [],
  List<OcptPersonSkill> skills = const [],
  List<OcptPersonUnavailability> unavailabilities = const [],
}) => OcptPerson(
  id: id,
  firstName: firstName,
  lastName: lastName,
  email: email,
  phone: "",
  addressLine1: "",
  addressLine2: "",
  postalCode: "",
  city: "",
  region: "",
  country: "",
  colorIndex: colorIndex,
  birthDate: birthDate,
  minorNotes: minorNotes,
  maxDailyPresenceMinutes: maxDailyPresenceMinutes,
  isTransportAutonomous: isTransportAutonomous,
  accommodationNotes: accommodationNotes,
  travelNotes: travelNotes,
  dietaryNotes: dietaryNotes,
  allergies: allergies,
  measurementHeight: measurementHeight,
  measurementChest: measurementChest,
  measurementWaist: measurementWaist,
  measurementHips: measurementHips,
  sizeTop: sizeTop,
  sizeBottom: sizeBottom,
  sizeShoes: sizeShoes,
  hmcNotes: hmcNotes,
  imageRightsStatus: imageRightsStatus,
  imageRightsDate: imageRightsDate,
  imageRightsAssetId: imageRightsDocument?.id,
  imageRightsDocument: imageRightsDocument,
  photoAssetId: photo?.id,
  photo: photo,
  notes: notes,
  commuteKmMilli: commuteKmMilli,
  mileageRateId: mileageRateId,
  positions: positions,
  skills: skills,
  unavailabilities: unavailabilities,
);

/// [person]'s current value for [field], mirroring `OcptResourcesMode.fieldValueOf` with no
/// pending edits (these tests have no bloc of their own).
String fieldValueOf(OcptPerson person, OcptPersonField field) => switch (field) {
  OcptPersonField.firstName => person.firstName,
  OcptPersonField.lastName => person.lastName,
  OcptPersonField.email => person.email,
  OcptPersonField.phone => person.phone,
  OcptPersonField.addressLine1 => person.addressLine1,
  OcptPersonField.addressLine2 => person.addressLine2,
  OcptPersonField.postalCode => person.postalCode,
  OcptPersonField.city => person.city,
  OcptPersonField.region => person.region,
  OcptPersonField.country => person.country,
  OcptPersonField.minorNotes => person.minorNotes,
  OcptPersonField.maxDailyPresenceMinutes => ocptMaxDailyPresenceTextOf(
    person.maxDailyPresenceMinutes,
  ),
  OcptPersonField.commuteKmMilli =>
    person.commuteKmMilli == null ? "" : ocptBudgetQuantityLabel(person.commuteKmMilli!),
  OcptPersonField.accommodationNotes => person.accommodationNotes,
  OcptPersonField.travelNotes => person.travelNotes,
  OcptPersonField.dietaryNotes => person.dietaryNotes,
  OcptPersonField.allergies => person.allergies,
  OcptPersonField.measurementHeight => person.measurementHeight,
  OcptPersonField.measurementChest => person.measurementChest,
  OcptPersonField.measurementWaist => person.measurementWaist,
  OcptPersonField.measurementHips => person.measurementHips,
  OcptPersonField.sizeTop => person.sizeTop,
  OcptPersonField.sizeBottom => person.sizeBottom,
  OcptPersonField.sizeShoes => person.sizeShoes,
  OcptPersonField.hmcNotes => person.hmcNotes,
  OcptPersonField.notes => person.notes,
};

/// The navigator [wrapInApp] mounts, so [RecordingRouterManager.pop] can close a dialog opened
/// through `showDialog` (the crew position picker) exactly as the real `GoRouter.pop` would —
/// both push onto the very same root `Navigator`. Mirrors `ocpt_schedule_slot_card_test.dart`'s
/// own instance of the same pattern.
final navigatorKey = GlobalKey<NavigatorState>();

/// A router manager whose [pop] pops [navigatorKey]'s own navigator, so a dialog opened through
/// `showDialog` genuinely closes: the positions card resolves its router manager from
/// `globalGetIt()`, with no real GoRouter for `pop` to delegate to.
class RecordingRouterManager extends OcptRouterManager {
  @override
  void pop<Y extends Object?>([Y? result]) {
    final navigator = navigatorKey.currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.pop(result);
    }
  }
}

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve.
Widget wrapInApp(Widget child) => MaterialApp(
  navigatorKey: navigatorKey,
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: SizedBox(width: 700, child: child)),
);

/// Grows the test surface tall enough that the whole (long, scrolling) sheet is built and
/// hit-testable without having to scroll it, restoring the default size once the test ends.
Future<void> useTallSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(700, 2600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

/// The [Finder] of the text field labelled [label] (its uppercased display label, e.g. `"EMAIL"`),
/// mirroring `OcptShotInspectorPanel`'s own test helper: the label and the field are siblings
/// inside one `OcptResourcesSheetField`, so the field is found as its descendant rather than
/// through the label directly.
Finder fieldOf(String label) => find.descendant(
  of: find.ancestor(of: find.text(label), matching: find.byType(OcptResourcesSheetField)),
  matching: find.byType(TextField),
);

/// Builds a sheet for [person], recording every callback into the maps/lists a test reads back.
/// Every callback but `onFieldChanged` and `onDeleteRequested` is a plain recorder: the specific
/// fields these tests care about are covered individually.
Widget buildSheet({
  required OcptPerson person,
  bool isReadOnly = false,
  void Function(OcptPersonField field, String rawValue)? onFieldChanged,
  VoidCallback? onPositionAdded,
  void Function(String id, {required String positionId, required String customLabel})?
  onPositionUpdated,
  ValueChanged<String>? onPositionRemoved,
  ValueChanged<String>? onSkillAdded,
  ValueChanged<String>? onSkillRemoved,
  void Function({
    required DateTime startDate,
    required DateTime endDate,
    required OcptDayPartSlot slot,
    required int? startMinute,
    required int? endMinute,
  })?
  onUnavailabilityAdded,
  void Function(
    String id, {
    required DateTime startDate,
    required DateTime endDate,
    required OcptDayPartSlot slot,
    required int? startMinute,
    required int? endMinute,
    required String reason,
  })?
  onUnavailabilityUpdated,
  ValueChanged<String>? onUnavailabilityRemoved,
  ValueChanged<int>? onColorChanged,
  VoidCallback? onPhotoPickRequested,
  VoidCallback? onPhotoCleared,
  VoidCallback? onImageRightsDocumentPickRequested,
  VoidCallback? onImageRightsDocumentCleared,
  List<OcptBudgetMileageRate> mileageRates = const [],
  ValueChanged<String?>? onMileageRateChanged,
  VoidCallback? onDeleteRequested,
}) => wrapInApp(
  OcptPersonSheet(
    person: person,
    isReadOnly: isReadOnly,
    fieldValueOf: (field) => fieldValueOf(person, field),
    onFieldChanged: onFieldChanged ?? (_, __) {},
    onColorChanged: onColorChanged ?? (_) {},
    onPhotoPickRequested: onPhotoPickRequested ?? () {},
    onPhotoCleared: onPhotoCleared ?? () {},
    onImageRightsDocumentPickRequested: onImageRightsDocumentPickRequested ?? () {},
    onImageRightsDocumentCleared: onImageRightsDocumentCleared ?? () {},
    onBirthDateChanged: (_) {},
    onTransportAutonomyChanged: (_) {},
    onImageRightsStatusChanged: (_) {},
    onImageRightsDateChanged: (_) {},
    mileageRates: mileageRates,
    onMileageRateChanged: onMileageRateChanged ?? (_) {},
    onPositionAdded: onPositionAdded ?? () {},
    onPositionUpdated: onPositionUpdated ?? (id, {required positionId, required customLabel}) {},
    onPositionRemoved: onPositionRemoved ?? (_) {},
    onSkillAdded: onSkillAdded ?? (_) {},
    onSkillRemoved: onSkillRemoved ?? (_) {},
    onUnavailabilityAdded:
        onUnavailabilityAdded ??
        ({
          required startDate,
          required endDate,
          required slot,
          required startMinute,
          required endMinute,
        }) {},
    onUnavailabilityUpdated:
        onUnavailabilityUpdated ??
        (
          id, {
          required startDate,
          required endDate,
          required slot,
          required startMinute,
          required endMinute,
          required reason,
        }) {},
    onUnavailabilityRemoved: onUnavailabilityRemoved ?? (_) {},
    onDeleteRequested: onDeleteRequested ?? () {},
  ),
);
