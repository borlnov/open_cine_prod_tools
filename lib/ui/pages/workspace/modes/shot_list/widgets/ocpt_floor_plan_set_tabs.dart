// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_set.dart';

/// The floor plans view's own set tabs, sitting in `OcptShotListCentreHeader`'s trailing slot: a
/// tab per set of the selected sequence, each
/// carrying its own **placed-shot count** ([placedShotCountOf] — how many of the sequence's shots
/// carry any live symbol on it), a filled `＋ Set` button appended after them (never `+ Set` as its
/// own visible text — the `＋` is the button's icon, the label is the word alone) opening the
/// breakdown's own kind of menu — the suggestion first and starred
/// ([suggestedSetId]/[suggestedSetName]), `Link an existing set ▸` grouped by location
/// ([linkableSetsByLocation]), `Create a set ▸` (each existing location, then `New location…`),
/// a divider, then `Duplicate this set` and `Copy blocking from a shot…` — its name **edited in
/// place** on whichever tab is currently selected, and removed through a small close action every
/// tab carries.
///
/// A tab is reported selected through [onSetSelected]; deleting one only asks
/// ([onSetDeleteRequested]) — the mode opens `OcptConfirmDialog`. Every write
/// ([onSetLinkRequested], [onSetCreationRequested], [onSetDuplicateRequested],
/// [onCopyBlockingRequested], [onSetNameChanged], [onSetReordered], [onSetDeleteRequested]) is a
/// **nullable** callback, withheld by the mode under a read-only preview; selecting a tab is never
/// withheld, since it only reads.
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

  /// The id of the Resources set `ocptSceneSetSuggestionOf` suggests for the selected sequence's
  /// own heading, or null while it suggests none, the suggestion is already one of [sets], or the
  /// caller withholds it — resolved by the mode exactly as the breakdown's own set picker resolves
  /// its own suggestion. Shown first in the menu, starred.
  final String? suggestedSetId;

  /// [suggestedSetId]'s own display name, read by the mode from the project's whole Resources
  /// catalogue — null whenever [suggestedSetId] is.
  final String? suggestedSetName;

  /// Every Resources set of the project **not already linked** to the selected sequence, grouped by
  /// its own location's name — the `Link an existing set ▸` submenu's own entries, in
  /// `(locationName, sets)` pairs, each set itself an `(id, name)` pair. Empty hides the whole
  /// submenu rather than showing one with nothing in it.
  final List<(String locationName, List<(String id, String name)> sets)> linkableSetsByLocation;

  /// Every location of the project, `(id, name)` — the `Create a set ▸` submenu's own per-location
  /// entries, its `New location…` entry always appended after them.
  final List<(String id, String name)> locationsForCreation;

  /// Called with a set's id when its tab is clicked. Never withheld: selecting only reads.
  final ValueChanged<String> onSetSelected;

  /// Called with a Resources set's id when the suggestion entry or one of the `Link an existing
  /// set ▸` submenu's own entries is clicked, or null while withheld.
  final ValueChanged<String>? onSetLinkRequested;

  /// Called with the location id a `Create a set ▸` submenu entry names, or null (its own
  /// `New location…` entry) to mint a fresh location for it too — or null itself, at the field
  /// level, while withheld.
  final void Function(String? locationId)? onSetCreationRequested;

  /// Called with the currently selected set's own id when the menu's own `Duplicate this set`
  /// entry is clicked, or null while withheld or while nothing is selected.
  final ValueChanged<String>? onSetDuplicateRequested;

  /// Called with the currently selected set's own id when the menu's own `Copy blocking from a
  /// shot…` entry is clicked, or null while withheld or while nothing is selected — the mode opens
  /// its own source-shot picker before dispatching the copy.
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
    this.suggestedSetId,
    this.suggestedSetName,
    this.linkableSetsByLocation = const [],
    this.locationsForCreation = const [],
    required this.onSetSelected,
    this.onSetLinkRequested,
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

  /// One set's own tab: its name (editable in place while selected), and a small close action.
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
  /// see this class's own doc comment), opening the breakdown's own kind of menu: the suggestion
  /// first (starred), `Link an existing set ▸`, `Create a set ▸`, a divider, `Duplicate this set`
  /// and `Copy blocking from a shot…`. A tap with nothing to offer at all (every callback withheld)
  /// still shows the button, disabled, rather than disappearing — the same posture every other
  /// withheld write in this mode takes.
  ///
  /// **A `MenuItemButton` may not go inside a `Wrap`** (a known pitfall of this mode): every entry
  /// here, including a submenu's own `menuChildren`, stays a single column — `SubmenuButton` never
  /// wraps its own children either — so the failure that pitfall names never applies.
  Widget _buildAddSetButton(BuildContext context) {
    final tr = Tr.of(context);
    final selectedSetId = this.selectedSetId;
    final suggestedSetId = this.suggestedSetId;
    final canSuggestLink = suggestedSetId != null && onSetLinkRequested != null;
    final canLinkExisting = onSetLinkRequested != null && linkableSetsByLocation.isNotEmpty;
    final canCreate = onSetCreationRequested != null;
    final canDuplicate = selectedSetId != null && onSetDuplicateRequested != null;
    final canCopyBlocking = selectedSetId != null && onCopyBlockingRequested != null;

    Widget buildDisabledButton() => FilledButton.icon(
      onPressed: null,
      icon: const Icon(Icons.add, size: 18),
      label: Text(tr.shotListFloorPlanAddSetButtonLabel),
    );

    if (!canSuggestLink && !canLinkExisting && !canCreate && !canDuplicate && !canCopyBlocking) {
      return buildDisabledButton();
    }

    return MenuAnchor(
      menuChildren: [
        if (canSuggestLink)
          MenuItemButton(
            leadingIcon: const Icon(Icons.star, size: 16),
            onPressed: () => onSetLinkRequested!(suggestedSetId),
            child: Text(tr.shotListFloorPlanSuggestedSetMenuAction(suggestedSetName ?? "")),
          ),
        if (canLinkExisting)
          SubmenuButton(
            menuChildren: _buildLinkExistingSetMenuItems(),
            child: Text(tr.shotListFloorPlanLinkExistingSetMenuAction),
          ),
        if (canCreate)
          SubmenuButton(
            menuChildren: _buildCreateSetMenuItems(tr),
            child: Text(tr.shotListFloorPlanCreateSetMenuAction),
          ),
        if (canDuplicate || canCopyBlocking) const Divider(height: 1),
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

  /// The `Link an existing set ▸` submenu's own entries: a disabled row naming each location,
  /// then one entry per set it holds that isn't already linked to the selected sequence.
  List<Widget> _buildLinkExistingSetMenuItems() => [
    for (final (locationName, groupSets) in linkableSetsByLocation) ...[
      MenuItemButton(child: Text(locationName)),
      for (final (id, name) in groupSets)
        MenuItemButton(onPressed: () => onSetLinkRequested!(id), child: Text(name)),
    ],
  ];

  /// The `Create a set ▸` submenu's own entries: one per existing location, then `New location…` —
  /// [OcptFloorPlanSetTabs.onSetCreationRequested] itself decides what a null `locationId` means
  /// (`OcptLocationsService.createSetLinkedToScene`'s own reading: mint a location of its own).
  List<Widget> _buildCreateSetMenuItems(Tr tr) => [
    for (final (id, name) in locationsForCreation)
      MenuItemButton(onPressed: () => onSetCreationRequested!(id), child: Text(name)),
    if (locationsForCreation.isNotEmpty) const Divider(height: 1),
    MenuItemButton(
      onPressed: () => onSetCreationRequested!(null),
      child: Text(tr.shotListFloorPlanNewLocationMenuAction),
    ),
  ];
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
