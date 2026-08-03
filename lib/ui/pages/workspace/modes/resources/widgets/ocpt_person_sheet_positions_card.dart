// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_crew_positions.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_person_position.dart';
import 'package:open_cine_prod_tools/types/ocpt_crew_department.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_person_sheet_card.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_resources_labels.dart';

/// How long a position row waits after the last keystroke in its label field before dispatching
/// the update — this card's own local debounce, distinct from
/// `OcptResourcesState.pendingFieldEdits` (which only covers a person's own columns, not this
/// sub-list).
const Duration _localFieldDebounce = Duration(milliseconds: 500);

/// The width of a position row's department column: the mock-up's own figure, kept as a literal
/// since no component theme states it.
const double _departmentColumnWidth = 132;

/// The width of a position row's scope column, the read-only one the schedule mode will fill.
const double _scopeColumnWidth = 150;

/// The sentinel value the position picker menu uses for its "free label" entry, never a real
/// `ocptCrewPositions` id.
const String _customPositionOption = "__custom__";

/// "Functions on the film": one row per [OcptPersonPosition] — a position picked from
/// `ocptCrewPositions` (grouped by [OcptCrewDepartment]) or a free label, editable in place — plus
/// the `+ Add a function` action.
///
/// A row's **scope is read-only** and stays empty until the schedule mode exists: a position is
/// held over the time slots the planning assigns, and a person may hold two of them over one slot,
/// neither of which a field on this row could answer (see `OcptPersonPositionsTable`'s own doc
/// comment). The column is shown rather than hidden so the sheet says where that answer will come
/// from instead of silently omitting the question.
///
/// Roles (the cast, reconciled from the screenplay) are a later milestone: this card only ever
/// shows crew position assignments, never a role row.
class OcptPersonSheetPositionsCard extends StatelessWidget {
  /// The person these positions belong to.
  final String personId;

  /// The person's crew position assignments, in display order.
  final List<OcptPersonPosition> positions;

  /// Called with a position's id and its two fields once a local edit is ready to be written, or
  /// null while the sheet may not be written to (a project version being previewed read-only): no
  /// row is then editable and the `+ Add a function` action disappears.
  final void Function(String id, {required String positionId, required String customLabel})?
  onUpdated;

  /// Called with a position's id when its row's remove button is clicked, or null while it may not
  /// be removed.
  final ValueChanged<String>? onRemoved;

  /// Called when `+ Add a function` is clicked, appending a new, blank assignment, or null while
  /// none may be added.
  final VoidCallback? onAdded;

  /// Class constructor
  const OcptPersonSheetPositionsCard({
    super.key,
    required this.personId,
    required this.positions,
    required this.onUpdated,
    required this.onRemoved,
    required this.onAdded,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return OcptPersonSheetCard(
      title: tr.resourcesPositionsTitle,
      hint: tr.resourcesPositionsHint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (positions.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                tr.resourcesPositionsEmptyHint,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else
            for (final position in positions)
              _OcptPersonPositionRow(
                key: ValueKey(position.id),
                position: position,
                onUpdated: onUpdated == null
                    ? null
                    : ({required positionId, required customLabel}) =>
                          onUpdated!(position.id, positionId: positionId, customLabel: customLabel),
                onRemoved: onRemoved == null ? null : () => onRemoved!(position.id),
              ),
          if (onAdded != null)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onAdded,
                child: Text(tr.resourcesAddPositionAction),
              ),
            ),
        ],
      ),
    );
  }
}

/// One row of [OcptPersonSheetPositionsCard]: the department (derived, read-only), the position
/// label (free text, with a picker menu shortcut into `ocptCrewPositions`) and the scope
/// (read-only, the schedule mode's answer), a local label edit debounced by [_localFieldDebounce]
/// before being reported.
class _OcptPersonPositionRow extends StatefulWidget {
  /// The position assignment this row shows.
  final OcptPersonPosition position;

  /// Called with the row's two current fields once ready to write, or null while read-only.
  final void Function({required String positionId, required String customLabel})? onUpdated;

  /// Called when this row's remove button is clicked, or null while it may not be removed.
  final VoidCallback? onRemoved;

  /// Class constructor
  const _OcptPersonPositionRow({super.key, required this.position, required this.onUpdated, required this.onRemoved});

  @override
  State<_OcptPersonPositionRow> createState() => _OcptPersonPositionRowState();
}

/// The state of [_OcptPersonPositionRow]: the row's own local copies of its two fields, and the
/// debounce that turns typing into an [OcptPersonSheetPositionsCard.onUpdated] call.
///
/// A fresh instance of this state is created for every distinct position id (the card keys each
/// row by it), so switching to another person — a completely different set of ids — disposes
/// these rows and, with them, flushes whatever edit was still pending: see [dispose].
class _OcptPersonPositionRowState extends State<_OcptPersonPositionRow> {
  /// The catalogue id currently held locally, empty while this is a free-label assignment.
  late String _positionId = widget.position.positionId;

  /// The label field's own controller, seeded from the catalogue's resolved label or the free
  /// label, whichever `widget.position` holds at construction time.
  late final TextEditingController _labelController = TextEditingController(
    text: widget.position.positionId.isNotEmpty
        ? ocptCrewPositionLabel(Tr.of(context), widget.position.positionId)
        : widget.position.customLabel,
  );

