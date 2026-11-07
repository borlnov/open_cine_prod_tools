// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart' as ocpt_theme;
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_set.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_resources_search.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_breakdown_labels.dart';

/// The widest the popover's own panel is ever drawn, in logical pixels.
const double _ocptBreakdownSetPickerPopoverWidth = 300;

/// The tallest the popover's own panel is ever drawn before its middle (the existing-sets list and
/// the create-in section) starts scrolling, in logical pixels.
const double _ocptBreakdownSetPickerPopoverMaxHeight = 360;

/// The gap kept between the chip and the popover, in logical pixels.
const double _ocptBreakdownSetPickerPopoverGap = 6;

/// The `+ Set` chip a scene's breakdown sheet opens this popover from, and the popover itself: a
/// single control that both **links** an existing set to the scene and **creates** a new one,
/// replacing what used to be two separate controls side by side.
///
/// The popover's own text field is both the filter the existing-sets list is matched against and
/// the name a creation would use — pre-filled with [defaultName] (the place the scene's own heading
/// names), editable before either action. Painted into the app's own [Overlay], through an
/// [OverlayPortal] and a [LayerLink]/[CompositedTransformFollower] pair, so it is not clipped by
/// the right dock's `ListView` — the same idiom `OcptBreakdownTagPopoverAnchor` uses for the script
/// sheet's own tag popover, simplified here since this one is toggled by a tap rather than shown
/// automatically, and always drawn below the chip rather than flipping sides.
///
/// Closes on an outside tap, on `Escape`, or right after [onSetLinked]/[onSetCreationRequested] is
/// called — there is nothing left to do in it once either has fired.
class OcptBreakdownSetPickerPopover extends StatefulWidget {
  /// The field's initial text: the place the scene's own heading suggests, editable by the user
  /// before linking or creating.
  final String defaultName;

  /// The whole set catalogue, every location's sets flattened.
  final List<OcptSet> sets;

  /// The name of every live location, keyed by id, naming the place each of [sets] belongs to.
  final Map<String, String> locationNameById;

  /// The scene this popover is offered from, so [sets] already linked to it are left out of the
  /// existing-sets list.
  final String sceneId;

  /// The id of the set [sceneId]'s own heading suggests, or null while it suggests none. Shown
  /// first in the existing-sets list, marked as a suggestion.
  final String? suggestedSetId;

  /// Every live location of the project, `(id, name)`, offered as the place a created set is filed
  /// under, alongside the entry minting a location of its own for it.
  final List<(String, String)> locations;

  /// Called with a set's id when one of the existing-sets rows is clicked, linking the scene to it.
  final ValueChanged<String> onSetLinked;

  /// Called with the field's current trimmed text and the location a created set belongs to — null
  /// meaning "in a new location of its own" — when a create-in entry is clicked.
  final void Function(String name, String? locationId) onSetCreationRequested;

  /// Class constructor
  const OcptBreakdownSetPickerPopover({
    super.key,
    required this.defaultName,
    required this.sets,
    required this.locationNameById,
    required this.sceneId,
    required this.suggestedSetId,
    required this.locations,
    required this.onSetLinked,
    required this.onSetCreationRequested,
  });

  /// Create the [_OcptBreakdownSetPickerPopoverState] holding the state of the breakdown set picker
  /// popover.
  @override
  State<OcptBreakdownSetPickerPopover> createState() => _OcptBreakdownSetPickerPopoverState();
}

/// State of [OcptBreakdownSetPickerPopover]: owns the overlay controller, the layer link and the
/// name field's text controller.
class _OcptBreakdownSetPickerPopoverState extends State<OcptBreakdownSetPickerPopover> {
  /// Owns whether the overlay entry is currently inserted.
  final OverlayPortalController _controller = OverlayPortalController();

  /// Links the chip's own geometry to the popover's `CompositedTransformFollower`.
  final LayerLink _link = LayerLink();

  /// The field's own text, both the existing-sets filter and the name a creation would use.
  late final TextEditingController _textController = TextEditingController(
    text: widget.defaultName,
  );

  /// The field's own focus, requested as soon as the popover appears.
  final FocusNode _fieldFocusNode = FocusNode();

