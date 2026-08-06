// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_location.dart';
import 'package:open_cine_prod_tools/models/ocpt_set.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_day_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_schedule_labels.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_shot_list_labels.dart';
import 'package:open_cine_prod_tools/utils/ocpt_day_minute.dart';
import 'package:open_cine_prod_tools/utils/ocpt_shooting_day_timeline.dart';
import 'package:open_cine_prod_tools/utils/ocpt_sun_times.dart';

/// The right dock's own `Inspector` tab content: the selected block's read-out, or — while none
/// is selected — the selected day's own, per `docs/plans/schedule-mode.md` §8's spec, or a plain
/// hint while nothing at all is selected.
///
/// Every writing affordance ([onDayStatusChanged], [onCrewNoteChanged], [onWeatherNoteChanged],
/// [onShotStatusChanged]) is a nullable callback, withheld while a project version is being
/// previewed. Reading — every other line — stays.
class OcptScheduleInspector extends StatelessWidget {
  /// The selected day, or null while none is selected.
  final OcptShootingDay? day;

  /// The selected day's own live slots, in `sortKey` order.
  final List<OcptShootingSlot> slots;

  /// The whole location catalogue, keyed by id.
  final Map<String, OcptLocation> locationById;

  /// The whole set catalogue, keyed by id.
  final Map<String, OcptSet> setById;

  /// The selected day's own computed timetable, or null while it has nothing placed yet.
  final OcptShootingDayTimeline? timeline;

  /// The selected day's own computed sun times, or null while its first slot has no location with
  /// coordinates.
  final OcptSunTimes? sunTimes;

  /// The selected day's own crew note, as currently held (a pending edit, or its stored value).
  final String crewNoteValue;

  /// The selected day's own weather note, as currently held.
  final String weatherNoteValue;

  /// Called with the status just picked, or null while withheld.
  final ValueChanged<OcptShootingDayStatus>? onDayStatusChanged;

  /// Called with the crew note's raw text on every keystroke, or null while withheld.
  final ValueChanged<String>? onCrewNoteChanged;

  /// Called with the weather note's raw text on every keystroke, or null while withheld.
  final ValueChanged<String>? onWeatherNoteChanged;

  /// The selected block, or null while none is selected — the inspector then shows [day]'s own
  /// read-out instead.
  final OcptShootingDayBlock? block;

  /// The shot [block] names, when [block]'s own kind is [OcptShootingBlockKind.shot].
  final OcptShot? blockShot;

  /// The label of the slot [block] sits in, or null while it sits in none.
  final String? blockSlotLabel;

  /// [block]'s own computed timeline entry, or null while the day has no timeline yet.
  final OcptShootingTimelineEntry? blockEntry;

  /// Called with the status just picked for [blockShot], or null while withheld.
  final ValueChanged<OcptShotStatus>? onShotStatusChanged;

  /// The selected block's own notes, as currently held (a pending edit, or its stored value).
  final String blockNotesValue;

  /// Called with the notes' raw text on every keystroke, or null while withheld.
  final ValueChanged<String>? onBlockNotesChanged;

  /// Whether the mode is read-only (a project version being previewed) — kept alongside the
  /// individual nullable callbacks above only for the one composite panel's own `isReadOnly` flag
  /// this widget itself needs nowhere else.
  final bool isReadOnly;

  /// Class constructor
  const OcptScheduleInspector({
    super.key,
    required this.day,
    required this.slots,
    required this.locationById,
    required this.setById,
    required this.timeline,
    required this.sunTimes,
    required this.crewNoteValue,
    required this.weatherNoteValue,
    required this.onDayStatusChanged,
    required this.onCrewNoteChanged,
    required this.onWeatherNoteChanged,
    required this.block,
    required this.blockShot,
    required this.blockSlotLabel,
    required this.blockEntry,
    required this.onShotStatusChanged,
    required this.blockNotesValue,
    required this.onBlockNotesChanged,
    required this.isReadOnly,
  });

