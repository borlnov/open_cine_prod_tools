// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart' as ocpt_theme;

/// The bordered card shell shared by a slot card's crew, cast and guest rows: the one place their
/// common border, radius and padding are declared, so the three kinds of card cannot drift from
/// one another.
class OcptScheduleSlotPersonCard extends StatelessWidget {
  /// The card's own content.
  final Widget child;

  /// Class constructor
  const OcptScheduleSlotPersonCard({super.key, required this.child});

  /// Build the schedule slot person card as a [Container].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(ocpt_theme.ocptRadiusSmall),
      ),
      child: child,
    );
  }
}
