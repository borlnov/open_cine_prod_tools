// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_scene_element_link.dart';
import 'package:open_cine_prod_tools/models/ocpt_scene_ref.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_sheet_card.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_decimal_input.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_resources_labels.dart';

/// How long a row waits after the last keystroke before reporting what was typed into it.
const Duration _localFieldDebounce = Duration(milliseconds: 600);

/// The width of a row's per-scene quantity field: a quantity is a number, never a sentence.
const double _quantityFieldWidth = 96;

/// "Scenes needing it": one row per `scene_elements` link — the scene it names, how many of the
/// element that scene needs, whatever that scene has to say about it, and the control unlinking it
/// — over the picker adding another.
///
/// A row rather than a chip, unlike a set's own scenes: a link carries a quantity and a note of its
/// own, and "2 verres, dont un cassé" is a fact about scene 12 rather than about the glasses. The
/// element's own quantity stays what the catalogue says in general; the row overrides it for that
/// scene alone, and an empty row simply doesn't override anything.
///
/// The picker offers every scene the element is not already linked to, in the screenplay's own
/// order, with no suggestion of its own: a heading names a place, which is what a *set* is matched
/// against — nothing in `INT. CUISINE - NUIT` says a bicycle is needed there.
class OcptElementSheetScenesCard extends StatelessWidget {
  /// The links of the element this card belongs to, in the screenplay's own scene order.
  final List<OcptSceneElementLink> sceneLinks;

  /// Every scene of the project's screenplay, in source order.
  final List<OcptSceneRef> scenes;

  /// Called with a scene's id when the picker adds it, or null while it may not be used.
  final ValueChanged<String>? onSceneAssigned;

  /// Called with a link's id and its two fields once a local edit is ready to be written, or null
  /// while the sheet may not be written to.
  final void Function(String id, {required String quantity, required String notes})? onLinkUpdated;

  /// Called with a link's id when its remove control is clicked, or null while it may not be used.
  final ValueChanged<String>? onLinkRemoved;

  /// Class constructor
  const OcptElementSheetScenesCard({
    super.key,
    required this.sceneLinks,
    required this.scenes,
    required this.onSceneAssigned,
    required this.onLinkUpdated,
    required this.onLinkRemoved,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final sceneById = {for (final scene in scenes) scene.id: scene};

    return OcptResourcesSheetCard(
      title: tr.resourcesElementScenesCardTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (sceneLinks.isEmpty)
            Text(
              tr.resourcesElementNoSceneHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          for (final link in sceneLinks)
            if (sceneById[link.sceneId] case final scene?) ...[
              _OcptSceneLinkRow(
                key: ValueKey(link.id),
                link: link,
                scene: scene,
                onUpdated: onLinkUpdated == null
                    ? null
                    : ({required quantity, required notes}) =>
                          onLinkUpdated!(link.id, quantity: quantity, notes: notes),
                onRemoved: onLinkRemoved == null ? null : () => onLinkRemoved!(link.id),
              ),
              const SizedBox(height: 8),
            ],
          if (onSceneAssigned != null) _buildScenePicker(context, tr),
        ],
      ),
    );
  }

  /// The `+ Scene` picker: every scene this element is not already needed in, in the screenplay's
  /// own order. Renders nothing at all once there is none left to offer.
  Widget _buildScenePicker(BuildContext context, Tr tr) {
    final onSceneAssigned = this.onSceneAssigned!;
    final linkedSceneIds = {for (final link in sceneLinks) link.sceneId};
    final offered = [
      for (final scene in scenes)
        if (!linkedSceneIds.contains(scene.id)) scene,
    ];

    if (offered.isEmpty) {
      return const SizedBox.shrink();
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: PopupMenuButton<String>(
        tooltip: "",
        onSelected: onSceneAssigned,
        itemBuilder: (context) => [
          for (final scene in offered)
            PopupMenuItem<String>(value: scene.id, child: Text(ocptSceneRefLabel(scene))),
        ],
        child: Chip(
          avatar: const Icon(Icons.add, size: 14),
          label: Text(tr.resourcesAddSceneToElementAction),
        ),
      ),
    );
  }
}

/// One row of [OcptElementSheetScenesCard]: the scene, its own quantity and note, and the control
/// unlinking it.
class _OcptSceneLinkRow extends StatefulWidget {
  /// The link this row shows.
  final OcptSceneElementLink link;

  /// The scene the link names.
  final OcptSceneRef scene;

