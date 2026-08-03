// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_location.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_scene_ref.dart';
import 'package:open_cine_prod_tools/types/ocpt_day_part_slot.dart';
import 'package:open_cine_prod_tools/types/ocpt_location_availability_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_location_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_permit_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_set_editable_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_location_sheet_address_card.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_location_sheet_availabilities_card.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_location_sheet_header.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_location_sheet_permit_card.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_location_sheet_photos_card.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_location_sheet_sets_card.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_delete_action.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_sheet_card.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_sheet_field.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_warning_color.dart';

/// The share of the sheet's top row the address card takes, against the permit card's own — the
/// mock-up's `1.3fr 1fr`, expressed as the two integers a [Row]'s flex takes.
const int _addressCardFlex = 13;

/// The share of the sheet's top row the permit card takes. See [_addressCardFlex].
const int _permitCardFlex = 10;

/// The resources mode's centre, once a location is selected: the whole location sheet, a single
/// scrolling column edited in place — the header (colour, name, permit status), the address and
/// permit cards side by side, the sets of the location and the scenes shot in them, the three
/// logistics cards (parking, power, facilities), the noise-and-schedule constraints callout, the
/// scouting photos, the notes, and `Delete this location` at the very bottom.
///
/// It is `OcptPersonSheet`'s and `OcptRoleSheet`'s sibling and follows the same grammar: the tabs of
/// the resources mode all answer one gesture — pick a record on the left, edit it in the centre —
/// so they share the header-then-cards shape and the same card and field chrome
/// (`OcptResourcesSheetCard`, `OcptResourcesSheetField`).
///
/// The three logistics cards sit in one row because that is the shape of the question they answer
/// together: where the truck goes, what amperage exists, and whether there is a toilet decide
/// between them whether a day is shootable here. The constraints are a callout rather than a fourth
/// card for the same reason the minor callout is one — what the neighbours will tolerate is a
/// warning, not a note.
///
/// The mock-up's "Shooting days on this location" section is schedule data and is out of scope
/// here entirely, exactly as the person sheet's own "Days of presence" is.
///
/// Every callback is always given by the caller (the mode always has a location selected while this
/// widget is built); [isReadOnly] is what this widget uses to null every one of them out before
/// handing it to the part that owns the affordance, so a field added later cannot be gated in one
/// place and forgotten in the other.
class OcptLocationSheet extends StatelessWidget {
  /// The location this sheet shows.
  final OcptLocation location;

  /// The person to contact about [location], or null while there is none.
  final OcptPerson? contact;

  /// The whole address book, offered by the contact picker.
  final List<OcptPerson> people;

  /// Every scene of the project's screenplay, in source order, offered by the sets card's own
  /// scene picker.
  final List<OcptSceneRef> scenes;

  /// The ids of the scenes already shot in some set, this location's or another's.
  final Set<String> assignedSceneIds;

  /// The id of the set each scene is suggested for, keyed by scene id.
  final Map<String, String> suggestedSetIdBySceneId;

  /// Whether what the mode shows is a project version being previewed read-only, which no callback
  /// of this sheet may write through.
  final bool isReadOnly;

  /// [location]'s current value for `field`: a pending edit still in the bloc's debounce, or the
  /// location's own stored value.
  final String Function(OcptLocationField field) fieldValueOf;

  /// Called with a field's raw text on every keystroke.
  final void Function(OcptLocationField field, String rawValue) onFieldChanged;

  /// Called with the palette index picked from the header's colour bar.
  final ValueChanged<int> onColorChanged;

  /// Called with the permit status picked from the header's badge.
  final ValueChanged<OcptPermitStatus> onPermitStatusChanged;

  /// Called with the newly picked permit date, or null to clear it.
  final ValueChanged<DateTime?> onPermitDateChanged;

  /// Called with the person now to contact, or null to clear it.
  final ValueChanged<String?> onContactChanged;

  /// Called with a person's id when the contact's `↗` is clicked.
  final ValueChanged<String> onPersonSheetOpenRequested;

