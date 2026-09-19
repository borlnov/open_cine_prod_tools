// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/types/ocpt_storyboard_panel_size.dart';

/// The board header's own `Panel size ▾` control: one radio entry per
/// [OcptStoryboardPanelSize], picking the common height every strip's frames share.
///
/// Built on [MenuAnchor], the same idiom `OcptShotListColumnsMenu` uses for the table's own
/// `Columns ▾`. A **view preference**, held in state for the session alone
/// (`OcptShotListState.boardPanelSize`'s own doc comment) — this menu writes nothing to the
/// project.
class OcptStoryboardPanelSizeMenu extends StatelessWidget {
  /// The panel size currently applied.
  final OcptStoryboardPanelSize value;

  /// Called with the size just picked.
  final ValueChanged<OcptStoryboardPanelSize> onChanged;

  /// Class constructor
  const OcptStoryboardPanelSizeMenu({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return MenuAnchor(
      menuChildren: [
        for (final size in OcptStoryboardPanelSize.values)
          RadioMenuButton<OcptStoryboardPanelSize>(
            value: size,
            groupValue: value,
            onChanged: (picked) {
              if (picked != null) {
                onChanged(picked);
              }
            },
            child: Text(_labelOf(tr, size)),
          ),
      ],
      builder: (context, controller, child) => OutlinedButton(
        onPressed: () => controller.isOpen ? controller.close() : controller.open(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tr.shotListBoardPanelSizeMenuAction),
            const Icon(Icons.arrow_drop_down, size: 16),
          ],
        ),
      ),
    );
  }

  /// The localized label of [size].
  String _labelOf(Tr tr, OcptStoryboardPanelSize size) => switch (size) {
    OcptStoryboardPanelSize.small => tr.shotListBoardPanelSizeSmall,
    OcptStoryboardPanelSize.medium => tr.shotListBoardPanelSizeMedium,
    OcptStoryboardPanelSize.large => tr.shotListBoardPanelSizeLarge,
  };
}
