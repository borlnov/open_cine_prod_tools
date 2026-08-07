// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_breakdown_palette.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_element.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_sheet_card.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_resources_labels.dart';

/// How long a row waits after the last keystroke before reporting what was typed into it.
const Duration _localFieldDebounce = Duration(milliseconds: 600);

/// The side of the little square carrying a category's colour beside a heading.
const double _categoryDotSide = 8;

/// "Their things": what the role wears, carries and is made up with — one row per `role_elements`
/// link, grouped under a heading per element category, over the picker adding another.
///
/// `OcptElementSheetScenesCard`'s sibling, and deliberately built the same way: a row rather than a
/// chip, because a link carries a note of its own — "manteau taché à partir de la séquence 12" is a
/// fact about this role's use of the coat, not about the coat. It carries no quantity, unlike a
/// scene's own link: a role wears the coat or they do not.
///
/// **Every category is offered**, and the grouping is read-time work over a flat table (see
/// `OcptRoleElementsTable`): a character's car, their dog and their stunt harness are facts about
/// them exactly as their coat is, so nothing here restricts the picker to costumes, props and
/// make-up. The headings are what make a long list readable, and they carry the same per-category
/// colour the breakdown mode paints with — a category reads the same everywhere in the app.
///
/// The links come in on [OcptElement.roleLinks] rather than on the role: one service loads the
/// table, one model carries it, and the card scans the catalogue for the links naming its role, so
/// this card and the element sheet's own reverse read-out cannot disagree.
class OcptRoleSheetElementsCard extends StatelessWidget {
  /// The role this card belongs to.
  final String roleId;

  /// The whole elements catalogue, in its own `sortKey` order: what this card reads its links out
  /// of, and what the picker offers.
  final List<OcptElement> elements;

  /// Called with an element's id when the picker adds it, or null while it may not be used.
  final ValueChanged<String>? onElementLinked;

  /// Called with a link's id and its note once a local edit is ready to be written, or null while
  /// the sheet may not be written to.
  final void Function(String id, String notes)? onLinkUpdated;

  /// Called with a link's id when its remove control is clicked, or null while it may not be used.
  final ValueChanged<String>? onLinkRemoved;

  /// Class constructor
  const OcptRoleSheetElementsCard({
    super.key,
    required this.roleId,
    required this.elements,
    required this.onElementLinked,
    required this.onLinkUpdated,
    required this.onLinkRemoved,
  });

