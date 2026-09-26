// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_set.dart';

/// The floor plans view's own set tabs, sitting in `OcptShotListCentreHeader`'s trailing slot
/// (`docs/plans/storyboard.md`, §4.1, §4.3; the redesign's §9.4 R3): a tab per set of the selected
/// sequence, each carrying its own **placed-shot count** ([placedShotCountOf] — how many of the
/// sequence's shots carry any live symbol on it), a filled `＋ Set` button appended after them
/// (never `+ Set` as its own visible text — the `＋` is the button's icon, the label is the word
/// alone) opening a menu of `Create set`, `Duplicate this set` and `Copy blocking from another
/// shot`, its name **edited in place** on whichever tab is currently selected, and removed through
/// a small close action every tab carries.
///
/// A tab is reported selected through [onSetSelected]; deleting one only asks
/// ([onSetDeleteRequested]) — the mode opens `OcptConfirmDialog`. Every write
/// ([onSetCreationRequested], [onSetDuplicateRequested], [onCopyBlockingRequested],
/// [onSetNameChanged], [onSetReordered], [onSetDeleteRequested]) is a **nullable** callback,
/// withheld by the mode under a read-only preview; selecting a tab is never withheld, since it only
/// reads.
class OcptFloorPlanSetTabs extends StatelessWidget {
  /// The selected sequence's own sets, in tab order.
  final List<OcptFloorPlanSet> sets;

  /// The id of the currently selected set, or null while none is.
  final String? selectedSetId;

  /// The selected set's own current name: a pending edit still in the bloc's debounce, or its own
  /// stored value — resolved by the mode, the tabs' equivalent of the inspector's `fieldValueOf`.
  final String Function(String setId) nameValueOf;

  /// How many of the selected sequence's own shots carry at least one live symbol on the given
  /// set's own id — the small badge next to a tab's own name.
  final int Function(String setId) placedShotCountOf;

  /// Called with a set's id when its tab is clicked. Never withheld: selecting only reads.
  final ValueChanged<String> onSetSelected;

  /// Called when the `＋ Set` menu's own `Create set` entry is clicked, or null while withheld.
  final VoidCallback? onSetCreationRequested;

  /// Called with the currently selected set's own id when the `＋ Set` menu's own `Duplicate this
  /// set` entry is clicked, or null while withheld or while nothing is selected.
  final ValueChanged<String>? onSetDuplicateRequested;

  /// Called with the currently selected set's own id when the `＋ Set` menu's own `Copy blocking
  /// from another shot` entry is clicked, or null while withheld or while nothing is selected — the
  /// mode opens its own source-shot picker before dispatching the copy.
  final ValueChanged<String>? onCopyBlockingRequested;

  /// Called with a set's id and its new name on every keystroke of the selected tab's own name
  /// field, or null while withheld.
  final void Function(String setId, String rawValue)? onSetNameChanged;

  /// Called with a set's id and its new 0-based tab position once a drag reordering the tabs
  /// ends, or null while withheld.
  final void Function(String setId, int newPosition)? onSetReordered;

  /// Called with a set's id when its own close action is clicked, or null while withheld. Only
  /// asks — the mode opens `OcptConfirmDialog`.
  final ValueChanged<String>? onSetDeleteRequested;

  /// Class constructor
  const OcptFloorPlanSetTabs({
    super.key,
    required this.sets,
    required this.selectedSetId,
    required this.nameValueOf,
    required this.placedShotCountOf,
    required this.onSetSelected,
    required this.onSetCreationRequested,
    required this.onSetDuplicateRequested,
    required this.onCopyBlockingRequested,
    required this.onSetNameChanged,
    required this.onSetReordered,
    required this.onSetDeleteRequested,
  });

