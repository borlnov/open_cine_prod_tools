// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/types/ocpt_unavailability_slot.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_sheet_card.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_resources_labels.dart';

/// How long an unavailability row waits after the last keystroke in its reason field before
/// dispatching the update — this card's own local debounce, mirroring
/// `OcptPersonSheetPositionsCard`'s own.
const Duration _localFieldDebounce = Duration(milliseconds: 500);

/// The window a row falls back to the first time it is switched to
/// [OcptUnavailabilitySlot.custom]: an ordinary working day, so the user narrows a plausible
/// window rather than building one from midnight.
const int ocptDefaultUnavailabilityStartMinute = 9 * 60;

/// The end of the window described by [ocptDefaultUnavailabilityStartMinute].
const int ocptDefaultUnavailabilityEndMinute = 18 * 60;

/// The number of lines a reason field is tall before it grows with what is typed into it.
const int _reasonMinLines = 2;

/// "Unavailabilities": one row per [OcptPersonUnavailability] — the date range it spans, the
/// [OcptUnavailabilitySlot] it takes of each of those days (with an explicit window when that slot
/// is [OcptUnavailabilitySlot.custom]) and its free-text reason, each editable in place, plus a
/// remove control — and the `+ Add an unavailability` action, which opens the platform date picker
/// directly (a new unavailability always starts as one full day with no reason, all of it then
/// editable on the row it creates).
///
/// **Two windows in one day are two rows**: this is a set of constraints rather than a calendar
/// with one entry per date, so nothing here has to be merged or de-duplicated. Each row therefore
/// carries its own `+` control, which adds a second row over the very same dates already set to
/// [OcptUnavailabilitySlot.custom] — going back through the date picker to re-enter a date the
/// sheet is already showing would be the same answer, typed twice.
class OcptPersonSheetUnavailabilitiesCard extends StatelessWidget {
  /// The person's unavailabilities, in start-date order.
  final List<OcptPersonUnavailability> unavailabilities;

  /// Called with an unavailability's id and its fields once a local edit or a discrete change is
  /// ready to be written, or null while the sheet may not be written to.
  final void Function(
    String id, {
    required DateTime startDate,
    required DateTime endDate,
    required OcptUnavailabilitySlot slot,
    required int? startMinute,
    required int? endMinute,
    required String reason,
  })?
  onUpdated;

  /// Called with an unavailability's id when its row's remove button is clicked, or null while it
  /// may not be removed.
  final ValueChanged<String>? onRemoved;

  /// Called with a new unavailability's whole shape, or null while none may be added.
  ///
  /// Two affordances report through it: `+ Add an unavailability`, which opens the date picker and
  /// reports one full day, and a row's own `+`, which reports a second slot over that row's dates.
  final void Function({
    required DateTime startDate,
    required DateTime endDate,
    required OcptUnavailabilitySlot slot,
    required int? startMinute,
    required int? endMinute,
  })?
  onAdded;

  /// Class constructor
  const OcptPersonSheetUnavailabilitiesCard({
    super.key,
    required this.unavailabilities,
    required this.onUpdated,
    required this.onRemoved,
    required this.onAdded,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final onAdded = this.onAdded;

    return OcptResourcesSheetCard(
      title: tr.resourcesUnavailabilitiesTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (unavailabilities.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                tr.resourcesUnavailabilitiesEmptyHint,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else
            for (final unavailability in unavailabilities)
              _OcptUnavailabilityRow(
                key: ValueKey(unavailability.id),
                unavailability: unavailability,
                onUpdated: onUpdated == null
                    ? null
                    : ({
                        required startDate,
                        required endDate,
                        required slot,
                        required startMinute,
                        required endMinute,
                        required reason,
                      }) => onUpdated!(
                        unavailability.id,
                        startDate: startDate,
                        endDate: endDate,
                        slot: slot,
                        startMinute: startMinute,
                        endMinute: endMinute,
                        reason: reason,
                      ),
                onRemoved: onRemoved == null ? null : () => onRemoved!(unavailability.id),
                onSlotAdded: onAdded == null
                    ? null
                    : (startDate, endDate) => onAdded(
                        startDate: startDate,
                        endDate: endDate,
                        slot: OcptUnavailabilitySlot.custom,
                        startMinute: ocptDefaultUnavailabilityStartMinute,
                        endMinute: ocptDefaultUnavailabilityEndMinute,
                      ),
              ),
          if (onAdded != null)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _handleAddRequested(context, onAdded),
                child: Text(tr.resourcesAddUnavailabilityAction),
              ),
            ),
        ],
      ),
    );
  }

  /// Opens the platform date picker, reporting the pick to [onAdded] as one full day; does nothing
  /// if it is dismissed with no pick.
  Future<void> _handleAddRequested(
    BuildContext context,
    void Function({
      required DateTime startDate,
      required DateTime endDate,
      required OcptUnavailabilitySlot slot,
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
        slot: OcptUnavailabilitySlot.fullDay,
        startMinute: null,
        endMinute: null,
      );
    }
  }
}

