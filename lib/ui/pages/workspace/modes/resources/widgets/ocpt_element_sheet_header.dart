// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_breakdown_palette.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart' as ocpt_theme;
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_element.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_editable_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_code_read_out.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_photo_slot.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_sheet_field.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_decimal_input.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_resources_labels.dart';

/// The width of the code read-out: a code is `PRP-3`, `VEH-1` — never a sentence.
const double _codeFieldWidth = 92;

/// How far above the bottom of the row's fields the tracking badge sits, so it reads as sitting on
/// the name's own baseline rather than on the very bottom of its input box.
const double _trackingBadgeBottomInset = 8;

/// The size of the icon standing in for an element that references no photo.
const double _photoPlaceholderIconSize = 34;

/// The element sheet's header: the element's code — read out, never typed, see
/// [OcptResourcesCodeReadOut] — and its name as a title on the first row, its tracking state as a
/// badge on the right of them, and the category, the sub-category and the quantity on the second.
///
/// It is the person sheet's and the role sheet's header in this tab's own terms: what names the
/// record, and the one thing about it worth reading before anything else. For an element that one
/// thing is how far along it is — an item nobody has found yet is the sheet's whole point — so the
/// badge says it in the colour the left dock's own column already paints it, rather than repeating
/// the three checkboxes the tracking card owns.
///
/// The category sits here rather than in a card because it decides where the element appears in the
/// list at all: it is part of naming the thing, not of describing it.
///
/// The photo slot sits on the left, exactly where the person sheet's does
/// ([OcptResourcesPhotoSlot]) — a costume or a prop is a thing somebody has to recognise on a
/// trestle table, so a photograph of it is worth as much here as a headshot is there. It carries
/// **no colour grid**: `elements` has no `colorIndex`, an element being read by its category's own
/// colour, so the slot's menu holds the two photo entries alone.
class OcptElementSheetHeader extends StatelessWidget {
  /// The element this header shows.
  final OcptElement element;

  /// [element]'s current value for `field`: a pending edit still in the bloc's debounce, or the
  /// element's own stored value.
  final String Function(OcptElementField field) fieldValueOf;

  /// {@macro open_cine_prod_tools.fieldTextChangedCallback}
  final void Function(OcptElementField field, String rawValue)? onFieldChanged;

  /// Called with the newly picked category, or null while it may not be changed.
  final ValueChanged<OcptElementCategory>? onCategoryChanged;

  /// Called when the photo slot's reference entry is picked, or null while it may not be used.
  final VoidCallback? onPhotoPickRequested;

  /// Called when the photo slot's remove entry is picked, or null while it may not be used.
  final VoidCallback? onPhotoCleared;

  /// Class constructor
  const OcptElementSheetHeader({
    super.key,
    required this.element,
    required this.fieldValueOf,
    required this.onFieldChanged,
    required this.onCategoryChanged,
    required this.onPhotoPickRequested,
    required this.onPhotoCleared,
  });

  /// Build the element sheet header as a [Row].
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      OcptResourcesPhotoSlot(
        photo: element.photo,
        currentColorIndex: null,
        placeholderBuilder: (context) => _PhotoPlaceholder(category: element.category),
        onPhotoPickRequested: onPhotoPickRequested,
        onPhotoCleared: onPhotoCleared,
        onColorChanged: null,
      ),
      const SizedBox(width: 16),
      Expanded(
        child: _Fields(
          element: element,
          fieldValueOf: fieldValueOf,
          onFieldChanged: onFieldChanged,
          onCategoryChanged: onCategoryChanged,
        ),
      ),
    ],
  );
}

/// What the photo slot shows while the element references none: the category's own colour, which
/// is the colour that category already reads as everywhere in the breakdown and its exports.
class _PhotoPlaceholder extends StatelessWidget {
  /// The category of the element the slot belongs to.
  final OcptElementCategory category;

  /// Class constructor
  const _PhotoPlaceholder({required this.category});

  /// Build the photo placeholder as a [Center].
  @override
  Widget build(BuildContext context) {
    final color = Color(
      ocptBreakdownColorOf(kind: OcptBreakdownTargetKind.element, category: category),
    );

    return Center(
      child: Icon(Icons.inventory_2_outlined, size: _photoPlaceholderIconSize, color: color),
    );
  }
}

/// The header's own two rows, to the right of the photo slot.
class _Fields extends StatelessWidget {
  /// The element the rows show.
  final OcptElement element;

  /// [element]'s current value for `field`.
  final String Function(OcptElementField field) fieldValueOf;

  /// {@macro open_cine_prod_tools.fieldTextChangedCallback}
  final void Function(OcptElementField field, String rawValue)? onFieldChanged;

  /// Called with the newly picked category, or null while it may not be changed.
  final ValueChanged<OcptElementCategory>? onCategoryChanged;

