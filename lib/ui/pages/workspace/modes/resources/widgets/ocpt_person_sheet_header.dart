// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_email_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_person_editable_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_person_sheet_avatar.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_person_sheet_date_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_sheet_field.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_warning_color.dart';

/// The person sheet's header: the photo slot on the left (see [OcptPersonSheetAvatar], which is
/// where referencing a photo and picking the fallback colour both live), and on the right the
/// display name (as
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

  /// Called with the palette index picked from the photo slot's colour grid, or null while it may
  /// not be changed.
  final ValueChanged<int>? onColorChanged;

  /// Called when the photo slot's reference entry is picked, or null while it may not be used.
  final VoidCallback? onPhotoPickRequested;

  /// Called when the photo slot's remove entry is picked, or null while it may not be used.
  final VoidCallback? onPhotoCleared;

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
    required this.onPhotoPickRequested,
    required this.onPhotoCleared,
    required this.onBirthDateChanged,
  });

  /// Build the person sheet header as a [Row].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final age = person.age;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OcptPersonSheetAvatar(
          person: person,
          onColorChanged: onColorChanged,
          onPhotoPickRequested: onPhotoPickRequested,
          onPhotoCleared: onPhotoCleared,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: OcptResourcesSheetField(
                      ownerId: person.id,
                      label: "",
                      value: fieldValueOf(OcptPersonField.firstName),
                      hintText: tr.resourcesFirstNameHint,
                      textStyle: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      onChanged: _onFieldChangedOrNull(OcptPersonField.firstName),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OcptResourcesSheetField(
                      ownerId: person.id,
                      label: "",
                      value: fieldValueOf(OcptPersonField.lastName),
                      hintText: tr.resourcesLastNameHint,
                      textStyle: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      onChanged: _onFieldChangedOrNull(OcptPersonField.lastName),
                    ),
                  ),
                  if (person.isMinor == true && age != null) ...[
                    const SizedBox(width: 8),
                    _MinorBadge(age: age),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              _ContactGrid(header: this),
            ],
          ),
        ),
      ],
    );
  }

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

/// The `Minor · {age}` badge, tinted with the workspace's warning colour.
class _MinorBadge extends StatelessWidget {
  /// The person's age in years.
  final int age;

  /// Class constructor
  const _MinorBadge({required this.age});

  /// Build the minor badge as a [Padding].
  @override
  Widget build(BuildContext context) {
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
}

/// Two fields of the contact grid, side by side and equally wide.
class _FieldRow extends StatelessWidget {
  /// The field on the left.
  final Widget first;

  /// The field on the right.
  final Widget second;

  /// Class constructor
  const _FieldRow({required this.first, required this.second});

  /// Build the field row as a [Row].
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: first),
      const SizedBox(width: 16),
      Expanded(child: second),
    ],
  );
}

/// One field of the contact grid, optionally checked by [errorTextOf] once it loses the focus.
class _TextField extends StatelessWidget {
  /// The widget this one belongs to.
  final OcptPersonSheetHeader header;

  /// The field's label.
  final String label;

  /// The field this one writes.
  final OcptPersonField field;

  /// Checks the field once it loses the focus, or null for no check.
  final String? Function(String value)? errorTextOf;

  /// Class constructor
  const _TextField({
    required this.header,
    required this.label,
    required this.field,
    this.errorTextOf,
  });

  /// Build the text field as an [OcptResourcesSheetField].
  @override
  Widget build(BuildContext context) => OcptResourcesSheetField(
    ownerId: header.person.id,
    label: label,
    value: header.fieldValueOf(field),
    errorTextOf: errorTextOf,
    onChanged: header._onFieldChangedOrNull(field),
  );
}

/// The contact grid: email and phone, then the two address lines full width, then the postal
/// code beside the city and the region beside the country, and last the date of birth.
///
/// The address is laid out in the order an international address form uses (street, then the
/// locality, then the administrative levels above it) rather than in any one country's own
/// printing order: `OcptPeopleTable.addressLine1`'s doc comment is where the six-column shape is
/// argued, and printing an address for a given country is a call sheet's job, not a form's.
class _ContactGrid extends StatelessWidget {
  /// The widget this one belongs to.
  final OcptPersonSheetHeader header;

  /// Class constructor
  const _ContactGrid({required this.header});

  /// Build the contact grid as a [Column].
  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldRow(
          first: _TextField(
            header: header,
            label: tr.resourcesEmailLabel,
            field: OcptPersonField.email,
            errorTextOf: (value) =>
                ocptEmailLooksWellFormed(value) ? null : tr.resourcesEmailMalformedError,
          ),
          second: _TextField(
            header: header,
            label: tr.resourcesPhoneLabel,
            field: OcptPersonField.phone,
          ),
        ),
        const SizedBox(height: 10),
        _TextField(
          header: header,
          label: tr.resourcesAddressLine1Label,
          field: OcptPersonField.addressLine1,
        ),
        const SizedBox(height: 10),
        _TextField(
          header: header,
          label: tr.resourcesAddressLine2Label,
          field: OcptPersonField.addressLine2,
        ),
        const SizedBox(height: 10),
        _FieldRow(
          first: _TextField(
            header: header,
            label: tr.resourcesPostalCodeLabel,
            field: OcptPersonField.postalCode,
          ),
          second: _TextField(
            header: header,
            label: tr.resourcesCityLabel,
            field: OcptPersonField.city,
          ),
        ),
        const SizedBox(height: 10),
        _FieldRow(
          first: _TextField(
            header: header,
            label: tr.resourcesRegionLabel,
            field: OcptPersonField.region,
          ),
          second: _TextField(
            header: header,
            label: tr.resourcesCountryLabel,
            field: OcptPersonField.country,
          ),
        ),
        const SizedBox(height: 10),
        _FieldRow(
          first: OcptPersonSheetDateField(
            label: tr.resourcesBirthDateLabel,
            value: header.person.birthDate,
            onChanged: header.onBirthDateChanged,
          ),
          second: const SizedBox.shrink(),
        ),
      ],
    );
  }
}