/// One row of [OcptPersonSheetUnavailabilitiesCard]: the date range and the slot (all discrete,
/// written immediately) over the reason (free multi-line text, debounced locally by
/// [_localFieldDebounce]).
class _OcptUnavailabilityRow extends StatefulWidget {
  /// The unavailability this row shows.
  final OcptPersonUnavailability unavailability;

  /// Called with the row's current fields once ready to write, or null while read-only.
  final void Function({
    required DateTime startDate,
    required DateTime endDate,
    required OcptUnavailabilitySlot slot,
    required int? startMinute,
    required int? endMinute,
    required String reason,
  })?
  onUpdated;

  /// Called when this row's remove button is clicked, or null while it may not be removed.
  final VoidCallback? onRemoved;

  /// Called with this row's current dates when its `+` is clicked, adding a second slot over them,
  /// or null while none may be added.
  final void Function(DateTime startDate, DateTime endDate)? onSlotAdded;

  /// Class constructor
  const _OcptUnavailabilityRow({
    super.key,
    required this.unavailability,
    required this.onUpdated,
    required this.onRemoved,
    required this.onSlotAdded,
  });

  @override
  State<_OcptUnavailabilityRow> createState() => _OcptUnavailabilityRowState();
}

/// The state of [_OcptUnavailabilityRow]: the row's own local copies of its fields, and the
/// debounce that turns typing the reason into an [OcptPersonSheetUnavailabilitiesCard.onUpdated]
/// call.
///
/// A fresh instance of this state is created for every distinct unavailability id (the card keys
/// each row by it), so switching to another person disposes these rows and, with them, flushes
/// whatever reason edit was still pending: see [dispose].
class _OcptUnavailabilityRowState extends State<_OcptUnavailabilityRow> {
  /// The first covered date, held locally.
  late DateTime _startDate = widget.unavailability.startDate;

  /// The last covered date, held locally.
  late DateTime _endDate = widget.unavailability.endDate;

  /// The slot taken of each covered day, held locally.
  late OcptUnavailabilitySlot _slot = widget.unavailability.slot;

  /// The window's start in minutes from midnight, null unless [_slot] is
  /// [OcptUnavailabilitySlot.custom].
  late int? _startMinute = widget.unavailability.startMinute;

  /// The window's end in minutes from midnight, null unless [_slot] is
  /// [OcptUnavailabilitySlot.custom].
  late int? _endMinute = widget.unavailability.endMinute;

  /// The reason field's own controller.
  late final TextEditingController _reasonController = TextEditingController(
    text: widget.unavailability.reason,
  );

  /// The reason field's own focus node, flushing a pending edit the moment it loses focus.
  final FocusNode _reasonFocusNode = FocusNode();

  /// The running local debounce timer, if any.
  Timer? _debounce;

  /// Whether a local reason edit is waiting to be flushed.
  bool _isDirty = false;

  @override
  void initState() {
    super.initState();
    _reasonFocusNode.addListener(_flushOnFocusLost);
  }

