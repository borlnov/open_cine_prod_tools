// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';

/// The band an episode wears wherever the schedule mode groups shots by episode before it groups
/// them by sequence — the left dock's own shots-still-to-place list and
/// `OcptScheduleShotPickerDialog` — so the two read an episode the same way.
///
/// A single-episode project names no episode anywhere (ADR 0019): both call sites only ever build
/// one of these while the project holds more than one live episode, never for one holding one or
/// none, so this widget carries no test of its own for that rule and simply draws whatever
/// [label] it is handed.
///
/// It has to read as a band and not as another sequence heading, the two sitting one above the
/// other in the same list: it reuses `OcptSchedulePositionsMatrix`'s own day band recipe — a
/// `surfaceContainerHigh` strip, bold and in the primary colour against the sequence headings'
/// plain bold `onSurfaceVariant` — rather than a new size no component theme already states.
///
/// **It positions itself in no list of its own**: it carries the strip's own padding and its
/// vertical air, and nothing horizontal, so each surface insets it exactly as it insets its own
/// sequence sections — the dock's list is inset by 16, the dialog's is flush, and a band carrying
/// either one would sit off the column it heads in the other. This is the frame-it-yourself rule
/// `OcptScheduleDayEventsList` already follows, drawn once and framed twice.
class OcptScheduleEpisodeBand extends StatelessWidget {
  /// The episode's own label, already localized (`ocptWorkspaceEpisodeLabelOf`).
  final String label;

  /// Class constructor
  const OcptScheduleEpisodeBand({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(ocptRadiusSmall),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
