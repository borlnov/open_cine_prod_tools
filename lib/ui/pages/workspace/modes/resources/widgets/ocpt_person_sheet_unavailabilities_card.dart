// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/types/ocpt_half_day.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_person_sheet_card.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_resources_labels.dart';

/// How long an unavailability row waits after the last keystroke in its reason field before
/// dispatching the update — this card's own local debounce, mirroring
/// `OcptPersonSheetPositionsCard`'s own.
const Duration _localFieldDebounce = Duration(milliseconds: 500);

/// "Unavailabilities": one row per [OcptPersonUnavailability] — its date, its [OcptHalfDay]
/// coverage and its free-text reason, each editable in place, plus a remove control — and the
/// `+ Add a date or a half-day` action, which opens the platform date picker directly (a new
/// unavailability always starts as a full day with no reason, both then editable on the row it
/// creates).
class OcptPersonSheetUnavailabilitiesCard extends StatelessWidget {
  /// The person's unavailabilities, in date order.
  final List<OcptPersonUnavailability> unavailabilities;

  /// Called with an unavailability's id and its three fields once a local edit or a discrete
  /// change is ready to be written, or null while the sheet may not be written to.
  final void Function(String id, {required DateTime date, required OcptHalfDay halfDay, required String reason})?
  onUpdated;

  /// Called with an unavailability's id when its row's remove button is clicked, or null while it
  /// may not be removed.
  final ValueChanged<String>? onRemoved;

  /// Called with the date picked once `+ Add a date or a half-day` opens the date picker and the
  /// user actually picks one, or null while none may be added.
  final ValueChanged<DateTime>? onAdded;

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

    return OcptPersonSheetCard(
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
                    : ({required date, required halfDay, required reason}) => onUpdated!(
                        unavailability.id,
                        date: date,
                        halfDay: halfDay,
                        reason: reason,
                      ),
                onRemoved: onRemoved == null ? null : () => onRemoved!(unavailability.id),
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

  /// Opens the platform date picker, reporting the pick to [onAdded]; does nothing if it is
  /// dismissed with no pick.
  Future<void> _handleAddRequested(BuildContext context, ValueChanged<DateTime> onAdded) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year + 5),
    );

    if (picked != null) {
      onAdded(picked);
    }
  }
}

/// One row of [OcptPersonSheetUnavailabilitiesCard]: the date and half-day (both discrete, written
/// immediately) over the reason (free text, debounced locally by [_localFieldDebounce]).
class _OcptUnavailabilityRow extends StatefulWidget {
  /// The unavailability this row shows.
  final OcptPersonUnavailability unavailability;

  /// Called with the row's three current fields once ready to write, or null while read-only.
  final void Function({required DateTime date, required OcptHalfDay halfDay, required String reason})? onUpdated;

  /// Called when this row's remove button is clicked, or null while it may not be removed.
  final VoidCallback? onRemoved;

  /// Class constructor
  const _OcptUnavailabilityRow({super.key, required this.unavailability, required this.onUpdated, required this.onRemoved});

  @override
  State<_OcptUnavailabilityRow> createState() => _OcptUnavailabilityRowState();
}

/// The state of [_OcptUnavailabilityRow]: the row's own local copies of its three fields, and the
/// debounce that turns typing the reason into an [OcptPersonSheetUnavailabilitiesCard.onUpdated]
/// call.
///
/// A fresh instance of this state is created for every distinct unavailability id (the card keys
/// each row by it), so switching to another person disposes these rows and, with them, flushes
/// whatever reason edit was still pending: see [dispose].
class _OcptUnavailabilityRowState extends State<_OcptUnavailabilityRow> {
  /// The date currently held locally.
  late DateTime _date = widget.unavailability.date;

  /// The half-day coverage currently held locally.
  late OcptHalfDay _halfDay = widget.unavailability.halfDay;

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

  /// Reports the row's three current fields, if a local reason edit is actually waiting.
  void _flushIfDirty() {
    _debounce?.cancel();
    if (!_isDirty) {
      return;
    }
    _isDirty = false;
    widget.onUpdated?.call(date: _date, halfDay: _halfDay, reason: _reasonController.text);
  }

  /// Picks a new date for this unavailability, written immediately alongside whatever the reason
  /// field currently holds (a discrete change never waits out the reason's own debounce).
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1900),
      lastDate: DateTime(_date.year + 5),
    );
    if (picked == null) {
      return;
    }

    _debounce?.cancel();
    _isDirty = false;
    setState(() => _date = picked);
    widget.onUpdated?.call(date: picked, halfDay: _halfDay, reason: _reasonController.text);
  }

  /// Sets this unavailability's half-day coverage, written immediately.
  void _setHalfDay(OcptHalfDay halfDay) {
    if (halfDay == _halfDay) {
      return;
    }

    _debounce?.cancel();
    _isDirty = false;
    setState(() => _halfDay = halfDay);
    widget.onUpdated?.call(date: _date, halfDay: halfDay, reason: _reasonController.text);
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
                child: InkWell(
                  onTap: isReadOnly ? null : _pickDate,
                  mouseCursor: ocptClickableCursor,
                  child: Text(
                    DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(_date),
                    style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              if (widget.onRemoved != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  tooltip: tr.resourcesRemoveUnavailabilityTooltip,
                  onPressed: widget.onRemoved,
                ),
            ],
          ),
          const SizedBox(height: 4),
          _OcptHalfDaySelector(value: _halfDay, onChanged: isReadOnly ? null : _setHalfDay),
          const SizedBox(height: 4),
          TextField(
            controller: _reasonController,
            focusNode: _reasonFocusNode,
            readOnly: isReadOnly,
            onChanged: isReadOnly ? null : _onReasonChanged,
            style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              hintText: tr.resourcesUnavailabilityReasonHint,
            ),
          ),
        ],
      ),
    );
  }
}

/// The small three-way selector an unavailability row uses to pick its [OcptHalfDay] coverage:
/// three compact pills, the active one tinted `primary`, matching `OcptResourcesTabBar`'s own
/// segmented look.
class _OcptHalfDaySelector extends StatelessWidget {
  /// The currently selected half-day.
  final OcptHalfDay value;

  /// Called with the half-day picked, or null while it may not be changed: the pills then read the
  /// current value out with no reaction to a tap.
  final ValueChanged<OcptHalfDay>? onChanged;

  /// Class constructor
  const _OcptHalfDaySelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final halfDay in OcptHalfDay.values) _buildPill(context, halfDay, ocptHalfDayLabel(tr, halfDay)),
      ],
    );
  }

  /// Builds one pill of the selector.
  Widget _buildPill(BuildContext context, OcptHalfDay halfDay, String label) {
    final theme = Theme.of(context);
    final isSelected = halfDay == value;
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
      onTap: () => onChanged(halfDay),
      mouseCursor: ocptClickableCursor,
      borderRadius: BorderRadius.circular(ocptRadiusSmall),
      child: pill,
    );
  }
}