  @override
  void dispose() {
    _flushIfDirty();
    _debounce?.cancel();
    _reasonFocusNode.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  /// Flushes a pending reason edit the moment the field loses focus.
  void _flushOnFocusLost() {
    if (!_reasonFocusNode.hasFocus) {
      _flushIfDirty();
    }
  }

  /// Records that the reason field changed and (re)starts the debounce.
  void _onReasonChanged(String text) {
    _isDirty = true;
    _debounce?.cancel();
    _debounce = Timer(_localFieldDebounce, _flushIfDirty);
  }

  /// Reports the row's current fields, if a local reason edit is actually waiting.
  void _flushIfDirty() {
    _debounce?.cancel();
    if (!_isDirty) {
      return;
    }
    _isDirty = false;
    _report();
  }

  /// Reports the row's current fields, whatever the debounce was doing: what every discrete change
  /// (a date, the slot, a window bound) calls, so it never waits out the reason's own debounce.
  void _report() {
    _debounce?.cancel();
    _isDirty = false;
    widget.onUpdated?.call(
      startDate: _startDate,
      endDate: _endDate,
      slot: _slot,
      startMinute: _startMinute,
      endMinute: _endMinute,
      reason: _reasonController.text,
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

  /// Sets this unavailability's slot, written immediately.
  ///
  /// Switching to [OcptUnavailabilitySlot.custom] seeds a plausible working-day window when the
  /// row has none yet; switching away from it drops the window, since the three other slots say
  /// everything themselves and a leftover pair of minutes would only ever come back wrong.
  void _setSlot(OcptUnavailabilitySlot slot) {
    if (slot == _slot) {
      return;
    }

    setState(() {
      _slot = slot;
      if (slot == OcptUnavailabilitySlot.custom) {
        _startMinute ??= ocptDefaultUnavailabilityStartMinute;
        _endMinute ??= ocptDefaultUnavailabilityEndMinute;
      } else {
        _startMinute = null;
        _endMinute = null;
      }
    });
    _report();
  }

  /// Picks one bound of the custom window, written immediately. The end is pushed to the start
  /// when a pick would invert them, for the same reason [_pickDate] keeps the two dates in order.
  Future<void> _pickTime({required bool isStart}) async {
    final currentMinute =
        (isStart ? _startMinute : _endMinute) ??
        (isStart ? ocptDefaultUnavailabilityStartMinute : ocptDefaultUnavailabilityEndMinute);
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
        if ((_endMinute ?? ocptDefaultUnavailabilityEndMinute) < pickedMinute) {
          _endMinute = pickedMinute;
        }
      } else {
        _endMinute = pickedMinute;
        if (pickedMinute < (_startMinute ?? ocptDefaultUnavailabilityStartMinute)) {
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
              Expanded(child: _buildDateRange(context, tr, isReadOnly: isReadOnly)),
              if (widget.onSlotAdded != null)
                IconButton(
                  icon: const Icon(Icons.add, size: 16),
                  tooltip: tr.resourcesAddUnavailabilitySlotTooltip,
                  onPressed: () => widget.onSlotAdded!(_startDate, _endDate),
                ),
              if (widget.onRemoved != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  tooltip: tr.resourcesRemoveUnavailabilityTooltip,
                  onPressed: widget.onRemoved,
                ),
            ],
          ),
          const SizedBox(height: 6),
          _OcptUnavailabilitySlotSelector(value: _slot, onChanged: isReadOnly ? null : _setSlot),
          if (_slot == OcptUnavailabilitySlot.custom) ...[
            const SizedBox(height: 6),
            _buildTimeWindow(context, isReadOnly: isReadOnly),
          ],
          const SizedBox(height: 8),
          Text(
            tr.resourcesUnavailabilityReasonLabel.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _reasonController,
            focusNode: _reasonFocusNode,
            readOnly: isReadOnly,
            onChanged: isReadOnly ? null : _onReasonChanged,
            minLines: _reasonMinLines,
            maxLines: null,
            style: theme.textTheme.bodySmall,
            decoration: InputDecoration(isDense: true, hintText: tr.resourcesUnavailabilityReasonHint),
          ),
        ],
      ),
    );
  }

  /// The `from … to …` pair of date buttons. Both ends are always shown, even when they hold the
  /// same date: a one-day unavailability is the same shape as any other, and hiding the second end
  /// until it differs would hide the very affordance that makes a range.
  Widget _buildDateRange(BuildContext context, Tr tr, {required bool isReadOnly}) => Wrap(
    spacing: 6,
    runSpacing: 4,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      Text(
        tr.resourcesUnavailabilityFromLabel,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      _buildDateButton(context, _startDate, isReadOnly: isReadOnly, isStart: true),
      Text(
        tr.resourcesUnavailabilityToLabel,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      _buildDateButton(context, _endDate, isReadOnly: isReadOnly, isStart: false),
    ],
  );

  /// One clickable date of the range.
  Widget _buildDateButton(
    BuildContext context,
    DateTime date, {
    required bool isReadOnly,
    required bool isStart,
  }) {
    final theme = Theme.of(context);
    final label = Text(
      DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(date),
      style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
    );

    if (isReadOnly) {
      return label;
    }

    return InkWell(
      onTap: () => _pickDate(isStart: isStart),
      mouseCursor: ocptClickableCursor,
      borderRadius: BorderRadius.circular(ocptRadiusSmall),
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), child: label),
    );
  }

  /// The `09:00 → 18:00` pair of time buttons, shown only while the slot is
  /// [OcptUnavailabilitySlot.custom].
  Widget _buildTimeWindow(BuildContext context, {required bool isReadOnly}) => Row(
    children: [
      _buildTimeButton(context, _startMinute, isReadOnly: isReadOnly, isStart: true),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Text("→", style: Theme.of(context).textTheme.labelSmall),
      ),
      _buildTimeButton(context, _endMinute, isReadOnly: isReadOnly, isStart: false),
    ],
  );

  /// One clickable bound of the custom window.
  Widget _buildTimeButton(
    BuildContext context,
    int? minute, {
    required bool isReadOnly,
    required bool isStart,
  }) {
    final theme = Theme.of(context);
    final resolvedMinute =
        minute ?? (isStart ? ocptDefaultUnavailabilityStartMinute : ocptDefaultUnavailabilityEndMinute);
    final label = Text(
      MaterialLocalizations.of(context).formatTimeOfDay(
        TimeOfDay(hour: resolvedMinute ~/ 60, minute: resolvedMinute % 60),
      ),
      style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
    );

    if (isReadOnly) {
      return label;
    }

    return InkWell(
      onTap: () => _pickTime(isStart: isStart),
      mouseCursor: ocptClickableCursor,
      borderRadius: BorderRadius.circular(ocptRadiusSmall),
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), child: label),
    );
  }
}