  /// A set's current value for `field`: a pending edit still in the bloc's debounce, or the set's
  /// own stored value.
  final String Function(String setId, OcptSetField field) setFieldValueOf;

  /// Called with a set field's raw text on every keystroke.
  final void Function(String setId, OcptSetField field, String rawValue) onSetFieldChanged;

  /// Called when a set is added to this location.
  final VoidCallback onSetAdded;

  /// Called with a set's id when its remove control is clicked.
  final ValueChanged<String> onSetRemoved;

  /// Called with a scene and the set it is now shot in.
  final void Function(String sceneId, String setId) onSceneAssigned;

  /// Called with a scene and the set it is no longer shot in.
  final void Function(String sceneId, String setId) onSceneRemoved;

  /// Called when a scouting photo is to be referenced.
  final VoidCallback onPhotoAddRequested;

  /// Called with a photo's asset id when its remove control is clicked.
  final ValueChanged<String> onPhotoRemoved;

  /// Called when the permit document is to be referenced or replaced.
  final VoidCallback onPermitDocumentPickRequested;

  /// Called when the permit document's reference is to be dropped.
  final VoidCallback onPermitDocumentCleared;

  /// Called with an availability window's id and its fields once one of them changed.
  final void Function(
    String id, {
    required DateTime startDate,
    required DateTime endDate,
    required int weekdays,
    required OcptDayPartSlot slot,
    required int? startMinute,
    required int? endMinute,
    required OcptLocationAvailabilityKind kind,
    required String note,
  })
  onAvailabilityUpdated;

  /// Called with a new availability window's whole shape.
  final void Function({
    required DateTime startDate,
    required DateTime endDate,
    required int weekdays,
    required OcptDayPartSlot slot,
    required int? startMinute,
    required int? endMinute,
  })
  onAvailabilityAdded;

  /// Called with an availability window's id when its remove control is clicked.
  final ValueChanged<String> onAvailabilityRemoved;

  /// Called once the inline delete confirmation is answered `Delete`.
  final VoidCallback onDeleteRequested;

