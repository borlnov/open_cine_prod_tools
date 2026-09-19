// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_case.dart';

/// The floor plans view's own case tabs, sitting in `OcptShotListCentreHeader`'s trailing slot
/// (`docs/plans/storyboard.md`, §4.1, §4.3): a tab per case of the selected sequence, `+ Case`
/// appended after them, its name **edited in place** on whichever tab is currently selected, and
/// removed through a small close action every tab carries.
///
/// A tab is reported selected through [onCaseSelected]; deleting one only asks
/// ([onCaseDeleteRequested]) — the mode opens `OcptConfirmDialog`. Every write ([onCaseCreationRequested],
/// [onCaseNameChanged], [onCaseReordered], [onCaseDeleteRequested]) is a **nullable** callback,
/// withheld by the mode under a read-only preview; selecting a tab is never withheld, since it only
/// reads.
class OcptFloorPlanCaseTabs extends StatelessWidget {
  /// The selected sequence's own cases, in tab order.
  final List<OcptFloorPlanCase> cases;

  /// The id of the currently selected case, or null while none is.
  final String? selectedCaseId;

  /// The selected case's own current name: a pending edit still in the bloc's debounce, or its own
  /// stored value — resolved by the mode, the tabs' equivalent of the inspector's `fieldValueOf`.
  final String Function(String caseId) nameValueOf;

  /// Called with a case's id when its tab is clicked. Never withheld: selecting only reads.
  final ValueChanged<String> onCaseSelected;

  /// Called when `+ Case` is clicked, or null while withheld.
  final VoidCallback? onCaseCreationRequested;

  /// Called with a case's id and its new name on every keystroke of the selected tab's own name
  /// field, or null while withheld.
  final void Function(String caseId, String rawValue)? onCaseNameChanged;

  /// Called with a case's id and its new 0-based tab position once a drag reordering the tabs
  /// ends, or null while withheld.
  final void Function(String caseId, int newPosition)? onCaseReordered;

  /// Called with a case's id when its own close action is clicked, or null while withheld. Only
  /// asks — the mode opens `OcptConfirmDialog`.
  final ValueChanged<String>? onCaseDeleteRequested;

  /// Class constructor
  const OcptFloorPlanCaseTabs({
    super.key,
    required this.cases,
    required this.selectedCaseId,
    required this.nameValueOf,
    required this.onCaseSelected,
    required this.onCaseCreationRequested,
    required this.onCaseNameChanged,
    required this.onCaseReordered,
    required this.onCaseDeleteRequested,
  });

  @override
  Widget build(BuildContext context) {
    final addButton = Tooltip(
      message: Tr.of(context).shotListFloorPlanAddCaseAction,
      child: IconButton(
        onPressed: onCaseCreationRequested,
        icon: const Icon(Icons.add, size: 18),
      ),
    );

    if (cases.isEmpty) {
      return addButton;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 40,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [for (final floorPlanCase in cases) _buildTab(context, floorPlanCase)],
            ),
          ),
        ),
        addButton,
      ],
    );
  }

  /// One case's own tab: its name (editable in place while selected), and a small close action.
  ///
  /// Reordering is a plain `Draggable`/`DragTarget` pair, not `ReorderableListView`: this row sits
  /// inside the centre header's own `Wrap` (unbounded cross-axis space), which
  /// `ReorderableListView`'s heavier scrolling/semantics machinery does not tolerate reliably —
  /// this simpler pair needs nothing from its ancestor beyond ordinary hit testing.
  Widget _buildTab(BuildContext context, OcptFloorPlanCase floorPlanCase) {
    final theme = Theme.of(context);
    final isSelected = floorPlanCase.id == selectedCaseId;

    final tab = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
      child: InkWell(
        onTap: () => onCaseSelected(floorPlanCase.id),
        mouseCursor: ocptClickableCursor,
        borderRadius: BorderRadius.circular(ocptRadiusSmall),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primary.withValues(alpha: ocptSelectedStateAlpha)
                : Colors.transparent,
            border: Border.all(
              color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(ocptRadiusSmall),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSelected && onCaseNameChanged != null)
                _EditableTabName(
                  key: ValueKey("${floorPlanCase.id}-editable"),
                  value: nameValueOf(floorPlanCase.id),
                  color: theme.colorScheme.primary,
                  onChanged: (value) => onCaseNameChanged!(floorPlanCase.id, value),
                )
              else
                Text(
                  nameValueOf(floorPlanCase.id),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                  ),
                ),
              if (onCaseDeleteRequested != null) ...[
                const SizedBox(width: 4),
                InkWell(
                  onTap: () => onCaseDeleteRequested!(floorPlanCase.id),
                  mouseCursor: ocptClickableCursor,
                  child: Icon(Icons.close, size: 14, color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    final onCaseReordered = this.onCaseReordered;
    if (onCaseReordered == null) {
      return tab;
    }

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => details.data != floorPlanCase.id,
      onAcceptWithDetails: (details) {
        final targetIndex = cases.indexOf(floorPlanCase);
        if (targetIndex >= 0) {
          onCaseReordered(details.data, targetIndex);
        }
      },
      builder: (context, candidateData, rejectedData) => LongPressDraggable<String>(
        data: floorPlanCase.id,
        feedback: Material(color: Colors.transparent, child: tab),
        childWhenDragging: Opacity(opacity: 0.4, child: tab),
        child: tab,
      ),
    );
  }
}

/// The selected tab's own editable name field, kept as a small stateful widget so it holds its own
/// [TextEditingController] without turning [OcptFloorPlanCaseTabs] itself into a
/// [StatefulWidget] — mirrors the version card's own rename form in spirit, but writes through the
/// mode's field-edit debounce on every keystroke rather than through an explicit `Save` button
/// (`OcptShotListCaseNameEditKey`).
class _EditableTabName extends StatefulWidget {
  /// The field's current value.
  final String value;

  /// The colour the text and the caret are drawn with.
  final Color color;

  /// Called with the field's raw text on every keystroke.
  final ValueChanged<String> onChanged;

  /// Class constructor
  const _EditableTabName({super.key, required this.value, required this.color, required this.onChanged});

  @override
  State<_EditableTabName> createState() => _EditableTabNameState();
}

class _EditableTabNameState extends State<_EditableTabName> {
  /// The field's own controller, seeded once from [_EditableTabName.value] and never re-seeded
  /// from a later prop change (a rebuild while the user is typing would otherwise fight the
  /// keystroke it is itself reporting).
  late final TextEditingController _controller = TextEditingController(text: widget.value);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IntrinsicWidth(
    child: TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: widget.color,
        fontWeight: FontWeight.w700,
      ),
      decoration: const InputDecoration(
        isDense: true,
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
      ),
    ),
  );
}