/// The selector an unavailability row uses to pick which part of a day it takes: one compact pill
/// per [OcptUnavailabilitySlot], the active one tinted `primary`, matching `OcptResourcesTabBar`'s
/// own segmented look.
class _OcptUnavailabilitySlotSelector extends StatelessWidget {
  /// The currently selected slot.
  final OcptUnavailabilitySlot value;

  /// Called with the slot picked, or null while it may not be changed: the pills then read the
  /// current value out with no reaction to a tap.
  final ValueChanged<OcptUnavailabilitySlot>? onChanged;

  /// Class constructor
  const _OcptUnavailabilitySlotSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final slot in OcptUnavailabilitySlot.values)
          _buildPill(context, slot, ocptUnavailabilitySlotLabel(tr, slot)),
      ],
    );
  }

  /// Builds one pill of the selector.
  Widget _buildPill(BuildContext context, OcptUnavailabilitySlot slot, String label) {
    final theme = Theme.of(context);
    final isSelected = slot == value;
    final onChanged = this.onChanged;

    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isSelected ? theme.colorScheme.primary.withValues(alpha: ocptSelectedStateAlpha) : null,
        borderRadius: BorderRadius.circular(ocptRadiusSmall),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );

    if (onChanged == null) {
      return pill;
    }

    return InkWell(
      onTap: () => onChanged(slot),
      mouseCursor: ocptClickableCursor,
      borderRadius: BorderRadius.circular(ocptRadiusSmall),
      child: pill,
    );
  }
}
