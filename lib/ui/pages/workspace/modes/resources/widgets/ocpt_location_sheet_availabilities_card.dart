// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_location.dart';
import 'package:open_cine_prod_tools/types/ocpt_day_part_slot.dart';
import 'package:open_cine_prod_tools/types/ocpt_location_availability_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_dated_window_controls.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_sheet_card.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_resources_labels.dart';
import 'package:open_cine_prod_tools/utils/ocpt_weekday_mask.dart';

/// How long a window waits after the last keystroke in its note field before dispatching the
/// update — this card's own local debounce, mirroring `OcptPersonSheetUnavailabilitiesCard`'s.
const Duration _localFieldDebounce = Duration(milliseconds: 500);

/// The number of lines a note field is tall before it grows with what is typed into it.
const int _noteMinLines = 2;

/// "Availability": one row per [OcptLocationAvailability] — the dates it spans, the days of the
/// week it actually covers inside them, the part of each of those days it takes, whether shooting
/// it costs something to respect, and the note saying what — plus the `+ Add an availability`
/// action, which opens the platform date picker directly.
///
/// The mirror image of the person sheet's unavailabilities, and deliberately the same controls:
/// what is entered here is when a location **may** be used, which is the raw material the schedule
/// mode crosses against a person's own windows.
///
/// A location with no window says *nothing* about itself rather than "never free": scheduling is
/// what will read these, and a production enters them for the locations it actually negotiated.
/// The free-text constraints card stays beside this one, for everything that isn't a matter of
/// hours — the neighbourhood, the way in, what may not be moved.
class OcptLocationSheetAvailabilitiesCard extends StatelessWidget {
  /// The location's availability windows, in start-date order.
  final List<OcptLocationAvailability> availabilities;

  /// Called with a window's id and its fields once a local edit or a discrete change is ready to be
  /// written, or null while the sheet may not be written to.
  final void Function(
    String id, {
    required DateTime startDate,
    required DateTime endDate,
    required int weekdays,
    required OcptDayPartSlot slot,
    required int? startMinute,
    required int? endMinute,
    required OcptLocationAvailabilityKind kind,
    required String note,
  })?
  onUpdated;

  /// Called with a window's id when its row's remove button is clicked, or null while it may not be
  /// removed.
  final ValueChanged<String>? onRemoved;

  /// Called with a new window's whole shape, or null while none may be added.
  ///
  /// Two affordances report through it: `+ Add an availability`, which opens the date picker and
  /// reports one whole day, and a row's own `+`, which reports a second slot over that row's dates
  /// — re-entering through the picker a date the sheet is already showing would be the same answer,
  /// typed twice.
  final void Function({
    required DateTime startDate,
    required DateTime endDate,
    required int weekdays,
    required OcptDayPartSlot slot,
    required int? startMinute,
    required int? endMinute,
  })?
  onAdded;

  /// Class constructor
  const OcptLocationSheetAvailabilitiesCard({
    super.key,
    required this.availabilities,
    required this.onUpdated,
    required this.onRemoved,
    required this.onAdded,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final onAdded = this.onAdded;
    final onRemoved = this.onRemoved;

    return OcptResourcesSheetCard(
      title: tr.resourcesLocationAvailabilityCardTitle,
      hint: availabilities.isEmpty ? null : tr.resourcesLocationAvailabilityCount(
        availabilities.length,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (availabilities.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                tr.resourcesLocationAvailabilitiesEmptyHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else
            for (final availability in availabilities)
              _OcptAvailabilityRow(
                key: ValueKey(availability.id),
                availability: availability,
                onUpdated: onUpdated == null
                    ? null
                    : ({
                        required startDate,
                        required endDate,
                        required weekdays,
                        required slot,
                        required startMinute,
                        required endMinute,
                        required kind,
                        required note,
                      }) => onUpdated!(
                        availability.id,
                        startDate: startDate,
                        endDate: endDate,
                        weekdays: weekdays,
                        slot: slot,
                        startMinute: startMinute,
                        endMinute: endMinute,
                        kind: kind,
                        note: note,
                      ),
                onRemoved: onRemoved == null ? null : () => onRemoved(availability.id),
                onSlotAdded: onAdded == null
                    ? null
                    : (startDate, endDate, weekdays) => onAdded(
                        startDate: startDate,
                        endDate: endDate,
                        weekdays: weekdays,
                        slot: OcptDayPartSlot.custom,
                        startMinute: ocptDefaultWindowStartMinute,
                        endMinute: ocptDefaultWindowEndMinute,
                      ),
              ),
          if (onAdded != null)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _handleAddRequested(context, onAdded),
                child: Text(tr.resourcesAddLocationAvailabilityAction),
              ),
            ),
        ],
      ),
    );
  }

  /// Opens the platform date picker, reporting the pick to [onAdded] as one whole day covering
  /// every weekday; does nothing if it is dismissed with no pick.
  Future<void> _handleAddRequested(
    BuildContext context,
    void Function({
      required DateTime startDate,
      required DateTime endDate,
      required int weekdays,
      required OcptDayPartSlot slot,
      required int? startMinute,
      required int? endMinute,
    })
    onAdded,
  ) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year + 5),
    );

    if (picked != null) {
      onAdded(
        startDate: picked,
        endDate: picked,
        weekdays: ocptEveryWeekdayMask,
        slot: OcptDayPartSlot.fullDay,
        startMinute: null,
        endMinute: null,
      );
    }
  }
}

