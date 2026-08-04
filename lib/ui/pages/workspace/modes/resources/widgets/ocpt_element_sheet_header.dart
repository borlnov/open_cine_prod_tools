// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_element.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_editable_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_sheet_field.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_decimal_input.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_resources_labels.dart';

/// The width of the code field: a code is `PRP-3`, `VEH-1` — never a sentence.
const double _codeFieldWidth = 92;

/// How far above the bottom of the row's fields the tracking badge sits, so it reads as sitting on
/// the name's own baseline rather than on the very bottom of its input box.
const double _trackingBadgeBottomInset = 8;

/// The element sheet's header: the element's code and its name as a title on the first row, its
/// tracking state as a badge on the right of them, and the category, the sub-category and the
/// quantity on the second.
///
/// It is the person sheet's and the role sheet's header in this tab's own terms: what names the
/// record, and the one thing about it worth reading before anything else. For an element that one
/// thing is how far along it is — an item nobody has found yet is the sheet's whole point — so the
/// badge says it in the colour the left dock's own column already paints it, rather than repeating
/// the three checkboxes the tracking card owns.
///
/// The category sits here rather than in a card because it decides where the element appears in the
/// list at all: it is part of naming the thing, not of describing it.
class OcptElementSheetHeader extends StatelessWidget {
  /// The element this header shows.
  final OcptElement element;

  /// [element]'s current value for `field`: a pending edit still in the bloc's debounce, or the
  /// element's own stored value.
  final String Function(OcptElementField field) fieldValueOf;

  /// Called with a field's raw text on every keystroke, or null while the sheet may not be written
  /// to.
  final void Function(OcptElementField field, String rawValue)? onFieldChanged;

  /// Called with the newly picked category, or null while it may not be changed.
  final ValueChanged<OcptElementCategory>? onCategoryChanged;

  /// Class constructor
  const OcptElementSheetHeader({
    super.key,
    required this.element,
    required this.fieldValueOf,
    required this.onFieldChanged,
    required this.onCategoryChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Aligned by the bottom rather than by the top: the code carries a label and the name does
        // not, and the name is a title-sized field, so the two boxes have neither the same height
        // nor the same first line. What has to line up is the bottom of the two input boxes — the
        // badge follows them instead of the top of the row it used to hang from.
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            SizedBox(
              width: _codeFieldWidth,
              child: _field(OcptElementField.code, tr.resourcesElementCodeLabel),
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
              child: _buildTrackingBadge(context, tr),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildCategoryPicker(context, tr)),
            const SizedBox(width: 12),
            Expanded(
              child: _field(OcptElementField.subCategory, tr.resourcesElementSubCategoryLabel),
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

  /// The badge reading how far along the element is, read-only: the three checkboxes of the
  /// tracking card are what change it.
  Widget _buildTrackingBadge(BuildContext context, Tr tr) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(ocptRadiusSmall),
      ),
      child: Text(
        ocptElementTrackingLabel(tr, element),
        style: theme.textTheme.labelMedium?.copyWith(
          color: ocptElementTrackingColor(context, element),
        ),
      ),
    );
  }

  /// The category picker: a label over a badge doubling as a [PopupMenuButton] over every
  /// [OcptElementCategory], withheld (a plain badge, no menu) while the sheet may not be written to.
  Widget _buildCategoryPicker(BuildContext context, Tr tr) {
    final theme = Theme.of(context);
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

  /// One text field of the header, labelled [label] and writing [field].
  Widget _field(OcptElementField field, String label) => OcptResourcesSheetField(
    ownerId: element.id,
    label: label,
    value: fieldValueOf(field),
    onChanged: _onChangedOf(field),
  );

  /// The `onChanged` [field] is given: the one reporting to [onFieldChanged], or null while the
  /// sheet may not be written to, which is what makes the field read its value out instead.
  ValueChanged<String>? _onChangedOf(OcptElementField field) {
    final onFieldChanged = this.onFieldChanged;
    if (onFieldChanged == null) {
      return null;
    }

    return (value) => onFieldChanged(field, value);
  }
}
