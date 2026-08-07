// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/types/ocpt_first_weekday.dart';
import 'package:open_cine_prod_tools/types/ocpt_scene_effect_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_schedule_agenda_color_mode.dart';
import 'package:open_cine_prod_tools/types/ocpt_schedule_agenda_mode.dart';
import 'package:open_cine_prod_tools/types/ocpt_schedule_centre_view.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_schedule_labels.dart';

/// The schedule mode's own header band: the `Day`/`Agenda`/`Positions`/`Presence` switch and,
/// while the agenda is shown, its own `Strip`/`Week`/`Month` segmented control beside it, the
/// mock's own `Couleur par lieu` / `Int-Ext · Jour-Nuit` "Colour by" control and its legend
/// (shown only under [OcptScheduleAgendaColorMode.effect], since there is nothing to teach a
/// reader while every day is tinted by its own location), plus — for the week and month
/// presentations — the previous/next/today paging row, mirroring the mock's header row and
/// `OcptBreakdownHeader`'s own segmented-switch styling.
///
/// Purely presentational: every affordance here only reads, pages or re-tints the agenda (never a
/// database write), so it needs no `isReadOnly` flag.
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

  /// What fact the agenda currently tints a day with. Ignored (and the "Colour by" control hidden)
  /// while [centreView] is not [OcptScheduleCentreView.agenda]: the control re-tints all three
  /// presentations at once, so it has no reason to show under any of the other centre views.
  final OcptScheduleAgendaColorMode agendaColorMode;

  /// Called with the colour mode just picked.
  final ValueChanged<OcptScheduleAgendaColorMode> onAgendaColorModeSelected;

  /// The date the week/month agenda currently pages through — what the paging row's own label and
  /// its previous/next controls are computed from.
  final DateTime agendaAnchorDate;

  /// Called with the new anchor date once previous/next/today is clicked.
  final ValueChanged<DateTime> onAgendaAnchorDateChanged;

  /// Which day a week starts on — what the week presentation's own range label is cut by.
  final OcptFirstWeekday firstWeekday;

  /// Class constructor
  const OcptScheduleHeader({
    super.key,
    required this.centreView,
    required this.onCentreViewSelected,
    required this.agendaMode,
    required this.onAgendaModeSelected,
    required this.agendaColorMode,
    required this.onAgendaColorModeSelected,
    required this.agendaAnchorDate,
    required this.onAgendaAnchorDateChanged,
    required this.firstWeekday,
  });

  @override
  Widget build(BuildContext context) {
    final showNav =
        centreView == OcptScheduleCentreView.agenda && agendaMode != OcptScheduleAgendaMode.strip;
    final showColorBy = centreView == OcptScheduleCentreView.agenda;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              _OcptScheduleSegmentedSwitch<OcptScheduleCentreView>(
                value: centreView,
                values: OcptScheduleCentreView.values,
                labelOf: (view) => switch (view) {
                  OcptScheduleCentreView.day => Tr.of(context).scheduleHeaderDaySegmentLabel,
                  OcptScheduleCentreView.agenda => Tr.of(context).scheduleHeaderAgendaSegmentLabel,
                  OcptScheduleCentreView.positions =>
                    Tr.of(context).scheduleHeaderPositionsSegmentLabel,
                  OcptScheduleCentreView.presence =>
                    Tr.of(context).scheduleHeaderPresenceSegmentLabel,
                },
                onChanged: onCentreViewSelected,
              ),
              if (centreView == OcptScheduleCentreView.agenda)
                _OcptScheduleSegmentedSwitch<OcptScheduleAgendaMode>(
                  value: agendaMode,
                  values: OcptScheduleAgendaMode.values,
                  labelOf: (mode) => ocptScheduleAgendaModeLabel(Tr.of(context), mode),
                  onChanged: onAgendaModeSelected,
                ),
              if (showNav) _buildNav(context),
            ],
          ),
          if (showColorBy) ...[const SizedBox(height: 8), _buildColorBy(context)],
        ],
      ),
    );
  }

  /// The "Colour by" row: its own label, the `Location`/`Effect` segmented control, and — only
  /// while [agendaColorMode] is [OcptScheduleAgendaColorMode.effect] — the legend teaching a reader
  /// what each of the five washes means.
  Widget _buildColorBy(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 6,
      children: [
        Text(
          tr.scheduleAgendaColorByLabel,
          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        _OcptScheduleSegmentedSwitch<OcptScheduleAgendaColorMode>(
          value: agendaColorMode,
          values: OcptScheduleAgendaColorMode.values,
          labelOf: (mode) => ocptScheduleAgendaColorModeLabel(tr, mode),
          onChanged: onAgendaColorModeSelected,
        ),
        if (agendaColorMode == OcptScheduleAgendaColorMode.effect) const _OcptScheduleEffectLegend(),
      ],
    );
  }

  /// The previous/next/today paging row, shown only for the week and month presentations.
  Widget _buildNav(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final isWeek = agendaMode == OcptScheduleAgendaMode.week;
    final label = isWeek
        ? ocptScheduleWeekRangeLabel(
            context,
            ocptScheduleStartOfWeek(agendaAnchorDate, firstWeekday),
          )
        : ocptScheduleMonthLabel(context, agendaAnchorDate);
    final step = isWeek ? const Duration(days: 7) : null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left, size: 18),
          tooltip: tr.scheduleAgendaPreviousAction,
          visualDensity: VisualDensity.compact,
          onPressed: () => onAgendaAnchorDateChanged(
            step != null
                ? agendaAnchorDate.subtract(step)
                : DateTime(agendaAnchorDate.year, agendaAnchorDate.month - 1, agendaAnchorDate.day),
          ),
        ),
        SizedBox(
          width: 170,
          child: Text(label, textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right, size: 18),
          tooltip: tr.scheduleAgendaNextAction,
          visualDensity: VisualDensity.compact,
          onPressed: () => onAgendaAnchorDateChanged(
            step != null
                ? agendaAnchorDate.add(step)
                : DateTime(agendaAnchorDate.year, agendaAnchorDate.month + 1, agendaAnchorDate.day),
          ),
        ),
        const SizedBox(width: 4),
        InkWell(
          onTap: () => onAgendaAnchorDateChanged(DateTime.now()),
          mouseCursor: ocptClickableCursor,
          borderRadius: BorderRadius.circular(ocptRadiusSmall),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(ocptRadiusSmall),
            ),
            child: Text(tr.scheduleAgendaTodayAction, style: theme.textTheme.labelSmall),
          ),
        ),
      ],
    );
  }
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

/// The compact legend `OcptScheduleHeader` shows beside its own "Colour by" control while
/// [OcptScheduleAgendaColorMode.effect] is active: one swatch and label per
/// [OcptSceneEffectCategory], in declaration order — the four categories, then
/// [OcptSceneEffectCategory.mixed] last, so a reader meets the wash that means "these disagree"
/// only after meeting the four it disagrees among. Read-only, like every other row of this
/// control: there is nothing here to click.
class _OcptScheduleEffectLegend extends StatelessWidget {
  /// Class constructor
  const _OcptScheduleEffectLegend();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 4,
      children: [
        for (final category in OcptSceneEffectCategory.values)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: ocptScheduleDayEffectTint(context, category),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 4),
              Text(ocptSceneEffectCategoryLabel(tr, category), style: theme.textTheme.labelSmall),
            ],
          ),
      ],
    );
  }
}
