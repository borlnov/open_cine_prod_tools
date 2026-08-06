// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/types/ocpt_schedule_agenda_mode.dart';
import 'package:open_cine_prod_tools/types/ocpt_schedule_centre_view.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_schedule_labels.dart';

/// The schedule mode's own header band: the `Agenda`/`Day` switch and, while the agenda is shown,
/// its own `Strip`/`Week`/`Month` segmented control beside it — mirroring the mock's header row
/// (`design.html` lines 423-433) and `OcptBreakdownHeader`'s own segmented-switch styling.
///
/// **The mock's "Couleur par lieu / Int-Ext · Jour-Nuit" segmented control and the alert list under
/// it are deliberately not built here** — they arrive with M3 (`docs/plans/schedule-mode.md` §10),
/// per Benoit's own M1 decision.
///
/// Purely presentational: every affordance here only reads, so it needs no `isReadOnly` flag.
class OcptScheduleHeader extends StatelessWidget {
  /// Which of the two centre views is currently active.
  final OcptScheduleCentreView centreView;

  /// Called with the view just picked.
  final ValueChanged<OcptScheduleCentreView> onCentreViewSelected;

  /// Which of the three agenda presentations is currently active. Ignored (and the segmented
  /// control hidden) while [centreView] is [OcptScheduleCentreView.day].
  final OcptScheduleAgendaMode agendaMode;

  /// Called with the presentation just picked.
  final ValueChanged<OcptScheduleAgendaMode> onAgendaModeSelected;

  /// Class constructor
  const OcptScheduleHeader({
    super.key,
    required this.centreView,
    required this.onCentreViewSelected,
    required this.agendaMode,
    required this.onAgendaModeSelected,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
    child: Row(
      children: [
        _OcptScheduleSegmentedSwitch<OcptScheduleCentreView>(
          value: centreView,
          values: OcptScheduleCentreView.values,
          labelOf: (view) => switch (view) {
            OcptScheduleCentreView.agenda => Tr.of(context).scheduleHeaderAgendaSegmentLabel,
            OcptScheduleCentreView.day => Tr.of(context).scheduleHeaderDaySegmentLabel,
          },
          onChanged: onCentreViewSelected,
        ),
        if (centreView == OcptScheduleCentreView.agenda) ...[
          const SizedBox(width: 12),
          _OcptScheduleSegmentedSwitch<OcptScheduleAgendaMode>(
            value: agendaMode,
            values: OcptScheduleAgendaMode.values,
            labelOf: (mode) => ocptScheduleAgendaModeLabel(Tr.of(context), mode),
            onChanged: onAgendaModeSelected,
          ),
        ],
      ],
    ),
  );
}

/// A small bordered rounded segmented control over an arbitrary enum [T], the active segment
/// filled `primary` and bolder — the shared shape of `OcptScheduleHeader`'s own two switches,
/// mirroring `OcptBreakdownHeader`'s own private `_OcptBreakdownViewSwitch`.
class _OcptScheduleSegmentedSwitch<T> extends StatelessWidget {
  /// The switch's own current value.
  final T value;

  /// Every value the switch offers, in display order.
  final List<T> values;

  /// The display label of a value.
  final String Function(T value) labelOf;

  /// Called with the segment just clicked, when it differs from [value].
  final ValueChanged<T> onChanged;

  /// Class constructor
  const _OcptScheduleSegmentedSwitch({
    required this.value,
    required this.values,
    required this.labelOf,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(ocptRadiusMedium),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [for (final segment in values) _buildSegment(context, segment)],
      ),
    );
  }

  /// One of the switch's own segments.
  Widget _buildSegment(BuildContext context, T segment) {
    final theme = Theme.of(context);
    final isActive = value == segment;

    return InkWell(
      onTap: isActive ? null : () => onChanged(segment),
      mouseCursor: ocptClickableCursor,
      borderRadius: BorderRadius.circular(ocptRadiusSmall),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? theme.colorScheme.primary.withValues(alpha: ocptSelectedStateAlpha)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(ocptRadiusSmall),
        ),
        child: Text(
          labelOf(segment),
          style: theme.textTheme.labelMedium?.copyWith(
            color: isActive ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