  /// Refill the name field with the new default name while the popover is closed.
  @override
  void didUpdateWidget(OcptBreakdownSetPickerPopover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.defaultName != widget.defaultName && !_controller.isShowing) {
      _textController.text = widget.defaultName;
    }
  }

  /// Build the breakdown set picker popover as a [CompositedTransformTarget].
  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _controller,
        overlayChildBuilder: (overlayContext) => _OverlayChild(
          link: _link,
          textController: _textController,
          fieldFocusNode: _fieldFocusNode,
          sets: widget.sets,
          locationNameById: widget.locationNameById,
          sceneId: widget.sceneId,
          suggestedSetId: widget.suggestedSetId,
          locations: widget.locations,
          onSetLinked: widget.onSetLinked,
          onSetCreationRequested: widget.onSetCreationRequested,
          onTextChanged: () => setState(() {}),
          onClose: _controller.hide,
        ),
        child: InkWell(
          onTap: _controller.show,
          mouseCursor: ocpt_theme.ocptClickableCursor,
          borderRadius: BorderRadius.circular(ocpt_theme.ocptRadiusLarge),
          child: Chip(
            avatar: const Icon(Icons.add, size: 14),
            label: Text(tr.breakdownSceneInspectorAddSetAction),
          ),
        ),
      ),
    );
  }

  /// Dispose [_textController] and [_fieldFocusNode].
  @override
  void dispose() {
    _textController.dispose();
    _fieldFocusNode.dispose();
    super.dispose();
  }
}

/// The barrier closing the popover on an outside tap, and the panel itself, followed onto the
/// chip and placed under it.
class _OverlayChild extends StatelessWidget {
  /// Links the chip's own geometry to the panel's `CompositedTransformFollower`.
  final LayerLink link;

  /// The field's own text, both the existing-sets filter and the name a creation would use.
  final TextEditingController textController;

  /// The field's own focus.
  final FocusNode fieldFocusNode;

  /// The whole set catalogue, every location's sets flattened.
  final List<OcptSet> sets;

  /// The name of every live location, keyed by id.
  final Map<String, String> locationNameById;

  /// The scene the popover is offered from.
  final String sceneId;

  /// The id of the set the scene's heading suggests, or null while it suggests none.
  final String? suggestedSetId;

  /// Every live location of the project, `(id, name)`.
  final List<(String, String)> locations;

  /// Called with a set's id when an existing-sets row is clicked.
  final ValueChanged<String> onSetLinked;

  /// Called with the name and the location (null for a new one) when a create-in entry is clicked.
  final void Function(String name, String? locationId) onSetCreationRequested;

  /// Called whenever the field's text changes, so the lists are filtered again.
  final VoidCallback onTextChanged;

  /// Called to close the popover.
  final VoidCallback onClose;

  /// Class constructor
  const _OverlayChild({
    required this.link,
    required this.textController,
    required this.fieldFocusNode,
    required this.sets,
    required this.locationNameById,
    required this.sceneId,
    required this.suggestedSetId,
    required this.locations,
    required this.onSetLinked,
    required this.onSetCreationRequested,
    required this.onTextChanged,
    required this.onClose,
  });

  /// Build the overlay child as a [Stack].
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(
        child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onClose),
      ),
      CompositedTransformFollower(
        link: link,
        targetAnchor: Alignment.bottomLeft,
        offset: const Offset(0, _ocptBreakdownSetPickerPopoverGap),
        child: Focus(
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
              onClose();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: _Panel(
            textController: textController,
            fieldFocusNode: fieldFocusNode,
            sets: sets,
            locationNameById: locationNameById,
            sceneId: sceneId,
            suggestedSetId: suggestedSetId,
            locations: locations,
            onSetLinked: onSetLinked,
            onSetCreationRequested: onSetCreationRequested,
            onTextChanged: onTextChanged,
            onClose: onClose,
          ),
        ),
      ),
    ],
  );
}

/// The panel: the name field, the filtered existing-sets list and the create-in section.
class _Panel extends StatelessWidget {
  /// The field's own text, both the existing-sets filter and the name a creation would use.
  final TextEditingController textController;

  /// The field's own focus.
  final FocusNode fieldFocusNode;

  /// The whole set catalogue, every location's sets flattened.
  final List<OcptSet> sets;

  /// The name of every live location, keyed by id.
  final Map<String, String> locationNameById;

  /// The scene the popover is offered from.
  final String sceneId;

  /// The id of the set the scene's heading suggests, or null while it suggests none.
  final String? suggestedSetId;

  /// Every live location of the project, `(id, name)`.
  final List<(String, String)> locations;

  /// Called with a set's id when an existing-sets row is clicked.
  final ValueChanged<String> onSetLinked;

  /// Called with the name and the location (null for a new one) when a create-in entry is clicked.
  final void Function(String name, String? locationId) onSetCreationRequested;

  /// Called whenever the field's text changes.
  final VoidCallback onTextChanged;

  /// Called to close the popover.
  final VoidCallback onClose;

  /// Class constructor
  const _Panel({
    required this.textController,
    required this.fieldFocusNode,
    required this.sets,
    required this.locationNameById,
    required this.sceneId,
    required this.suggestedSetId,
    required this.locations,
    required this.onSetLinked,
    required this.onSetCreationRequested,
    required this.onTextChanged,
    required this.onClose,
  });

