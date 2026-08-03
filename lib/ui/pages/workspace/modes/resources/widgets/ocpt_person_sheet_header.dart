// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/types/ocpt_person_editable_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_person_sheet_avatar.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_person_sheet_date_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_person_sheet_field.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_warning_color.dart';

/// The person sheet's header: the photo slot on the left, and on the right the display name (as
/// two adjoining, title-styled fields — `person.displayName` is derived from `firstName` and
/// `lastName`, so there is no single stored field a mock-up's own single name field could bind
/// to), the minor badge, and the two-column contact grid.
///
/// [OcptPerson.birthDate] has no field of its own in the mock-up (only the age it derives is
/// shown, in the minor badge): this header is where it is decided to live, right after the
/// contact fields, since nowhere else in the sheet is a more natural home for it and the minor
/// badge next to the name depends on it.
class OcptPersonSheetHeader extends StatelessWidget {
  /// The person this header shows.
  final OcptPerson person;

  /// [person]'s current value for `field`: a pending edit still in the bloc's debounce, or the
  /// person's own stored value.
  final String Function(OcptPersonField field) fieldValueOf;

  /// Called with a field's raw text on every keystroke, or null while the sheet may not be
  /// written to.
  final void Function(OcptPersonField field, String rawValue)? onFieldChanged;

  /// Called with the palette index picked from the avatar's colour popover, or null while it may
  /// not be changed.
  final ValueChanged<int>? onColorChanged;

  /// Called with the newly picked date of birth (or null to clear it), or null while it may not be
  /// changed.
  final ValueChanged<DateTime?>? onBirthDateChanged;

  /// Class constructor
  const OcptPersonSheetHeader({
    super.key,
    required this.person,
    required this.fieldValueOf,
    required this.onFieldChanged,
    required this.onColorChanged,
    required this.onBirthDateChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final age = person.age;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OcptPersonSheetAvatar(person: person, onColorChanged: onColorChanged),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: OcptPersonSheetField(
                      personId: person.id,
                      label: "",
                      value: fieldValueOf(OcptPersonField.firstName),
                      hintText: tr.resourcesFirstNameHint,
                      textStyle: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                      onChanged: _onFieldChangedOrNull(OcptPersonField.firstName),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OcptPersonSheetField(
                      personId: person.id,
                      label: "",
                      value: fieldValueOf(OcptPersonField.lastName),
                      hintText: tr.resourcesLastNameHint,
                      textStyle: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                      onChanged: _onFieldChangedOrNull(OcptPersonField.lastName),
                    ),
                  ),
                  if (person.isMinor == true && age != null) ...[
                    const SizedBox(width: 8),
                    _buildMinorBadge(context, age),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              _buildContactGrid(context, tr),
            ],
          ),
        ),
      ],
    );
  }

  /// The `Minor · {age}` badge, tinted with the workspace's warning colour.
  Widget _buildMinorBadge(BuildContext context, int age) {
    final theme = Theme.of(context);
    final color = ocptWarningColor(context);

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          Tr.of(context).resourcesMinorBadge(age),
          style: theme.textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  /// The contact grid: email and phone, then the two address lines full width, then the postal
  /// code beside the city and the region beside the country, and last the date of birth.
  ///
  /// The address is laid out in the order an international address form uses (street, then the
  /// locality, then the administrative levels above it) rather than in any one country's own
  /// printing order: `OcptPeopleTable.addressLine1`'s doc comment is where the six-column shape is
  /// argued, and printing an address for a given country is a call sheet's job, not a form's.
  Widget _buildContactGrid(BuildContext context, Tr tr) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _buildFieldRow(
        first: _buildTextField(tr.resourcesEmailLabel, OcptPersonField.email),
        second: _buildTextField(tr.resourcesPhoneLabel, OcptPersonField.phone),
      ),
      const SizedBox(height: 10),
      _buildTextField(tr.resourcesAddressLine1Label, OcptPersonField.addressLine1),
      const SizedBox(height: 10),
      _buildTextField(tr.resourcesAddressLine2Label, OcptPersonField.addressLine2),
      const SizedBox(height: 10),
      _buildFieldRow(
        first: _buildTextField(tr.resourcesPostalCodeLabel, OcptPersonField.postalCode),
        second: _buildTextField(tr.resourcesCityLabel, OcptPersonField.city),
      ),
      const SizedBox(height: 10),
      _buildFieldRow(
        first: _buildTextField(tr.resourcesRegionLabel, OcptPersonField.region),
        second: _buildTextField(tr.resourcesCountryLabel, OcptPersonField.country),
      ),
      const SizedBox(height: 10),
      _buildFieldRow(
        first: OcptPersonSheetDateField(
          label: tr.resourcesBirthDateLabel,
          value: person.birthDate,
          onChanged: onBirthDateChanged,
        ),
        second: const SizedBox.shrink(),
      ),
    ],
  );

  /// One field of the contact grid.
  Widget _buildTextField(String label, OcptPersonField field) => OcptPersonSheetField(
    personId: person.id,
    label: label,
    value: fieldValueOf(field),
    onChanged: _onFieldChangedOrNull(field),
  );

  /// Two fields of the contact grid, side by side and equally wide.
  Widget _buildFieldRow({required Widget first, required Widget second}) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: first),
      const SizedBox(width: 16),
      Expanded(child: second),
    ],
  );

  /// The `onChanged` a field of [field] is given: the one reporting to [onFieldChanged], or null
  /// while the sheet may not be written to, which is what makes the field read out its value
  /// instead of accepting a new one.
  ValueChanged<String>? _onFieldChangedOrNull(OcptPersonField field) {
    final onFieldChanged = this.onFieldChanged;
    if (onFieldChanged == null) {
      return null;
    }
    return (value) => onFieldChanged(field, value);
  }
}