  /// Class constructor
  const _Fields({
    required this.element,
    required this.fieldValueOf,
    required this.onFieldChanged,
    required this.onCategoryChanged,
  });

  /// Build the fields as a [Column].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Aligned by the bottom rather than by the top: the code carries a label and the name does
        // not, and the name is a title-sized field, so the two have neither the same height nor the
        // same first line. What has to line up is the bottom of them — the badge follows them
        // instead of the top of the row it used to hang from.
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            SizedBox(
              width: _codeFieldWidth,
              child: OcptResourcesCodeReadOut(
                label: tr.resourcesElementCodeLabel,
                code: element.code,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OcptResourcesSheetField(
                ownerId: element.id,
                label: "",
                value: fieldValueOf(OcptElementField.name),
                hintText: tr.resourcesElementNameHint,
                textStyle: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                onChanged: _onChangedOf(OcptElementField.name),
              ),
            ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(bottom: _trackingBadgeBottomInset),
              child: _TrackingBadge(element: element),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _CategoryPicker(element: element, onCategoryChanged: onCategoryChanged),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _OcptElementSheetHeaderField(
                fields: this,
                field: OcptElementField.subCategory,
                label: tr.resourcesElementSubCategoryLabel,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OcptResourcesSheetField(
                ownerId: element.id,
                label: tr.resourcesElementQuantityLabel,
                value: fieldValueOf(OcptElementField.quantity),
                inputFormatters: ocptDecimalInputFormatters,
                keyboardType: ocptDecimalKeyboardType,
                onChanged: _onChangedOf(OcptElementField.quantity),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Get the `onChanged` [field] is given: the one reporting to [onFieldChanged], or null while the
  /// sheet may not be written to, which is what makes the field read its value out instead.
  ValueChanged<String>? _onChangedOf(OcptElementField field) {
    final onFieldChanged = this.onFieldChanged;
    if (onFieldChanged == null) {
      return null;
    }

    return (value) => onFieldChanged(field, value);
  }
}

/// One text field of the header, labelled `label` and writing `field`.
class _OcptElementSheetHeaderField extends StatelessWidget {
  /// The fields group whose element and callbacks the field is wired to.
  final _Fields fields;

  /// The element field the text field writes.
  final OcptElementField field;

  /// The label of the text field.
  final String label;

  /// Class constructor
  const _OcptElementSheetHeaderField({
    required this.fields,
    required this.field,
    required this.label,
  });

  /// Build the element sheet header field as an [OcptResourcesSheetField].
  @override
  Widget build(BuildContext context) {
    final field = this.field;
    final label = this.label;

    return OcptResourcesSheetField(
      ownerId: fields.element.id,
      label: label,
      value: fields.fieldValueOf(field),
      onChanged: fields._onChangedOf(field),
    );
  }
}

/// The badge reading how far along the element is, read-only: the three checkboxes of the
/// tracking card are what change it.
class _TrackingBadge extends StatelessWidget {
  /// The element the badge reads.
  final OcptElement element;

  /// Class constructor
  const _TrackingBadge({required this.element});

  /// Build the tracking badge as a [Container].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(ocpt_theme.ocptRadiusSmall),
      ),
      child: Text(
        ocptElementTrackingLabel(tr, element),
        style: theme.textTheme.labelMedium?.copyWith(
          color: ocptElementTrackingColor(context, element),
        ),
      ),
    );
  }
}

/// The category picker: a label over a badge doubling as a [PopupMenuButton] over every
/// [OcptElementCategory], withheld (a plain badge, no menu) while the sheet may not be written
/// to.
class _CategoryPicker extends StatelessWidget {
  /// The element whose category is shown.
  final OcptElement element;

  /// Called with the newly picked category, or null while it may not be changed.
  final ValueChanged<OcptElementCategory>? onCategoryChanged;

  /// Class constructor
  const _CategoryPicker({required this.element, required this.onCategoryChanged});

  /// Build the category picker as a [Column].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final onCategoryChanged = this.onCategoryChanged;

    final badge = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            ocptElementCategoryLabel(tr, element.category),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
        ),
        if (onCategoryChanged != null) ...[
          const SizedBox(width: 4),
          Icon(Icons.arrow_drop_down, size: 16, color: theme.colorScheme.onSurfaceVariant),
        ],
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr.resourcesElementCategoryFieldLabel.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        if (onCategoryChanged == null)
          badge
        else
          PopupMenuButton<OcptElementCategory>(
            tooltip: "",
            onSelected: onCategoryChanged,
            itemBuilder: (context) => [
              for (final category in OcptElementCategory.values)
                PopupMenuItem<OcptElementCategory>(
                  value: category,
                  child: Text(ocptElementCategoryLabel(tr, category)),
                ),
            ],
            child: badge,
          ),
      ],
    );
  }
}
