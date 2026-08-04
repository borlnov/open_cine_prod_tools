// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_element.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_tracking_flag.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_sheet_card.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_sheet_field.dart';

/// "Tracking": the three boxes both reference spreadsheets tick about an element, in the order the
/// shoot goes through them, and where the thing waits until then.
///
/// The three are shown as one column of ticks rather than as a single "status" picker because they
/// are **not** exclusive: an item can be secured and returned without ever having been marked
/// ready, and a production that skipped a box should not be made to lie about it. The header's own
/// badge is what reads the three of them as one sentence.
///
/// While the sheet may not be written to, the boxes are shown with no callback at all: Flutter's
/// own [Checkbox] renders a null `onChanged` as the greyed, unclickable state, which is the one
/// case where reading the value out matters more than withholding the control — a tick nobody can
/// see is a fact lost.
class OcptElementSheetTrackingCard extends StatelessWidget {
  /// The element this card belongs to.
  final OcptElement element;

  /// The element's current value for `field`.
  final String Function(OcptElementField field) fieldValueOf;

  /// Called with a field's raw text on every keystroke, or null while the sheet may not be written
  /// to.
  final void Function(OcptElementField field, String rawValue)? onFieldChanged;

  /// Called with the flag ticked or unticked and what it now holds, or null while they may not be
  /// changed.
  final void Function(OcptElementTrackingFlag flag, {required bool value})? onTrackingFlagChanged;

  /// Class constructor
  const OcptElementSheetTrackingCard({
    super.key,
    required this.element,
    required this.fieldValueOf,
    required this.onFieldChanged,
    required this.onTrackingFlagChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final onFieldChanged = this.onFieldChanged;

    return OcptResourcesSheetCard(
      title: tr.resourcesElementTrackingCardTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildFlag(
            context,
            label: tr.resourcesElementSecuredLabel,
            flag: OcptElementTrackingFlag.secured,
            value: element.isSecured,
          ),
          _buildFlag(
            context,
            label: tr.resourcesElementReadyLabel,
            flag: OcptElementTrackingFlag.readyForShoot,
            value: element.isReadyForShoot,
          ),
          _buildFlag(
            context,
            label: tr.resourcesElementReturnedLabel,
            flag: OcptElementTrackingFlag.returned,
            value: element.isReturned,
          ),
          const SizedBox(height: 8),
          OcptResourcesSheetField(
            ownerId: element.id,
            label: tr.resourcesElementStorageNotesLabel,
            value: fieldValueOf(OcptElementField.storageNotes),
            onChanged: onFieldChanged == null
                ? null
                : (value) => onFieldChanged(OcptElementField.storageNotes, value),
          ),
        ],
      ),
    );
  }

  /// One tick of the card: the box and its label, the whole row being what toggles it.
  Widget _buildFlag(
    BuildContext context, {
    required String label,
    required OcptElementTrackingFlag flag,
    required bool value,
  }) {
    final theme = Theme.of(context);
    final onTrackingFlagChanged = this.onTrackingFlagChanged;
    final onToggled = onTrackingFlagChanged == null
        ? null
        : () => onTrackingFlagChanged(flag, value: !value);

    return InkWell(
      onTap: onToggled,
      mouseCursor: onToggled == null ? MouseCursor.defer : ocptClickableCursor,
      borderRadius: BorderRadius.circular(ocptRadiusSmall),
      child: Row(
        children: [
          Checkbox(
            value: value,
            onChanged: onTrackingFlagChanged == null
                ? null
                : (checked) => onTrackingFlagChanged(flag, value: checked ?? false),
          ),
          const SizedBox(width: 4),
          Expanded(child: Text(label, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}