  /// Class constructor
  const OcptLocationSheet({
    super.key,
    required this.location,
    required this.contact,
    required this.people,
    required this.scenes,
    required this.assignedSceneIds,
    required this.suggestedSetIdBySceneId,
    this.isReadOnly = false,
    required this.fieldValueOf,
    required this.onFieldChanged,
    required this.onColorChanged,
    required this.onPermitStatusChanged,
    required this.onPermitDateChanged,
    required this.onContactChanged,
    required this.onPersonSheetOpenRequested,
    required this.setFieldValueOf,
    required this.onSetFieldChanged,
    required this.onSetAdded,
    required this.onSetRemoved,
    required this.onSceneAssigned,
    required this.onSceneRemoved,
    required this.onPhotoAddRequested,
    required this.onPhotoRemoved,
    required this.onPermitDocumentPickRequested,
    required this.onPermitDocumentCleared,
    required this.onAvailabilityUpdated,
    required this.onAvailabilityAdded,
    required this.onAvailabilityRemoved,
    required this.onDeleteRequested,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(26, 20, 26, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OcptLocationSheetHeader(
            location: location,
            fieldValueOf: fieldValueOf,
            onFieldChanged: isReadOnly ? null : onFieldChanged,
            onColorChanged: isReadOnly ? null : onColorChanged,
            onPermitStatusChanged: isReadOnly ? null : onPermitStatusChanged,
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: _addressCardFlex,
                child: OcptLocationSheetAddressCard(
                  locationId: location.id,
                  contact: contact,
                  people: people,
                  fieldValueOf: fieldValueOf,
                  onFieldChanged: isReadOnly ? null : onFieldChanged,
                  onContactChanged: isReadOnly ? null : onContactChanged,
                  onPersonSheetOpenRequested: onPersonSheetOpenRequested,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: _permitCardFlex,
                child: OcptLocationSheetPermitCard(
                  locationId: location.id,
                  permitDate: location.permitDate,
                  permitDocument: location.permitDocument,
                  fieldValueOf: fieldValueOf,
                  onFieldChanged: isReadOnly ? null : onFieldChanged,
                  onPermitDateChanged: isReadOnly ? null : onPermitDateChanged,
                  onPermitDocumentPickRequested: isReadOnly ? null : onPermitDocumentPickRequested,
                  onPermitDocumentCleared: isReadOnly ? null : onPermitDocumentCleared,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OcptLocationSheetSetsCard(
            sets: location.sets,
            scenes: scenes,
            assignedSceneIds: assignedSceneIds,
            suggestedSetIdBySceneId: suggestedSetIdBySceneId,
            fieldValueOf: setFieldValueOf,
            onSetFieldChanged: isReadOnly ? null : onSetFieldChanged,
            onSetAdded: isReadOnly ? null : onSetAdded,
            onSetRemoved: isReadOnly ? null : onSetRemoved,
            onSceneAssigned: isReadOnly ? null : onSceneAssigned,
            onSceneRemoved: isReadOnly ? null : onSceneRemoved,
          ),
          const SizedBox(height: 12),
          _buildLogisticsRow(context, tr),
          const SizedBox(height: 12),
          OcptLocationSheetAvailabilitiesCard(
            availabilities: location.availabilities,
            onUpdated: isReadOnly ? null : onAvailabilityUpdated,
            onRemoved: isReadOnly ? null : onAvailabilityRemoved,
            onAdded: isReadOnly ? null : onAvailabilityAdded,
          ),
          const SizedBox(height: 12),
          _buildConstraintsCallout(context, tr),
          const SizedBox(height: 12),
          OcptLocationSheetPhotosCard(
            photos: location.photos,
            onPhotoAddRequested: isReadOnly ? null : onPhotoAddRequested,
            onPhotoRemoved: isReadOnly ? null : onPhotoRemoved,
          ),
          const SizedBox(height: 12),
          OcptResourcesSheetCard(
            title: tr.resourcesNotesTitle,
            child: _buildNotesField(OcptLocationField.notes, null),
          ),
          if (!isReadOnly) ...[
            const SizedBox(height: 20),
            OcptResourcesDeleteAction(
              ownerId: location.id,
              label: tr.resourcesLocationDeleteAction,
              confirmMessage: tr.resourcesLocationDeleteConfirmMessage,
              onDeleteRequested: onDeleteRequested,
            ),
          ],
        ],
      ),
    );
  }

  /// The row of the three logistics cards: parking, power, facilities.
  Widget _buildLogisticsRow(BuildContext context, Tr tr) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: OcptResourcesSheetCard(
          title: tr.resourcesLocationParkingTitle,
          child: _buildNotesField(OcptLocationField.parkingNotes, tr.resourcesLocationParkingHint),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: OcptResourcesSheetCard(
          title: tr.resourcesLocationPowerTitle,
          child: _buildNotesField(OcptLocationField.powerNotes, tr.resourcesLocationPowerHint),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: OcptResourcesSheetCard(
          title: tr.resourcesLocationFacilitiesTitle,
          child: _buildNotesField(
            OcptLocationField.facilitiesNotes,
            tr.resourcesLocationFacilitiesHint,
          ),
        ),
      ),
    ],
  );

  /// The warning-tinted callout holding what the neighbours and the town hall will tolerate, built
  /// exactly as the person sheet's own legal-hours callout is.
  Widget _buildConstraintsCallout(BuildContext context, Tr tr) {
    final theme = Theme.of(context);
    final color = ocptWarningColor(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(ocptRadiusLarge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr.resourcesLocationConstraintsTitle,
            style: theme.textTheme.labelLarge?.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          _buildNotesField(
            OcptLocationField.constraintsNotes,
            tr.resourcesLocationConstraintsHint,
          ),
        ],
      ),
    );
  }

  /// One multi-line field of the sheet, writing [field] and hinted with [hintText].
  Widget _buildNotesField(OcptLocationField field, String? hintText) => OcptResourcesSheetField(
    ownerId: location.id,
    label: "",
    value: fieldValueOf(field),
    multiline: true,
    hintText: hintText,
    onChanged: isReadOnly ? null : (value) => onFieldChanged(field, value),
  );
}
