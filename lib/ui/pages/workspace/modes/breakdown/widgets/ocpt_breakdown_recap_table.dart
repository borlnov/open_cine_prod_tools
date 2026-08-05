// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_scene.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_target.dart';
import 'package:open_cine_prod_tools/models/ocpt_element.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_empty_mode.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_breakdown_labels.dart';
import 'package:open_cine_prod_tools/utils/ocpt_breakdown_legend.dart';
import 'package:open_cine_prod_tools/utils/ocpt_breakdown_search.dart';

/// The narrowest the `Element` column is ever drawn, in logical pixels — past this, a very narrow
/// window scrolls the table horizontally rather than crushing the name column.
const double _ocptRecapElementColumnMinWidth = 220;

/// The `Status` column's own fixed width, in logical pixels.
const double _ocptRecapStatusColumnWidth = 110;

/// The `Owner` column's own fixed width, in logical pixels.
const double _ocptRecapOwnerColumnWidth = 120;

/// One scene column's own fixed width, in logical pixels.
const double _ocptRecapSceneColumnWidth = 52;

/// The `Occ.` column's own fixed width, in logical pixels.
const double _ocptRecapOccurrenceColumnWidth = 44;

/// The narrowest the whole table is ever drawn, in logical pixels — a real film has many scene
/// columns, so the table scrolls horizontally inside its own container well before it would
/// overflow, rather than ever being crushed thinner than this.
const double _ocptRecapMinTableWidth = 820;

/// The diameter of a scene cell's filled dot — the target is tagged in that scene — in logical
/// pixels.
const double _ocptRecapFilledDotDiameter = 8;

/// The diameter of a scene cell's muted dot — the target is **not** tagged in that scene — in
/// logical pixels: small enough that a row of them reads as background, not as content.
const double _ocptRecapMutedDotDiameter = 4;

/// The opacity a muted dot's own colour is drawn at.
const double _ocptRecapMutedDotAlpha = 0.35;

/// The room the vertical scroll bar's own thumb takes at the right edge of the rows, in logical
/// pixels — read off the ambient [ScrollbarThemeData] rather than repeated here, so the gutter
/// follows `ocpt_theme.dart`'s own scroll bar rather than drifting from it.
///
/// A desktop scroll bar is painted **over** the viewport it scrolls, and this table's own last
/// column sits hard against that edge: without a gutter, the thumb covers the `Occ.` count. The
/// rows are therefore laid out this much narrower than the table, and the header row carries a
/// trailing spacer of the same width so its columns stay aligned with theirs.
double _ocptRecapScrollbarGutterOf(BuildContext context) {
  final scrollbarTheme = Theme.of(context).scrollbarTheme;
  final thickness = scrollbarTheme.thickness?.resolve(const {}) ?? 0;

  return thickness + 2 * (scrollbarTheme.crossAxisMargin ?? 0);
}

/// The breakdown mode's recap view: a scrollable cross-table, one row per tagged target, one
/// column per scene, grouped by category — the mock-up's own cross-table, over the tags and the
/// three catalogues the app already reconciles from the screenplay and the resources mode, rather
/// than the mock-up's own flat, invented data model.
///
/// Grouping reuses `ocptBreakdownLegendEntriesOf` rather than re-deriving it, in its own order
/// (element categories in enum order, then roles, then sets) and with its own colour — the very
/// same function the legend and the scene panel's own bars read, so the three surfaces can never
/// disagree about what "one category" means or how many targets fall under it. A group whose every
/// target was filtered out by [searchQuery] (below) renders no header at all, rather than an empty
/// one.
///
/// [searchQuery] filters the table's **rows** only — a role or a set's target name, its category
/// label, and — element targets only — its sub-category, its owner's name and its notes
/// (`ocptBreakdownRecapRowMatches`) — and never its scene columns: every scene stays, which is what
/// lets a reader see, in one line, where the thing they just found falls across the whole film.
/// [scenes], [elements] and [people] are the loaded snapshot's own raw lists, resolved here (never
/// added onto `OcptBreakdownTarget` itself, which deliberately stays minimal) into each row's
/// notes and owner name; a role or a set carries neither a status nor an owner
/// (`OcptBreakdownTarget.status` is null for either, and `elements.ownerPersonId` is an element's
/// own column, not an equivalent fact of a role's casting or a set's location), so both cells are
/// simply left empty for those two kinds rather than filled with something that would misread as
/// one.
///
/// Purely presentational, like every other widget of this mode: it renders and reports every click
/// upward, reading nothing off a manager. A row's click only selects its target
/// (`onTargetSelected`), which writes nothing to the project database — so, unlike the target and
/// scene inspectors, this table needs no `isReadOnly` flag at all: there is nothing here for a
/// previewed version to withhold.
class OcptBreakdownRecapTable extends StatelessWidget {
  /// Every scene of the loaded snapshot, in source order — one column per entry, whatever
  /// [searchQuery] holds.
  final List<OcptBreakdownScene> scenes;