/// One row of [OcptLocationSheetAvailabilitiesCard]: the dates, the weekdays, the slot and the kind
/// (all discrete, written immediately) over the note (free multi-line text, debounced locally by
/// [_localFieldDebounce]).
class _OcptAvailabilityRow extends StatefulWidget {
  /// The window this row shows.
  final OcptLocationAvailability availability;

  /// Called with the row's current fields once ready to write, or null while read-only.
  final void Function({
    required DateTime startDate,
    required DateTime endDate,
    required int weekdays,
    required OcptDayPartSlot slot,
    required int? startMinute,
    required int? endMinute,
    required OcptLocationAvailabilityKind kind,
    required String note,
  })?
  onUpdated;

  /// Called when this row's remove button is clicked, or null while it may not be removed.
  final VoidCallback? onRemoved;

  /// Called with this row's current dates and weekdays when its `+` is clicked, adding a second
  /// slot over them, or null while none may be added.
  final void Function(DateTime startDate, DateTime endDate, int weekdays)? onSlotAdded;

  /// Class constructor
  const _OcptAvailabilityRow({
    super.key,
    required this.availability,
    required this.onUpdated,
    required this.onRemoved,
    required this.onSlotAdded,
  });

  @override
  State<_OcptAvailabilityRow> createState() => _OcptAvailabilityRowState();
}

/// The state of [_OcptAvailabilityRow]: the row's own local copies of its fields, and the debounce
/// that turns typing the note into an [OcptLocationSheetAvailabilitiesCard.onUpdated] call.
///
/// A fresh instance is created for every distinct window id (the card keys each row by it), so
/// switching to another location disposes these rows and, with them, flushes whatever note edit was
/// still pending: see [dispose].
class _OcptAvailabilityRowState extends State<_OcptAvailabilityRow> {
  /// The first covered date, held locally.
  late DateTime _startDate = widget.availability.startDate;

  /// The last covered date, held locally.
  late DateTime _endDate = widget.availability.endDate;

  /// The days of the week covered inside the range, held locally.
  late int _weekdays = widget.availability.weekdays;

  /// The slot taken of each covered day, held locally.
  late OcptDayPartSlot _slot = widget.availability.slot;

  /// The window's start in minutes from midnight, null unless [_slot] is [OcptDayPartSlot.custom].
  late int? _startMinute = widget.availability.startMinute;

  /// The window's end in minutes from midnight, null unless [_slot] is [OcptDayPartSlot.custom].
  late int? _endMinute = widget.availability.endMinute;

  /// Whether the window is free or conditional, held locally.
  late OcptLocationAvailabilityKind _kind = widget.availability.kind;

  /// The note field's own controller.
  late final TextEditingController _noteController = TextEditingController(
    text: widget.availability.note,
  );

  /// The note field's own focus node, flushing a pending edit the moment it loses focus.
  final FocusNode _noteFocusNode = FocusNode();

  /// The running local debounce timer, if any.
  Timer? _debounce;

  /// Whether a local note edit is waiting to be flushed.
  bool _isDirty = false;