  /// The label field's own focus node, flushing a pending edit the moment it loses focus.
  final FocusNode _labelFocusNode = FocusNode();

  /// The running local debounce timer, if any.
  Timer? _debounce;

  /// Whether a local edit is waiting to be flushed.
  bool _isDirty = false;

  @override
  void initState() {
    super.initState();
    _labelFocusNode.addListener(_flushOnFocusLost);
  }

  @override
  void dispose() {
    _flushIfDirty();
    _debounce?.cancel();
    _labelFocusNode.dispose();
    _labelController.dispose();
    super.dispose();
  }

  /// Flushes a pending edit the moment the label field loses focus, so a click elsewhere in the
  /// sheet never silently drops it.
  void _flushOnFocusLost() {
    if (!_labelFocusNode.hasFocus) {
      _flushIfDirty();
    }
  }

  /// Records that the label field now holds a free label (typing always leaves the catalogue,
  /// even if a catalogue entry was picked moments ago) and (re)starts the debounce.
  void _onLabelChanged(String text) {
    _positionId = "";
    _isDirty = true;
    _restartDebounce();
  }

  /// (Re)starts the local debounce, cancelling whatever was still running.
  void _restartDebounce() {
    _debounce?.cancel();
    _debounce = Timer(_localFieldDebounce, _flushIfDirty);
  }

  /// Reports the row's two current fields, if a local edit is actually waiting; a no-op otherwise,
  /// so a focus change with nothing typed never triggers a redundant write.
  void _flushIfDirty() {
    _debounce?.cancel();
    if (!_isDirty) {
      return;
    }
    _isDirty = false;
    widget.onUpdated?.call(
      positionId: _positionId,
      customLabel: _positionId.isEmpty ? _labelController.text : "",
    );
  }

  /// Picks catalogue position [positionId] from the row's menu: written immediately, since picking
  /// an entry is a single discrete action rather than typing.
  void _pickCatalogPosition(String positionId) {
    _debounce?.cancel();
    _isDirty = false;
    setState(() {
      _positionId = positionId;
      _labelController.text = ocptCrewPositionLabel(Tr.of(context), positionId);
    });
    widget.onUpdated?.call(positionId: positionId, customLabel: "");
  }

  /// Switches this row to a free label, keeping whatever text the label field already shows:
  /// written immediately, since picking the menu's "Custom label…" entry is itself a single
  /// discrete action.
  void _pickCustomLabel() {
    _debounce?.cancel();
    _isDirty = false;
    setState(() => _positionId = "");
    widget.onUpdated?.call(positionId: "", customLabel: _labelController.text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final isReadOnly = widget.onUpdated == null;
    final department = ocptCrewPositionDepartmentOf(_positionId);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(ocptRadiusMedium),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          SizedBox(
            width: _departmentColumnWidth,
            child: Text(
              department != null ? ocptCrewDepartmentLabel(tr, department) : ocptResourcesEmptyValue,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _labelController,
                    focusNode: _labelFocusNode,
                    readOnly: isReadOnly,
                    onChanged: isReadOnly ? null : _onLabelChanged,
                    style: theme.textTheme.bodySmall,
                    decoration: InputDecoration(isDense: true, hintText: tr.resourcesPositionLabelHint),
                  ),
                ),
                if (!isReadOnly)
                  PopupMenuButton<String>(
                    tooltip: "",
                    icon: const Icon(Icons.arrow_drop_down, size: 18),
                    onSelected: (value) => value == _customPositionOption
                        ? _pickCustomLabel()
                        : _pickCatalogPosition(value),
                    itemBuilder: (context) => _buildMenuItems(context, tr),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: _scopeColumnWidth,
            child: Text(
              tr.resourcesPositionScopePlaceholder,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          if (widget.onRemoved != null)
            IconButton(
              icon: const Icon(Icons.close, size: 16),
              tooltip: tr.resourcesRemovePositionTooltip,
              onPressed: widget.onRemoved,
            ),
        ],
      ),
    );
  }

  /// Builds the position picker menu: every `ocptCrewPositions` entry, grouped under a disabled
  /// department header each time the department changes, then a divider and the "Custom label…"
  /// entry.
  List<PopupMenuEntry<String>> _buildMenuItems(BuildContext context, Tr tr) {
    final theme = Theme.of(context);
    final items = <PopupMenuEntry<String>>[];
    OcptCrewDepartment? lastDepartment;

    for (final position in ocptCrewPositions) {
      if (position.department != lastDepartment) {
        items.add(
          PopupMenuItem<String>(
            enabled: false,
            height: 28,
            child: Text(
              ocptCrewDepartmentLabel(tr, position.department).toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        );
        lastDepartment = position.department;
      }
      items.add(PopupMenuItem<String>(value: position.id, child: Text(ocptCrewPositionLabel(tr, position.id))));
    }

    items.add(const PopupMenuDivider());
    items.add(PopupMenuItem<String>(value: _customPositionOption, child: Text(tr.resourcesPositionCustomOptionLabel)));

    return items;
  }
}
