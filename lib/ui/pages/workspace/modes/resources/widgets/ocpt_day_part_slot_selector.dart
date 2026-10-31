// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/types/ocpt_day_part_slot.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_selectable_pill.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_resources_labels.dart';

/// The selector a dated window picks its [OcptDayPartSlot] with: one compact pill per value, the
/// active one tinted `primary`, matching `OcptResourcesTabBar`'s own segmented look.
class OcptDayPartSlotSelector extends StatelessWidget {
  /// The currently selected slot.
  final OcptDayPartSlot value;

  /// Called with the slot picked, or null while it may not be changed: the pills then read the
  /// current value out with no reaction to a tap.
  final ValueChanged<OcptDayPartSlot>? onChanged;

  /// Class constructor
  const OcptDayPartSlotSelector({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final slot in OcptDayPartSlot.values)
          OcptSelectablePill(
            label: ocptDayPartSlotLabel(tr, slot),
            isSelected: slot == value,
            onPressed: onChanged == null ? null : () => onChanged!(slot),
          ),
      ],
    );
  }
}