  @override
  Widget build(BuildContext context) {
    final block = this.block;
    if (block != null) {
      return _buildBlockInspector(context, block);
    }

    final day = this.day;
    if (day == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            Tr.of(context).scheduleInspectorEmptyHint,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    return _buildDayInspector(context, day);
  }

  /// The day inspector: date, status, locations, sets, slots, the PAT band → the estimated end,
  /// the sun times and the UTC offset they were computed with, weather note, crew note.
  Widget _buildDayInspector(BuildContext context, OcptShootingDay day) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final dateLabel = DateFormat.yMMMEd(Localizations.localeOf(context).toString()).format(day.date);
    final locationNames = {
      for (final slot in slots)
        if (slot.locationId != null) locationById[slot.locationId]?.name,
    }.whereType<String>().toList();
    final setNames = {
      for (final slot in slots)
        if (slot.setId != null) setById[slot.setId]?.name,
    }.whereType<String>().toList();
    final firstCastCallMinute = slots
        .map((slot) => slot.castCallMinute)
        .firstWhere((minute) => minute != null, orElse: () => null);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(tr.scheduleInspectorDayTitle(ocptScheduleDayTagLabel(day.dayNumber)), style: theme.textTheme.titleSmall),
        const SizedBox(height: 2),
        Text(dateLabel, style: theme.textTheme.bodySmall),
        const SizedBox(height: 12),
        _OcptScheduleInspectorSection(
          label: tr.scheduleInspectorStatusLabel,
          child: onDayStatusChanged == null
              ? Text(ocptShootingDayStatusLabel(tr, day.status), style: theme.textTheme.bodySmall)
              : PopupMenuButton<OcptShootingDayStatus>(
                  tooltip: "",
                  onSelected: onDayStatusChanged,
                  itemBuilder: (context) => [
                    for (final status in OcptShootingDayStatus.values)
                      PopupMenuItem<OcptShootingDayStatus>(
                        value: status,
                        child: Text(ocptShootingDayStatusLabel(tr, status)),
                      ),
                  ],
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        ocptShootingDayStatusLabel(tr, day.status),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: ocptShootingDayStatusColor(context, day.status),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_drop_down, size: 16),
                    ],
                  ),
                ),
        ),
        _OcptScheduleInspectorSection(
          label: tr.scheduleInspectorLocationsLabel,
          child: Text(
            locationNames.isEmpty ? tr.scheduleDayNoLocation : locationNames.join(" → "),
            style: theme.textTheme.bodySmall,
          ),
        ),
        _OcptScheduleInspectorSection(
          label: tr.scheduleInspectorSetsLabel,
          child: Text(
            setNames.isEmpty ? tr.scheduleInspectorNoSets : setNames.join(", "),
            style: theme.textTheme.bodySmall,
          ),
        ),
        _OcptScheduleInspectorSection(
          label: tr.scheduleInspectorSlotsLabel,
          child: slots.isEmpty
              ? Text(tr.scheduleInspectorNoSlots, style: theme.textTheme.bodySmall)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final slot in slots)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          "${slot.label.isEmpty ? tr.scheduleInspectorUnnamedSlot : slot.label} · "
                          "${ocptScheduleDayMinuteRangeLabel(slot.crewCallMinute, slot.crewWrapMinute)}",
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
        ),
        _OcptScheduleInspectorSection(
          label: tr.scheduleInspectorPatToEndLabel,
          child: Text(
            ocptScheduleDayMinuteRangeLabel(firstCastCallMinute, timeline?.dayEndMinute),
            style: theme.textTheme.bodySmall,
          ),
        ),
        _OcptScheduleInspectorSection(
          label: tr.scheduleInspectorSunLabel,
          child: Text(_sunTimesLine(tr), style: theme.textTheme.bodySmall),
        ),
        _OcptScheduleInspectorSection(
          label: tr.scheduleInspectorWeatherLabel,
          child: _OcptScheduleNoteField(
            ownerId: day.id,
            value: weatherNoteValue,
            onChanged: onWeatherNoteChanged,
          ),
        ),
        _OcptScheduleInspectorSection(
          label: tr.scheduleInspectorCrewNoteLabel,
          child: _OcptScheduleNoteField(
            ownerId: day.id,
            value: crewNoteValue,
            onChanged: onCrewNoteChanged,
          ),
        ),
      ],
    );
  }

  /// The block inspector: kind, (for a shot) its own code/size/characters and status control, the
  /// computed start/end/duration, its own slot and notes.
  Widget _buildBlockInspector(BuildContext context, OcptShootingDayBlock block) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final blockShot = this.blockShot;
    final entry = blockEntry;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(ocptShootingBlockKindLabel(tr, block.kind), style: theme.textTheme.titleSmall),
        const SizedBox(height: 12),
        if (block.kind == OcptShootingBlockKind.shot && blockShot != null) ...[
          _OcptScheduleInspectorSection(
            label: tr.scheduleInspectorShotLabel,
            child: Text("${blockShot.code} · ${blockShot.shotSize}", style: theme.textTheme.bodySmall),
          ),
          if (blockShot.characters.isNotEmpty)
            _OcptScheduleInspectorSection(
              label: tr.scheduleInspectorCharactersLabel,
              child: Text(blockShot.characters.join(", "), style: theme.textTheme.bodySmall),
            ),
          _OcptScheduleInspectorSection(
            label: tr.scheduleInspectorShotStatusLabel,
            child: onShotStatusChanged == null
                ? Text(ocptShotStatusLabel(tr, blockShot.status), style: theme.textTheme.bodySmall)
                : PopupMenuButton<OcptShotStatus>(
                    tooltip: "",
                    onSelected: onShotStatusChanged,
                    itemBuilder: (context) => [
                      for (final status in OcptShotStatus.values)
                        PopupMenuItem<OcptShotStatus>(
                          value: status,
                          child: Text(ocptShotStatusLabel(tr, status)),
                        ),
                    ],
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          ocptShotStatusLabel(tr, blockShot.status),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: ocptShotStatusColor(context, blockShot.status),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_drop_down, size: 16),
                      ],
                    ),
                  ),
          ),
        ] else if (block.label.isNotEmpty)
          _OcptScheduleInspectorSection(
            label: tr.scheduleInspectorLabelLabel,
            child: Text(block.label, style: theme.textTheme.bodySmall),
          ),
        if (blockSlotLabel != null)
          _OcptScheduleInspectorSection(
            label: tr.scheduleInspectorSlotLabel,
            child: Text(blockSlotLabel!, style: theme.textTheme.bodySmall),
          ),
        _OcptScheduleInspectorSection(
          label: tr.scheduleInspectorTimeLabel,
          child: Text(
            entry == null
                ? "—"
                : "${ocptScheduleDayMinuteRangeLabel(entry.startMinute, entry.endMinute)} · "
                    "${ocptFormatMinuteDuration(entry.durationMinutes)}",
            style: theme.textTheme.bodySmall,
          ),
        ),
        _OcptScheduleInspectorSection(
          label: tr.scheduleInspectorNotesLabel,
          child: _OcptScheduleNoteField(
            ownerId: block.id,
            value: blockNotesValue,
            onChanged: onBlockNotesChanged,
          ),
        ),
      ],
    );
  }

  /// The sun/twilight summary line, or the "no coordinates" hint while [sunTimes] is null.
  String _sunTimesLine(Tr tr) {
    final sunTimes = this.sunTimes;
    if (sunTimes == null) {
      return tr.scheduleInspectorNoSunTimes;
    }

    final sunrise = sunTimes.sunriseMinute;
    final sunset = sunTimes.sunsetMinute;
    final civilDawn = sunTimes.civilDawnMinute;
    final civilDusk = sunTimes.civilDuskMinute;

    return tr.scheduleInspectorSunTimesLine(
      sunrise == null ? "—" : ocptFormatDayMinute(sunrise),
      sunset == null ? "—" : ocptFormatDayMinute(sunset),
      civilDawn == null ? "—" : ocptFormatDayMinute(civilDawn),
      civilDusk == null ? "—" : ocptFormatDayMinute(civilDusk),
      ocptScheduleUtcOffsetLabel(sunTimes.utcOffsetUsed),
    );
  }
}

