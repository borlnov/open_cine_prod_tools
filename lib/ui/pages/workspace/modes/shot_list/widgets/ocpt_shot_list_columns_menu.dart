// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_column.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_shot_list_labels.dart';

/// The table's `Columns ▾` control: one checkbox entry per optional column, in the order
/// [OcptShotListColumn] declares them.
///
/// Only the optional columns are listed — the shot code, the characters, the shot size, the
/// framing, the camera move and the difficulty are always shown, so there is nothing to toggle
/// about them. Every toggle is persisted by the bloc, so the set of visible columns survives
/// closing the project.
///
/// Built on [MenuAnchor] rather than a [PopupMenuButton]: the menu stays open across toggles
/// (turning three columns on is one trip, not three), and its trigger is an ordinary
/// [OutlinedButton] taking its shape and density from the theme, which a popup menu button's own
/// icon-shaped trigger could not be.
class OcptShotListColumnsMenu extends StatelessWidget {
  /// The optional columns currently shown.
  final Set<OcptShotListColumn> visibleColumns;

  /// Called with an optional column when its entry is toggled.
  final ValueChanged<OcptShotListColumn> onColumnToggled;

  /// Class constructor
  const OcptShotListColumnsMenu({
    super.key,
    required this.visibleColumns,
    required this.onColumnToggled,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return MenuAnchor(
      menuChildren: [
        for (final column in OcptShotListColumn.values)
          CheckboxMenuButton(
            value: visibleColumns.contains(column),
            closeOnActivate: false,
            onChanged: (isVisible) => onColumnToggled(column),
            child: Text(ocptShotListColumnLabel(tr, column)),
          ),
      ],
      builder: (context, controller, child) => OutlinedButton(
        onPressed: () => controller.isOpen ? controller.close() : controller.open(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tr.shotListColumnsMenuAction),
            const Icon(Icons.arrow_drop_down, size: 16),
          ],
        ),
      ),
    );
  }
}