  /// Every tagged target of the loaded snapshot.
  final List<OcptBreakdownTarget> targets;

  /// The whole `elements` catalogue, resolved here into a row's notes, sub-category and owner —
  /// `OcptBreakdownSnapshot.elements`.
  final List<OcptElement> elements;

  /// The whole address book, resolved here into an element target's owner name —
  /// `OcptBreakdownSnapshot.people`.
  final List<OcptPerson> people;

  /// The header's own search field, as typed — filters the table's rows, see this class's own doc
  /// comment.
  final String searchQuery;

  /// The `(kind, id)` of the currently selected target, or null while none is — the row it names is
  /// tinted.
  final (OcptBreakdownTargetKind, String)? selectedTargetRef;

  /// Called with a row's target kind, its id and its first scene's id when it is clicked — the same
  /// event a tagged word's click in the script view already dispatches.
  final void Function(OcptBreakdownTargetKind kind, String id, String sceneId) onTargetSelected;

  /// Class constructor
  const OcptBreakdownRecapTable({
    super.key,
    required this.scenes,
    required this.targets,
    required this.elements,
    required this.people,
    required this.searchQuery,
    required this.selectedTargetRef,
    required this.onTargetSelected,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    if (targets.isEmpty) {
      return OcptWorkspaceEmptyMode(
        icon: Icons.grid_view_outlined,
        message: tr.breakdownRecapNothingTaggedHint,
      );
    }

    final elementById = {for (final element in elements) element.id: element};
    final personById = {for (final person in people) person.id: person};

    final matchingTargets = [
      for (final target in targets)
        if (_matches(tr, target, elementById, personById)) target,
    ];

    if (matchingTargets.isEmpty) {
      return OcptWorkspaceEmptyMode(
        icon: Icons.search_off,
        message: tr.breakdownRecapNoMatchesHint(searchQuery),
      );
    }

    final matchingByKey = <OcptBreakdownLegendKey, List<OcptBreakdownTarget>>{};
    for (final target in matchingTargets) {
      matchingByKey.putIfAbsent(ocptBreakdownLegendKeyOf(target), () => []).add(target);
    }
    for (final group in matchingByKey.values) {
      group.sort((a, b) => a.name.compareTo(b.name));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final scrollbarGutter = _ocptRecapScrollbarGutterOf(context);
        final fixedWidth =
            _ocptRecapStatusColumnWidth +
            _ocptRecapOwnerColumnWidth +
            _ocptRecapOccurrenceColumnWidth +
            scenes.length * _ocptRecapSceneColumnWidth +
            scrollbarGutter;
        final elementWidth = math.max(
          _ocptRecapElementColumnMinWidth,
          constraints.maxWidth - fixedWidth,
        );
        final tableWidth = math.max(_ocptRecapMinTableWidth, elementWidth + fixedWidth);

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: tableWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _RecapHeaderRow(
                  elementWidth: elementWidth,
                  scenes: scenes,
                  scrollbarGutter: scrollbarGutter,
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.only(right: scrollbarGutter),
                    children: [
                      for (final entry in ocptBreakdownLegendEntriesOf(targets))
                        if (matchingByKey[entry.key] case final groupTargets?)
                          _RecapGroupSection(
                            entry: entry,
                            targets: groupTargets,
                            elementById: elementById,
                            personById: personById,
                            scenes: scenes,
                            elementWidth: elementWidth,
                            selectedTargetRef: selectedTargetRef,
                            onTargetSelected: onTargetSelected,
                          ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Whether [target] matches [searchQuery], resolving its notes/sub-category/owner off
  /// [elementById]/[personById] first — see `ocptBreakdownRecapRowMatches`'s own doc comment for why
  /// a role or a set simply never passes those three.
  bool _matches(
    Tr tr,
    OcptBreakdownTarget target,
    Map<String, OcptElement> elementById,
    Map<String, OcptPerson> personById,
  ) {
    final element = target.kind == OcptBreakdownTargetKind.element ? elementById[target.id] : null;
    final ownerPersonId = element?.ownerPersonId;
    final owner = ownerPersonId == null ? null : personById[ownerPersonId];

    return ocptBreakdownRecapRowMatches(
      query: searchQuery,
      targetName: target.name,
      categoryLabel: ocptBreakdownLegendKeyLabel(tr, ocptBreakdownLegendKeyOf(target)),
      subCategory: element?.subCategory,
      ownerName: owner?.displayName,
      notes: element?.notes,
    );
  }
}

/// The table's own sticky header row: `Element`, `Status`, `Owner`, one column per scene labelled
/// with its own display number, then `Occ.`.
class _RecapHeaderRow extends StatelessWidget {
  /// The `Element` column's own width, computed by the table to fill whatever room the scene
  /// columns leave.
  final double elementWidth;

  /// Every scene of the loaded snapshot, one column each.
  final List<OcptBreakdownScene> scenes;

  /// The width of the trailing spacer this row ends on, keeping its own columns aligned with the
  /// rows underneath — which are laid out that much narrower, so the vertical scroll bar's thumb
  /// has somewhere of its own to sit (see [_ocptRecapScrollbarGutterOf]).
  final double scrollbarGutter;

  /// Class constructor
  const _RecapHeaderRow({
    required this.elementWidth,
    required this.scenes,
    required this.scrollbarGutter,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: elementWidth,
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text(tr.breakdownRecapColumnElement.toUpperCase(), style: labelStyle),
              ),
            ),
            SizedBox(
              width: _ocptRecapStatusColumnWidth,
              child: Text(tr.breakdownRecapColumnStatus.toUpperCase(), style: labelStyle),
            ),
            SizedBox(
              width: _ocptRecapOwnerColumnWidth,
              child: Text(tr.breakdownRecapColumnOwner.toUpperCase(), style: labelStyle),
            ),
            for (final scene in scenes)
              SizedBox(
                width: _ocptRecapSceneColumnWidth,
                child: Center(
                  child: Text(
                    tr.breakdownRecapSceneColumnLabel(scene.displayNumber),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: labelStyle,
                  ),
                ),
              ),
            SizedBox(
              width: _ocptRecapOccurrenceColumnWidth,
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  tr.breakdownRecapColumnOccurrences.toUpperCase(),
                  textAlign: TextAlign.right,
                  style: labelStyle,
                ),
              ),
            ),
            SizedBox(width: scrollbarGutter),
          ],
        ),
      ),
    );
  }
}