  /// Called with the row's two fields once a local edit is ready to be written, or null while the
  /// sheet may not be written to.
  final void Function({required String quantity, required String notes})? onUpdated;

  /// Called when the row's remove control is clicked, or null while it may not be used.
  final VoidCallback? onRemoved;

  /// Class constructor
  const _OcptSceneLinkRow({
    super.key,
    required this.link,
    required this.scene,
    required this.onUpdated,
    required this.onRemoved,
  });

  @override
  State<_OcptSceneLinkRow> createState() => _OcptSceneLinkRowState();
}

/// The state of [_OcptSceneLinkRow]: the row's own two controllers, and the debounce that turns
/// typing into an [_OcptSceneLinkRow.onUpdated] call.
///
/// The same discipline `OcptPersonSheetUnavailabilitiesCard`'s own row follows, and for the same
/// reason: these two fields belong to the link rather than to the element, so they are debounced
/// here and reported together instead of riding the bloc's own field-edit map. A fresh instance is
/// created for every distinct link id (the card keys each row by it), so switching to another
/// element disposes these rows and, with them, flushes whatever was still pending — see [dispose].
class _OcptSceneLinkRowState extends State<_OcptSceneLinkRow> {
  /// The per-scene quantity field's own controller.
  late final TextEditingController _quantityController = TextEditingController(
    text: widget.link.quantity,
  );

  /// The per-scene notes field's own controller.
  late final TextEditingController _notesController = TextEditingController(
    text: widget.link.notes,
  );

  /// The two fields' own focus node, flushing a pending edit the moment the row loses focus.
  final FocusNode _focusNode = FocusNode();

  /// The running local debounce timer, if any.
  Timer? _debounce;

  /// Whether a local edit is waiting to be flushed.
  bool _isDirty = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_flushOnFocusLost);
  }

  @override
  void dispose() {
    _flushIfDirty();
    _debounce?.cancel();
    _focusNode.dispose();
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// Flushes a pending edit the moment the row loses focus.
  void _flushOnFocusLost() {
    if (!_focusNode.hasFocus) {
      _flushIfDirty();
    }
  }

  /// Records that one of the two fields changed and (re)starts the debounce.
  void _onFieldChanged(String text) {
    _isDirty = true;
    _debounce?.cancel();
    _debounce = Timer(_localFieldDebounce, _flushIfDirty);
  }

  /// Reports the row's current fields, if a local edit is actually waiting.
  void _flushIfDirty() {
    _debounce?.cancel();
    if (!_isDirty) {
      return;
    }
    _isDirty = false;
    widget.onUpdated?.call(
      quantity: _quantityController.text,
      notes: _notesController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final onRemoved = widget.onRemoved;
    final isReadOnly = widget.onUpdated == null;

    // A [Focus] around the whole row rather than a node on each field: `hasFocus` is true while any
    // descendant holds the primary focus, so the listener fires once, when the caret leaves the row
    // altogether — moving from the quantity to the note is not a moment to write.
    return Focus(
      focusNode: _focusNode,
      skipTraversal: true,
      canRequestFocus: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(ocptRadiusLarge),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    ocptSceneRefLabel(widget.scene),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                if (onRemoved != null)
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    tooltip: tr.resourcesRemoveSceneFromElementTooltip,
                    onPressed: onRemoved,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: _quantityFieldWidth,
                  child: _buildField(
                    context,
                    controller: _quantityController,
                    label: tr.resourcesSceneElementQuantityLabel,
                    isReadOnly: isReadOnly,
                    isDecimal: true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildField(
                    context,
                    controller: _notesController,
                    label: tr.resourcesSceneElementNotesLabel,
                    isReadOnly: isReadOnly,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// One of the row's two fields: an uppercase, muted label over a themed text field, the same
  /// chrome `OcptResourcesSheetField` gives every other field of the mode — written here rather
  /// than reused because these two are driven by the row's own controllers and debounce, not by the
  /// bloc's pending-edit map.
  Widget _buildField(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    required bool isReadOnly,
    bool isDecimal = false,
  }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          readOnly: isReadOnly,
          onChanged: isReadOnly ? null : _onFieldChanged,
          inputFormatters: isDecimal ? ocptDecimalInputFormatters : null,
          keyboardType: isDecimal ? ocptDecimalKeyboardType : null,
          style: theme.textTheme.bodySmall,
          decoration: const InputDecoration(isDense: true),
        ),
      ],
    );
  }
}