  /// The elements this role is linked to, paired with the id of the link saying so, in the
  /// catalogue's own order.
  ///
  /// A role never holds two live links onto one element (`OcptElementsService.addRoleElement`
  /// revives rather than duplicates), so the first match is the only one.
  List<(OcptElement, String)> get _linkedElements => [
    for (final element in elements)
      for (final link in element.roleLinks)
        if (link.roleId == roleId) (element, link.id),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final linked = _linkedElements;

    return OcptResourcesSheetCard(
      title: tr.resourcesRoleElementsCardTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (linked.isEmpty)
            Text(
              tr.resourcesRoleNoElementHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          for (final category in OcptElementCategory.values)
            if (_ofCategory(linked, category) case final rows when rows.isNotEmpty) ...[
              _buildCategoryHeading(context, tr, category),
              for (final (element, linkId) in rows) ...[
                _OcptRoleElementRow(
                  key: ValueKey(linkId),
                  element: element,
                  notes: _notesOf(element, linkId),
                  onUpdated: onLinkUpdated == null
                      ? null
                      : (notes) => onLinkUpdated!(linkId, notes),
                  onRemoved: onLinkRemoved == null ? null : () => onLinkRemoved!(linkId),
                ),
                const SizedBox(height: 8),
              ],
            ],
          if (onElementLinked != null) _buildElementPicker(context, tr, linked),
        ],
      ),
    );
  }

  /// The entries of [linked] whose element belongs to [category], in the order they came in.
  List<(OcptElement, String)> _ofCategory(
    List<(OcptElement, String)> linked,
    OcptElementCategory category,
  ) => [
    for (final entry in linked)
      if (entry.$1.category == category) entry,
  ];

  /// The note link [linkId] carries on [element].
  String _notesOf(OcptElement element, String linkId) =>
      element.roleLinks.firstWhere((link) => link.id == linkId).notes;

  /// A category's heading: its own colour, then its localized name — the same colour the breakdown
  /// mode gives that category, since a category must read the same in every view.
  Widget _buildCategoryHeading(BuildContext context, Tr tr, OcptElementCategory category) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 6),
      child: Row(
        children: [
          Container(
            width: _categoryDotSide,
            height: _categoryDotSide,
            decoration: BoxDecoration(
              color: Color(
                ocptBreakdownColorOf(kind: OcptBreakdownTargetKind.element, category: category),
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            ocptElementCategoryLabel(tr, category).toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// The `+ Element` picker: every element this role is not already linked to, grouped by category
  /// the way the left dock's own list heads it. Renders nothing at all once there is none left to
  /// offer.
  Widget _buildElementPicker(
    BuildContext context,
    Tr tr,
    List<(OcptElement, String)> linked,
  ) {
    final onElementLinked = this.onElementLinked!;
    final linkedIds = {for (final (element, _) in linked) element.id};
    final offered = [
      for (final element in elements)
        if (!linkedIds.contains(element.id)) element,
    ];

    if (offered.isEmpty) {
      return const SizedBox.shrink();
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: PopupMenuButton<String>(
        tooltip: "",
        onSelected: onElementLinked,
        itemBuilder: (context) => [
          for (final category in OcptElementCategory.values)
            if (offered.where((element) => element.category == category).toList()
                case final categoryElements when categoryElements.isNotEmpty) ...[
              PopupMenuItem<String>(
                enabled: false,
                height: 28,
                child: Text(
                  ocptElementCategoryLabel(tr, category).toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
              for (final element in categoryElements)
                PopupMenuItem<String>(
                  value: element.id,
                  child: Text(_elementLabel(element)),
                ),
            ],
        ],
        child: Chip(
          avatar: const Icon(Icons.add, size: 14),
          label: Text(tr.resourcesAddElementToRoleAction),
        ),
      ),
    );
  }

  /// How an element reads in this card and its picker: its name, prefixed by the code the app
  /// minted for it when it has one.
  static String _elementLabel(OcptElement element) =>
      element.code.isEmpty ? element.name : "${element.code} · ${element.name}";
}

/// One row of [OcptRoleSheetElementsCard]: the element, this role's own note about it, and the
/// control unlinking it.
class _OcptRoleElementRow extends StatefulWidget {
  /// The element this row shows.
  final OcptElement element;

  /// The note the link carries.
  final String notes;

  /// Called with the row's note once a local edit is ready to be written, or null while the sheet
  /// may not be written to.
  final ValueChanged<String>? onUpdated;

  /// Called when the row's remove control is clicked, or null while it may not be used.
  final VoidCallback? onRemoved;

  /// Class constructor
  const _OcptRoleElementRow({
    super.key,
    required this.element,
    required this.notes,
    required this.onUpdated,
    required this.onRemoved,
  });

  @override
  State<_OcptRoleElementRow> createState() => _OcptRoleElementRowState();
}

/// The state of [_OcptRoleElementRow]: the row's own controller, and the debounce that turns typing
/// into an [_OcptRoleElementRow.onUpdated] call.
///
/// The same discipline `OcptElementSheetScenesCard`'s own row follows, and for the same reason: the
/// note belongs to the link rather than to the role, so it is debounced here and reported from here
/// instead of riding the bloc's own field-edit map. A fresh instance is created for every distinct
/// link id (the card keys each row by it), so switching to another role disposes these rows and,
/// with them, flushes whatever was still pending — see [dispose].
class _OcptRoleElementRowState extends State<_OcptRoleElementRow> {
  /// The note field's own controller.
  late final TextEditingController _notesController = TextEditingController(text: widget.notes);

  /// The field's own focus node, flushing a pending edit the moment the row loses focus.
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
    _notesController.dispose();
    super.dispose();
  }

  /// Flushes a pending edit the moment the row loses focus.
  void _flushOnFocusLost() {
    if (!_focusNode.hasFocus) {
      _flushIfDirty();
    }
  }

  /// Records that the note changed and (re)starts the debounce.
  void _onFieldChanged(String text) {
    _isDirty = true;
    _debounce?.cancel();
    _debounce = Timer(_localFieldDebounce, _flushIfDirty);
  }

  /// Reports the row's current note, if a local edit is actually waiting.
  void _flushIfDirty() {
    _debounce?.cancel();
    if (!_isDirty) {
      return;
    }
    _isDirty = false;
    widget.onUpdated?.call(_notesController.text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final onRemoved = widget.onRemoved;
    final isReadOnly = widget.onUpdated == null;

    // A [Focus] around the whole row rather than a node on the field, exactly as the scenes card's
    // own row does it: the listener then fires when the caret leaves the row altogether.
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
                    OcptRoleSheetElementsCard._elementLabel(widget.element),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                if (onRemoved != null)
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    tooltip: tr.resourcesRemoveElementFromRoleTooltip,
                    onPressed: onRemoved,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              tr.resourcesRoleElementNotesLabel.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _notesController,
              readOnly: isReadOnly,
              onChanged: isReadOnly ? null : _onFieldChanged,
              style: theme.textTheme.bodySmall,
              decoration: const InputDecoration(isDense: true),
            ),
          ],
        ),
      ),
    );
  }
}