/// One category (or role/set) group of the recap: [entry]'s own swatch, label and row count, then
/// one [_RecapRow] per target of [targets], alphabetised by name.
class _RecapGroupSection extends StatelessWidget {
  /// The legend entry this section groups under — its colour and its key's label, never its own
  /// `OcptBreakdownLegendEntry.count`: that counts every target of the whole screenplay, while this
  /// section's own row count is [targets]' length, the table's own search already applied by the
  /// caller.
  final OcptBreakdownLegendEntry entry;

  /// This group's own targets, matching [entry]'s key, already filtered by the search and sorted by
  /// name.
  final List<OcptBreakdownTarget> targets;

  /// `{elementId: element}`, resolved once by the table.
  final Map<String, OcptElement> elementById;

  /// `{personId: person}`, resolved once by the table.
  final Map<String, OcptPerson> personById;

  /// Every scene of the loaded snapshot, one column each.
  final List<OcptBreakdownScene> scenes;

  /// The `Element` column's own width, forwarded from the table.
  final double elementWidth;

  /// The `(kind, id)` of the currently selected target, or null while none is.
  final (OcptBreakdownTargetKind, String)? selectedTargetRef;

  /// Called with a row's target kind, its id and its first scene's id when it is clicked.
  final void Function(OcptBreakdownTargetKind kind, String id, String sceneId) onTargetSelected;