  @override
  void initState() {
    super.initState();
    _noteFocusNode.addListener(_flushOnFocusLost);
  }

  @override
  void dispose() {
    _flushIfDirty();
    _debounce?.cancel();
    _noteFocusNode.dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// Flushes a pending note edit the moment the field loses focus.
  void _flushOnFocusLost() {
    if (!_noteFocusNode.hasFocus) {
      _flushIfDirty();
    }
  }

  /// Records that the note field changed and (re)starts the debounce.
  void _onNoteChanged(String text) {
    _isDirty = true;
    _debounce?.cancel();
    _debounce = Timer(_localFieldDebounce, _flushIfDirty);
  }

  /// Reports the row's current fields, if a local note edit is actually waiting.
  void _flushIfDirty() {
    _debounce?.cancel();
    if (!_isDirty) {
      return;
    }
    _isDirty = false;
    _report();
  }

  /// Reports the row's current fields, whatever the debounce was doing: what every discrete change
  /// (a date, a weekday, the slot, a bound, the kind) calls, so it never waits out the note's own
  /// debounce.
  void _report() {
    _debounce?.cancel();
    _isDirty = false;
    widget.onUpdated?.call(
      startDate: _startDate,
      endDate: _endDate,
      weekdays: _weekdays,
      slot: _slot,
      startMinute: _startMinute,
      endMinute: _endMinute,
      kind: _kind,
      note: _noteController.text,
    );
  }

  /// Picks a new first or last date for this range, written immediately.
  ///
  /// The two ends are kept in order rather than the pick refused: moving the start past the end
  /// drags the end with it, and picking an end before the start pulls the start back — a date
  /// picker slip should not need an error message to recover from.
  Future<void> _pickDate({required bool isStart}) async {
    final anchor = isStart ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: anchor,
      firstDate: DateTime(1900),
      lastDate: DateTime(anchor.year + 5),
    );
    if (picked == null) {
      return;
    }

    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate.isBefore(picked)) {
          _endDate = picked;
        }
      } else {
        _endDate = picked;
        if (picked.isBefore(_startDate)) {
          _startDate = picked;
        }
      }
    });
    _report();
  }

  /// Adds [weekday] to the covered days, or takes it out, written immediately.
  ///
  /// Clearing the last covered day does nothing at all (see [ocptWeekdayMaskToggled]): a window
  /// covering no day of the week says nothing, and the way to drop it is the row's own remove
  /// control.
  void _toggleWeekday(int weekday) {
    final toggled = ocptWeekdayMaskToggled(_weekdays, weekday);
    if (toggled == _weekdays) {
      return;
    }

    setState(() => _weekdays = toggled);
    _report();
  }

  /// Sets this window's slot, written immediately.
  ///
  /// Switching to [OcptDayPartSlot.custom] seeds a plausible working-day window when the row has
  /// none yet; switching away from it drops the window, since the three other slots say everything
  /// themselves and a leftover pair of minutes would only ever come back wrong.
  void _setSlot(OcptDayPartSlot slot) {
    if (slot == _slot) {
      return;
    }

    setState(() {
      _slot = slot;
      if (slot == OcptDayPartSlot.custom) {
        _startMinute ??= ocptDefaultWindowStartMinute;
        _endMinute ??= ocptDefaultWindowEndMinute;
      } else {
        _startMinute = null;
        _endMinute = null;
      }
    });
    _report();
  }

  /// Sets whether this window is free or conditional, written immediately.
  void _setKind(OcptLocationAvailabilityKind kind) {
    if (kind == _kind) {
      return;
    }

    setState(() => _kind = kind);
    _report();
  }

  /// Picks one bound of the custom window, written immediately. The end is pushed to the start when
  /// a pick would invert them, for the same reason [_pickDate] keeps the two dates in order.
  Future<void> _pickTime({required bool isStart}) async {
    final currentMinute =
        (isStart ? _startMinute : _endMinute) ??
        (isStart ? ocptDefaultWindowStartMinute : ocptDefaultWindowEndMinute);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: currentMinute ~/ 60, minute: currentMinute % 60),
    );
    if (picked == null) {
      return;
    }

    final pickedMinute = picked.hour * 60 + picked.minute;
    setState(() {
      if (isStart) {
        _startMinute = pickedMinute;
        if ((_endMinute ?? ocptDefaultWindowEndMinute) < pickedMinute) {
          _endMinute = pickedMinute;
        }
      } else {
        _endMinute = pickedMinute;
        if (pickedMinute < (_startMinute ?? ocptDefaultWindowStartMinute)) {
          _startMinute = pickedMinute;
        }
      }
    });
    _report();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final isReadOnly = widget.onUpdated == null;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(ocptRadiusMedium),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: OcptDateRangeControl(
                  startDate: _startDate,
                  endDate: _endDate,
                  onStartPressed: isReadOnly ? null : () => _pickDate(isStart: true),
                  onEndPressed: isReadOnly ? null : () => _pickDate(isStart: false),
                ),
              ),
              if (widget.onSlotAdded != null)
                IconButton(
                  icon: const Icon(Icons.add, size: 16),
                  tooltip: tr.resourcesAddLocationAvailabilitySlotTooltip,
                  onPressed: () => widget.onSlotAdded!(_startDate, _endDate, _weekdays),
                ),
              if (widget.onRemoved != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  tooltip: tr.resourcesRemoveLocationAvailabilityTooltip,
                  onPressed: widget.onRemoved,
                ),
            ],
          ),
          const SizedBox(height: 6),
          _OcptWeekdaySelector(
            value: _weekdays,
            onToggled: isReadOnly ? null : _toggleWeekday,
          ),
          const SizedBox(height: 6),
          OcptDayPartSlotSelector(value: _slot, onChanged: isReadOnly ? null : _setSlot),
          if (_slot == OcptDayPartSlot.custom) ...[
            const SizedBox(height: 6),
            OcptTimeWindowControl(
              startMinute: _startMinute,
              endMinute: _endMinute,
              onStartPressed: isReadOnly ? null : () => _pickTime(isStart: true),
              onEndPressed: isReadOnly ? null : () => _pickTime(isStart: false),
            ),
          ],
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final kind in OcptLocationAvailabilityKind.values)
                OcptSelectablePill(
                  label: ocptLocationAvailabilityKindLabel(tr, kind),
                  isSelected: kind == _kind,
                  onPressed: isReadOnly ? null : () => _setKind(kind),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            tr.resourcesLocationAvailabilityNoteLabel.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _noteController,
            focusNode: _noteFocusNode,
            readOnly: isReadOnly,
            onChanged: isReadOnly ? null : _onNoteChanged,
            minLines: _noteMinLines,
            maxLines: null,
            style: theme.textTheme.bodySmall,
            decoration: InputDecoration(
              isDense: true,
              hintText: tr.resourcesLocationAvailabilityNoteHint,
            ),
          ),
        ],
      ),
    );
  }
}

