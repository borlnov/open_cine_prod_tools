// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_right_dock_tab_label.dart';

/// The chrome every tabbed right dock shares: a compact tab row of [tabs], a trailing × close
/// button, a divider, and the active tab's [body] below.
///
/// It knows nothing of the tabs a dock hosts: the caller resolves each label and decides which tab
/// is active, so that no tab enum is shared between the docks.
class OcptRightDockFrame extends StatelessWidget {
  /// The labels of the tab row, in order.
  final List<OcptRightDockTabLabel> tabs;

  /// The close button's tooltip.
  final String closeTooltip;

  /// Called when the × close button is clicked.
  final VoidCallback onClose;

  /// The active tab's body, which fills the dock below the tab row.
  final Widget body;

  /// Class constructor
  const OcptRightDockFrame({
    super.key,
    required this.tabs,
    required this.closeTooltip,
    required this.onClose,
    required this.body,
  });

  /// Build the right dock frame as a [Column].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            // The tab cluster scrolls horizontally rather than overflowing: the dock can be
            // resized (and squeezed by the centre floor, see
            // `OcptWorkspaceDock.resolveDockWidths`) down to widths narrower than every tab label
            // plus the close button combined.
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: tabs),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              tooltip: closeTooltip,
              visualDensity: VisualDensity.compact,
              onPressed: onClose,
            ),
          ],
        ),
        Divider(height: 1, thickness: 1, color: theme.colorScheme.outlineVariant),
        Expanded(child: body),
      ],
    );
  }
}