  /// Class constructor
  const _RecapGroupSection({
    required this.entry,
    required this.targets,
    required this.elementById,
    required this.personById,
    required this.scenes,
    required this.elementWidth,
    required this.selectedTargetRef,
    required this.onTargetSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final color = Color(entry.color);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 8),
              Text(
                ocptBreakdownLegendKeyLabel(tr, entry.key).toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 8),
              Text(
                "${targets.length}",
                style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        for (final target in targets)
          _RecapRow(
            target: target,
            element: elementById[target.id],
            owner: _ownerOf(target),
            scenes: scenes,
            elementWidth: elementWidth,
            color: color,
            isSelected: selectedTargetRef == (target.kind, target.id),
            onTap: () => onTargetSelected(target.kind, target.id, target.sceneIds.first),
          ),
      ],
    );
  }

  /// [target]'s own owner, resolved off [elementById]/[personById], or null while [target] is a
  /// role/a set or its element carries none.
  OcptPerson? _ownerOf(OcptBreakdownTarget target) {
    final ownerPersonId = elementById[target.id]?.ownerPersonId;
    return ownerPersonId == null ? null : personById[ownerPersonId];
  }
}

/// One row of the recap: the target's own name (and notes, if any), its status pill, its owner, one
/// dot per scene and its occurrence count.
class _RecapRow extends StatelessWidget {
  /// The target this row shows.
  final OcptBreakdownTarget target;

  /// The raw `elements` row [target] resolves to, non-null only when [target] is an
  /// [OcptBreakdownTargetKind.element] — what this row's notes come from.
  final OcptElement? element;

  /// [target]'s own owner, non-null only when [target] is an element that has one.
  final OcptPerson? owner;

  /// Every scene of the loaded snapshot, one column each.
  final List<OcptBreakdownScene> scenes;

  /// The `Element` column's own width, forwarded from the table.
  final double elementWidth;

  /// This row's own group colour — [target]'s own dot in a scene it is tagged in is filled with it.
  final Color color;

  /// Whether [target] is the currently selected one.
  final bool isSelected;

  /// Called when this row is clicked.
  final VoidCallback onTap;

  /// Class constructor
  const _RecapRow({
    required this.target,
    required this.element,
    required this.owner,
    required this.scenes,
    required this.elementWidth,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notes = element?.notes ?? "";
    final status = target.status;

    return InkWell(
      onTap: onTap,
      mouseCursor: ocptClickableCursor,
      child: ColoredBox(
        color: isSelected
            ? theme.colorScheme.primary.withValues(alpha: ocptSelectedStateAlpha)
            : Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            children: [
              SizedBox(
                width: elementWidth,
                child: Padding(
                  padding: const EdgeInsets.only(left: 12, right: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        target.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                      if (notes.isNotEmpty)
                        Text(
                          notes,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: _ocptRecapStatusColumnWidth,
                child: status == null ? null : _RecapStatusPill(status: status),
              ),
              SizedBox(
                width: _ocptRecapOwnerColumnWidth,
                child: owner == null
                    ? null
                    : Text(
                        owner!.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
              ),
              for (final scene in scenes)
                SizedBox(
                  width: _ocptRecapSceneColumnWidth,
                  child: Center(
                    child: _RecapDot(
                      key: ValueKey((target.kind, target.id, scene.id)),
                      isTagged: target.sceneIds.contains(scene.id),
                      color: color,
                    ),
                  ),
                ),
              SizedBox(
                width: _ocptRecapOccurrenceColumnWidth,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    "${target.occurrenceCount}",
                    textAlign: TextAlign.right,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One scene cell's own dot: filled with [color] while [isTagged], a small muted dot otherwise.
class _RecapDot extends StatelessWidget {
  /// Whether the row's own target is tagged in this cell's own scene.
  final bool isTagged;

  /// The row's own group colour, used only while [isTagged].
  final Color color;

  /// Class constructor
  const _RecapDot({super.key, required this.isTagged, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final diameter = isTagged ? _ocptRecapFilledDotDiameter : _ocptRecapMutedDotDiameter;

    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        color: isTagged
            ? color
            : theme.colorScheme.onSurfaceVariant.withValues(alpha: _ocptRecapMutedDotAlpha),
        shape: BoxShape.circle,
      ),
    );
  }
}

/// The small status pill shown in a row's own `Status` column, mirroring
/// `OcptBreakdownSceneInspector`'s own private status pill — the recap has no shared file to put
/// one in without either mode reaching into the other's `widgets/` directory, so each keeps its
/// own tiny copy.
class _RecapStatusPill extends StatelessWidget {
  /// The status shown.
  final OcptElementStatus status;

  /// Class constructor
  const _RecapStatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = ocptElementStatusColor(context, status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: ocptSelectedStateAlpha),
        borderRadius: BorderRadius.circular(ocptRadiusLarge),
      ),
      child: Text(
        ocptElementStatusLabel(Tr.of(context), status),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