  /// Build the panel as a [Material].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return Material(
      elevation: 8,
      color: theme.colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(ocpt_theme.ocptRadiusMedium),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: _ocptBreakdownSetPickerPopoverWidth,
          maxHeight: _ocptBreakdownSetPickerPopoverMaxHeight,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Text(
                tr.breakdownSceneInspectorSetPickerNameLabel.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: TextField(
                controller: textController,
                focusNode: fieldFocusNode,
                autofocus: true,
                decoration: const InputDecoration(isDense: true),
                onChanged: (_) => onTextChanged(),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ExistingSets(
                      query: textController.text,
                      sets: sets,
                      locationNameById: locationNameById,
                      sceneId: sceneId,
                      suggestedSetId: suggestedSetId,
                      onSetLinked: onSetLinked,
                      onClose: onClose,
                    ),
                    _CreateSection(
                      name: textController.text.trim(),
                      locations: locations,
                      onSetCreationRequested: onSetCreationRequested,
                      onClose: onClose,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

/// The existing sets not already linked to the scene, filtered by the field's own text, the
/// suggested one first — left out entirely once nothing matches.
class _ExistingSets extends StatelessWidget {
  /// The field's current text, matched against each set's label.
  final String query;

  /// The whole set catalogue, every location's sets flattened.
  final List<OcptSet> sets;

  /// The name of every live location, keyed by id.
  final Map<String, String> locationNameById;

  /// The scene the popover is offered from.
  final String sceneId;

  /// The id of the set the scene's heading suggests, or null while it suggests none.
  final String? suggestedSetId;

  /// Called with a set's id when its row is clicked.
  final ValueChanged<String> onSetLinked;

  /// Called to close the popover.
  final VoidCallback onClose;

  /// Class constructor
  const _ExistingSets({
    required this.query,
    required this.sets,
    required this.locationNameById,
    required this.sceneId,
    required this.suggestedSetId,
    required this.onSetLinked,
    required this.onClose,
  });

  /// Build the existing sets as a [Column].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    final suggested = <OcptSet>[];
    final others = <OcptSet>[];
    for (final set in sets) {
      if (set.sceneIds.contains(sceneId)) {
        continue;
      }
      if (!ocptResourcesSearchMatches(
        query: query,
        fields: [ocptBreakdownSetLabel(set, locationNameById)],
      )) {
        continue;
      }

      (set.id == suggestedSetId ? suggested : others).add(set);
    }

    if (suggested.isEmpty && others.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 2),
          child: Text(
            tr.breakdownSceneInspectorSetPickerExistingLabel.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        for (final set in suggested)
          _Row(
            label: tr.breakdownSceneInspectorSetSuggestedOption(
              ocptBreakdownSetLabel(set, locationNameById),
            ),
            onTap: () {
              onSetLinked(set.id);
              onClose();
            },
          ),
        for (final set in others)
          _Row(
            label: ocptBreakdownSetLabel(set, locationNameById),
            onTap: () {
              onSetLinked(set.id);
              onClose();
            },
          ),
      ],
    );
  }
}

/// The `Create "<field text>" in…` section: one entry per location, plus "in a new location".
/// Left out entirely while the field's own trimmed text is empty — there is nothing to name a
/// creation with then.
class _CreateSection extends StatelessWidget {
  /// The field's current trimmed text, the name a creation would use.
  final String name;

  /// Every live location of the project, `(id, name)`.
  final List<(String, String)> locations;

  /// Called with the name and the location (null for a new one) when an entry is clicked.
  final void Function(String name, String? locationId) onSetCreationRequested;

  /// Called to close the popover.
  final VoidCallback onClose;

  /// Class constructor
  const _CreateSection({
    required this.name,
    required this.locations,
    required this.onSetCreationRequested,
    required this.onClose,
  });

  /// Build the create section as a [Column].
  @override
  Widget build(BuildContext context) {
    if (name.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
          child: Text(
            tr.breakdownSceneInspectorCreateSetMenuTitle(name),
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        for (final (id, locationName) in locations)
          _Row(
            label: tr.breakdownSceneInspectorCreateSetInOption(locationName),
            onTap: () {
              onSetCreationRequested(name, id);
              onClose();
            },
          ),
        _Row(
          label: tr.breakdownSceneInspectorCreateSetInNewLocationOption,
          onTap: () {
            onSetCreationRequested(name, null);
            onClose();
          },
        ),
      ],
    );
  }
}

/// One tappable row, shared by the existing-sets list and the create-in section.
class _Row extends StatelessWidget {
  /// The row's text.
  final String label;

  /// Called when the row is clicked.
  final VoidCallback onTap;

  /// Class constructor
  const _Row({required this.label, required this.onTap});

  /// Build the row as an [InkWell].
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    mouseCursor: ocpt_theme.ocptClickableCursor,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ),
  );
}