  @override
  Widget build(BuildContext context) {
    final addButton = _buildAddSetButton(context);

    if (sets.isEmpty) {
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
              children: [for (final floorPlanSet in sets) _buildTab(context, floorPlanSet)],
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
  Widget _buildTab(BuildContext context, OcptFloorPlanSet floorPlanSet) {
    final theme = Theme.of(context);
    final isSelected = floorPlanSet.id == selectedSetId;

    final tab = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
      child: InkWell(
        onTap: () => onSetSelected(floorPlanSet.id),
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
              if (isSelected && onSetNameChanged != null)
                _EditableTabName(
                  key: ValueKey("${floorPlanSet.id}-editable"),
                  value: nameValueOf(floorPlanSet.id),
                  color: theme.colorScheme.primary,
                  onChanged: (value) => onSetNameChanged!(floorPlanSet.id, value),
                )
              else
                Text(
                  nameValueOf(floorPlanSet.id),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                  ),
                ),
              _buildPlacedShotCountBadge(context, floorPlanSet, isSelected),
              if (onSetDeleteRequested != null) ...[
                const SizedBox(width: 4),
                InkWell(
                  onTap: () => onSetDeleteRequested!(floorPlanSet.id),
                  mouseCursor: ocptClickableCursor,
                  child: Icon(Icons.close, size: 14, color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    final onSetReordered = this.onSetReordered;
    if (onSetReordered == null) {
      return tab;
    }

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => details.data != floorPlanSet.id,
      onAcceptWithDetails: (details) {
        final targetIndex = sets.indexOf(floorPlanSet);
        if (targetIndex >= 0) {
          onSetReordered(details.data, targetIndex);
        }
      },
      builder: (context, candidateData, rejectedData) => LongPressDraggable<String>(
        data: floorPlanSet.id,
        feedback: Material(color: Colors.transparent, child: tab),
        childWhenDragging: Opacity(opacity: 0.4, child: tab),
        child: tab,
      ),
    );
  }

  /// [floorPlanSet]'s own placed-shot count, as a small badge next to its tab's own name — hidden
  /// while the count is zero, so an empty set's tab stays exactly as before.
  Widget _buildPlacedShotCountBadge(
    BuildContext context,
    OcptFloorPlanSet floorPlanSet,
    bool isSelected,
  ) {
    final count = placedShotCountOf(floorPlanSet.id);
    if (count <= 0) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Tooltip(
        message: Tr.of(context).shotListFloorPlanSetPlacedShotCountTooltip(count),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primary.withValues(alpha: ocptSelectedStateAlpha * 2)
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(ocptRadiusSmall),
          ),
          child: Text(
            "$count",
            style: theme.textTheme.labelSmall?.copyWith(
              color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  /// The filled `＋ Set` button, whose own visible text is the word alone (the `＋` is the icon —
  /// see this class's own doc comment), opening a menu of `Create set`, `Duplicate this set` and
  /// `Copy blocking from another shot`. A tap with nothing to offer at all (every callback
  /// withheld) still shows the button, disabled, rather than disappearing — the same posture every
  /// other withheld write in this mode takes.
  Widget _buildAddSetButton(BuildContext context) {
    final tr = Tr.of(context);
    final selectedSetId = this.selectedSetId;
    final canCreate = onSetCreationRequested != null;
    final canDuplicate = selectedSetId != null && onSetDuplicateRequested != null;
    final canCopyBlocking = selectedSetId != null && onCopyBlockingRequested != null;

    Widget buildLabel() => FilledButton.icon(
      onPressed: null,
      icon: const Icon(Icons.add, size: 18),
      label: Text(tr.shotListFloorPlanAddSetButtonLabel),
    );

    if (!canCreate && !canDuplicate && !canCopyBlocking) {
      return buildLabel();
    }

    return MenuAnchor(
      menuChildren: [
        if (canCreate)
          MenuItemButton(
            onPressed: onSetCreationRequested,
            child: Text(tr.shotListFloorPlanCreateSetMenuAction),
          ),
        if (canDuplicate)
          MenuItemButton(
            onPressed: () => onSetDuplicateRequested!(selectedSetId),
            child: Text(tr.shotListFloorPlanDuplicateSetMenuAction),
          ),
        if (canCopyBlocking)
          MenuItemButton(
            onPressed: () => onCopyBlockingRequested!(selectedSetId),
            child: Text(tr.shotListFloorPlanCopyBlockingMenuAction),
          ),
      ],
      builder: (context, controller, child) => FilledButton.icon(
        onPressed: () => controller.isOpen ? controller.close() : controller.open(),
        icon: const Icon(Icons.add, size: 18),
        label: Text(tr.shotListFloorPlanAddSetButtonLabel),
      ),
    );
  }
}

/// The selected tab's own editable name field, kept as a small stateful widget so it holds its own
/// [TextEditingController] without turning [OcptFloorPlanSetTabs] itself into a
/// [StatefulWidget] — mirrors the version card's own rename form in spirit, but writes through the
/// mode's field-edit debounce on every keystroke rather than through an explicit `Save` button
/// (`OcptShotListSetNameEditKey`).
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