/// The seven weekday toggles of a window: `M T W T F S S` in the locale's own order and its own
/// narrow names, the covered ones tinted `primary`.
///
/// The names and the order come from [MaterialLocalizations], which the app already ships in both
/// its languages: a hand-written list of seven labels would be a translation of something the
/// platform already knows, and would put Sunday in the wrong place for half the world.
class _OcptWeekdaySelector extends StatelessWidget {
  /// The mask of the covered days.
  final int value;

  /// Called with the weekday clicked, or null while the days may not be changed.
  final ValueChanged<int>? onToggled;

  /// Class constructor
  const _OcptWeekdaySelector({required this.value, required this.onToggled});

  @override
  Widget build(BuildContext context) {
    final materialLocalizations = MaterialLocalizations.of(context);
    final onToggled = this.onToggled;
    final firstDayIndex = materialLocalizations.firstDayOfWeekIndex;

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (var offset = 0; offset < ocptWeekdays.length; offset++)
          () {
            // `narrowWeekdays` is indexed from Sunday, while a `DateTime.weekday` runs Monday to
            // Sunday: the two meet through `index % 7`, Sunday being 7 there and 0 here.
            final index = (firstDayIndex + offset) % ocptWeekdays.length;
            final weekday = index == 0 ? DateTime.sunday : index;

            return OcptSelectablePill(
              label: materialLocalizations.narrowWeekdays[index],
              isSelected: ocptWeekdayMaskContains(value, weekday),
              onPressed: onToggled == null ? null : () => onToggled(weekday),
            );
          }(),
      ],
    );
  }
}
