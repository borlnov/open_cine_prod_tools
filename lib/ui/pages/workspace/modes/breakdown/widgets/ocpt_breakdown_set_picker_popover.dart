// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_set.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_breakdown_labels.dart';
import 'package:open_cine_prod_tools/utils/ocpt_resources_search.dart';

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
/// the name a creation would use — pre-filled with [defaultName] (the place the scene's own
/// heading names), editable before either action. Painted into the app's own [Overlay], through an
/// [OverlayPortal] and a [LayerLink]/[CompositedTransformFollower] pair, so it is not clipped by the
/// right dock's `ListView` — the same idiom `OcptBreakdownTagPopoverAnchor` uses for the script
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

  @override
  State<OcptBreakdownSetPickerPopover> createState() => _OcptBreakdownSetPickerPopoverState();
}

class _OcptBreakdownSetPickerPopoverState extends State<OcptBreakdownSetPickerPopover> {
  /// Owns whether the overlay entry is currently inserted.
  final OverlayPortalController _controller = OverlayPortalController();

  /// Links the chip's own geometry to the popover's `CompositedTransformFollower`.
  final LayerLink _link = LayerLink();

  /// The field's own text, both the existing-sets filter and the name a creation would use.
  late final TextEditingController _textController = TextEditingController(text: widget.defaultName);

  /// The field's own focus, requested as soon as the popover appears.
  final FocusNode _fieldFocusNode = FocusNode();

  @override
  void didUpdateWidget(OcptBreakdownSetPickerPopover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.defaultName != widget.defaultName && !_controller.isShowing) {
      _textController.text = widget.defaultName;
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _fieldFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _controller,
        overlayChildBuilder: _buildOverlayChild,
        child: InkWell(
          onTap: _controller.show,
          mouseCursor: ocptClickableCursor,
          borderRadius: BorderRadius.circular(ocptRadiusLarge),
          child: Chip(
            avatar: const Icon(Icons.add, size: 14),
            label: Text(tr.breakdownSceneInspectorAddSetAction),
          ),
        ),
      ),
    );
  }

  /// The barrier closing the popover on an outside tap, and the panel itself, followed onto the
  /// chip and placed under it.
  Widget _buildOverlayChild(BuildContext overlayContext) => Stack(
    children: [
      Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _controller.hide,
        ),
      ),
      CompositedTransformFollower(
        link: _link,
        targetAnchor: Alignment.bottomLeft,
        offset: const Offset(0, _ocptBreakdownSetPickerPopoverGap),
        child: Focus(
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
              _controller.hide();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: _buildPanel(overlayContext),
        ),
      ),
    ],
  );

  /// The panel: the name field, the filtered existing-sets list and the create-in section.
  Widget _buildPanel(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return Material(
      elevation: 8,
      color: theme.colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(ocptRadiusMedium),
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
                controller: _textController,
                focusNode: _fieldFocusNode,
                autofocus: true,
                decoration: const InputDecoration(isDense: true),
                onChanged: (_) => setState(() {}),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildExistingSets(context, theme, tr),
                    _buildCreateSection(context, theme, tr),
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

  /// The existing sets not already linked to [OcptBreakdownSetPickerPopover.sceneId], filtered by
  /// the field's own text, the suggested one first — left out entirely once nothing matches.
  Widget _buildExistingSets(BuildContext context, ThemeData theme, Tr tr) {
    final suggested = <OcptSet>[];
    final others = <OcptSet>[];
    for (final set in widget.sets) {
      if (set.sceneIds.contains(widget.sceneId)) {
        continue;
      }
      if (!ocptResourcesSearchMatches(
        query: _textController.text,
        fields: [ocptBreakdownSetLabel(set, widget.locationNameById)],
      )) {
        continue;
      }

      (set.id == widget.suggestedSetId ? suggested : others).add(set);
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
          _buildRow(
            context,
            theme,
            tr.breakdownSceneInspectorSetSuggestedOption(
              ocptBreakdownSetLabel(set, widget.locationNameById),
            ),
            () {
              widget.onSetLinked(set.id);
              _controller.hide();
            },
          ),
        for (final set in others)
          _buildRow(
            context,
            theme,
            ocptBreakdownSetLabel(set, widget.locationNameById),
            () {
              widget.onSetLinked(set.id);
              _controller.hide();
            },
          ),
      ],
    );
  }

  /// The `Create "<field text>" in…` section: one entry per location, plus "in a new location".
  /// Left out entirely while the field's own trimmed text is empty — there is nothing to name a
  /// creation with then.
  Widget _buildCreateSection(BuildContext context, ThemeData theme, Tr tr) {
    final name = _textController.text.trim();
    if (name.isEmpty) {
      return const SizedBox.shrink();
    }

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
        for (final (id, locationName) in widget.locations)
          _buildRow(context, theme, tr.breakdownSceneInspectorCreateSetInOption(locationName), () {
            widget.onSetCreationRequested(name, id);
            _controller.hide();
          }),
        _buildRow(context, theme, tr.breakdownSceneInspectorCreateSetInNewLocationOption, () {
          widget.onSetCreationRequested(name, null);
          _controller.hide();
        }),
      ],
    );
  }

  /// One tappable row, shared by the existing-sets list and the create-in section.
  Widget _buildRow(BuildContext context, ThemeData theme, String label, VoidCallback onTap) => InkWell(
    onTap: onTap,
    mouseCursor: ocptClickableCursor,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall,
      ),
    ),
  );
}