/// One labelled section of the inspector: an upper-case label over its content, mirroring the
/// mock's own `PAT → fin` / `Soleil` / `Météo` band.
class _OcptScheduleInspectorSection extends StatelessWidget {
  /// The section's own label.
  final String label;

  /// The section's own content.
  final Widget child;

  /// Class constructor
  const _OcptScheduleInspectorSection({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 3),
          child,
        ],
      ),
    );
  }
}

/// A dense, multi-line text field for a note (a day's own weather or crew note, a block's own
/// notes), following the same controller-sync idiom as `OcptBreakdownHeader`'s own search field:
/// [value] is the field's current authoritative value, and the internal controller is only reset
/// to it when [ownerId] changes (the inspector now shows a different day or block) or when [value]
/// genuinely differs from what the controller already holds, so the caret never jumps mid-typing.
///
/// Reads as plain, selectable text with no field chrome at all while [onChanged] is null (a
/// project version being previewed read-only).
class _OcptScheduleNoteField extends StatefulWidget {
  /// The id of the day or block this field belongs to.
  final String ownerId;

  /// The field's current authoritative value.
  final String value;

  /// Called with the field's raw text on every keystroke, or null while withheld.
  final ValueChanged<String>? onChanged;

  /// Class constructor
  const _OcptScheduleNoteField({required this.ownerId, required this.value, required this.onChanged});

  @override
  State<_OcptScheduleNoteField> createState() => _OcptScheduleNoteFieldState();
}

/// The state of [_OcptScheduleNoteField]: owns the controller the class doc comment explains.
class _OcptScheduleNoteFieldState extends State<_OcptScheduleNoteField> {
  /// The field's own text editing controller, seeded from the widget's initial value and kept in
  /// sync with it afterward, see [didUpdateWidget].
  late final TextEditingController _controller = TextEditingController(text: widget.value);

  /// The [_OcptScheduleNoteField.ownerId] the controller was last synced against.
  late String _trackedOwnerId = widget.ownerId;

  @override
  void didUpdateWidget(covariant _OcptScheduleNoteField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.ownerId != _trackedOwnerId || widget.value != _controller.text) {
      _controller.text = widget.value;
      _trackedOwnerId = widget.ownerId;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onChanged = widget.onChanged;
    if (onChanged == null) {
      return SelectableText(
        widget.value.isEmpty ? "—" : widget.value,
        style: Theme.of(context).textTheme.bodySmall,
      );
    }

    return TextField(
      controller: _controller,
      onChanged: onChanged,
      maxLines: null,
      minLines: 2,
      style: Theme.of(context).textTheme.bodySmall,
      decoration: const InputDecoration(isDense: true),
    );
  }
}
