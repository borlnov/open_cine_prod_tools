// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/types/ocpt_location_editable_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_sheet_card.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_sheet_field.dart';

/// The sentinel the contact picker uses for its entry that clears the contact, never a real person
/// id.
const String _noContactOption = "";

/// "Address and access": the location's postal address in the six fields an address is made of, its
/// GPS coordinates, and who to contact about it.
///
/// The six address fields are `people`'s own (decision 10 of the plan this ships under): an address
/// has one shape wherever it appears, and a call sheet prints a location's exactly as it prints a
/// person's.
///
/// The contact is a **person of the address book**, not a name typed again: the owner of a location
/// is someone the production already has a phone number for, and their sheet is one click away
/// through the same `↗` the role sheet's cast member line carries. Their phone and email are read
/// there rather than repeated here — one place holds a person's contact details, and it is their
/// own sheet.
class OcptLocationSheetAddressCard extends StatelessWidget {
  /// The id of the location this card belongs to.
  final String locationId;

  /// The person to contact about this location, or null while there is none.
  final OcptPerson? contact;

  /// The whole address book, offered by the contact picker.
  final List<OcptPerson> people;

  /// The location's current value for `field`.
  final String Function(OcptLocationField field) fieldValueOf;

  /// Called with a field's raw text on every keystroke, or null while the sheet may not be written
  /// to.
  final void Function(OcptLocationField field, String rawValue)? onFieldChanged;

  /// Called with the person now to contact, or null to clear it; itself null while the contact may
  /// not be changed.
  final ValueChanged<String?>? onContactChanged;

  /// Called with the contact's id when their line is clicked. Never null: reading a person's sheet
  /// is not a write.
  final ValueChanged<String> onPersonSheetOpenRequested;

  /// Class constructor
  const OcptLocationSheetAddressCard({
    super.key,
    required this.locationId,
    required this.contact,
    required this.people,
    required this.fieldValueOf,
    required this.onFieldChanged,
    required this.onContactChanged,
    required this.onPersonSheetOpenRequested,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return OcptResourcesSheetCard(
      title: tr.resourcesLocationAddressCardTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _field(context, OcptLocationField.addressLine1, tr.resourcesAddressLine1Label),
          const SizedBox(height: 8),
          _field(context, OcptLocationField.addressLine2, tr.resourcesAddressLine2Label),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _field(context, OcptLocationField.postalCode, tr.resourcesPostalCodeLabel),
              ),
              const SizedBox(width: 10),
              Expanded(flex: 2, child: _field(context, OcptLocationField.city, tr.resourcesCityLabel)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _field(context, OcptLocationField.region, tr.resourcesRegionLabel)),
              const SizedBox(width: 10),
              Expanded(child: _field(context, OcptLocationField.country, tr.resourcesCountryLabel)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _field(
                  context,
                  OcptLocationField.latitude,
                  tr.resourcesLatitudeLabel,
                  errorTextOf: (value) => _coordinateErrorOf(tr, value),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _field(
                  context,
                  OcptLocationField.longitude,
                  tr.resourcesLongitudeLabel,
                  errorTextOf: (value) => _coordinateErrorOf(tr, value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildContactPicker(context, tr),
          const SizedBox(height: 8),
          _field(context, OcptLocationField.contactNotes, tr.resourcesLocationContactNotesLabel),
        ],
      ),
    );
  }

  /// One text field of the card, labelled [label] and writing [field].
  Widget _field(
    BuildContext context,
    OcptLocationField field,
    String label, {
    String? Function(String value)? errorTextOf,
  }) {
    final onFieldChanged = this.onFieldChanged;

    return OcptResourcesSheetField(
      ownerId: locationId,
      label: label,
      value: fieldValueOf(field),
      errorTextOf: errorTextOf,
      onChanged: onFieldChanged == null ? null : (value) => onFieldChanged(field, value),
    );
  }

  /// What is wrong with the coordinate [value], or null when there is nothing to say about it.
  ///
  /// A **remark, never a gate** (decision 11 of the plan this ships under, the rule the email field
  /// already follows): the value is written either way — as no coordinate at all, since a location
  /// half-way through being pinned is not at 45 degrees north of nowhere — and the field says so
  /// once it loses the focus. An empty field is not an error: most locations are never pinned.
  String? _coordinateErrorOf(Tr tr, String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || double.tryParse(trimmed) != null) {
      return null;
    }

    return tr.resourcesCoordinateFormatError;
  }

  /// Builds the contact line: a label over a badge doubling as a [PopupMenuButton] over the whole
  /// address book, and — once a contact is set — the `↗` opening their own sheet.
  Widget _buildContactPicker(BuildContext context, Tr tr) {
    final theme = Theme.of(context);
    final contact = this.contact;
    final onContactChanged = this.onContactChanged;
    final currentLabel = contact == null
        ? tr.resourcesLocationNoContact
        : (contact.displayName.isEmpty ? tr.resourcesUnnamedPerson : contact.displayName);

    final badge = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            currentLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              fontStyle: contact == null ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ),
        if (onContactChanged != null) ...[
          const SizedBox(width: 4),
          Icon(Icons.arrow_drop_down, size: 16, color: theme.colorScheme.onSurfaceVariant),
        ],
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr.resourcesLocationContactLabel.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            if (onContactChanged == null)
              Flexible(child: badge)
            else
              Flexible(
                child: PopupMenuButton<String>(
                  tooltip: "",
                  onSelected: (value) =>
                      onContactChanged(value == _noContactOption ? null : value),
                  itemBuilder: (context) => [
                    PopupMenuItem<String>(
                      value: _noContactOption,
                      child: Text(tr.resourcesLocationNoContact),
                    ),
                    const PopupMenuDivider(),
                    for (final person in people)
                      PopupMenuItem<String>(
                        value: person.id,
                        child: Text(
                          person.displayName.isEmpty
                              ? tr.resourcesUnnamedPerson
                              : person.displayName,
                        ),
                      ),
                  ],
                  child: badge,
                ),
              ),
            if (contact != null) ...[
              const SizedBox(width: 6),
              Tooltip(
                message: tr.resourcesOpenPersonSheetTooltip,
                child: InkWell(
                  onTap: () => onPersonSheetOpenRequested(contact.id),
                  mouseCursor: ocptClickableCursor,
                  borderRadius: BorderRadius.circular(ocptRadiusSmall),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.north_east, size: 14),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
