// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_set.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_sheet.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_symbol.dart';
import 'package:open_cine_prod_tools/models/ocpt_location.dart';
import 'package:open_cine_prod_tools/models/ocpt_set.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_canvas_painter.dart';
import 'package:open_cine_prod_tools/utils/ocpt_floor_plan_fit.dart';

/// The width, in logical pixels, a gallery card's own thumbnail is drawn at.
const double _thumbnailWidth = 220;

/// The height, in logical pixels, a gallery card's own thumbnail is drawn at.
const double _thumbnailHeight = 130;

/// The width, in logical pixels, one gallery card takes — the thumbnail's own width plus its
/// surrounding padding.
const double _cardWidth = _thumbnailWidth + 24;

/// The floor plans view's own empty-state gallery, filling the centre while the selected sequence
/// has no linked Resources set yet (`docs/plans/storyboard.md`, §10.4): one card per live set of
/// the project, its own thumbnail, name, location and code, the heading's own suggestion
/// ([suggestedSetId]) first and starred, a click linking it ([onSetLinkRequested]) — and, under
/// the grid, a `Create a set…` action ([onSetCreationRequested]) opening the very same
/// location/`New location…` menu the set tabs' own `＋ Set` button does.
///
/// Both write callbacks are nullable and withheld under a read-only preview, mirroring every other
/// composite of this mode: a null [onSetLinkRequested] draws every card but stops it reacting to a
/// tap, a null [onSetCreationRequested] hides the `Create a set…` action outright (nothing to
/// create into while previewing).
class OcptFloorPlanSetGallery extends StatelessWidget {
  /// Every location of the project, each carrying its own live sets — the whole catalogue this
  /// gallery offers, project-wide (a set may already be linked to another episode's own sequence).
  final List<OcptLocation> locations;

  /// Every live Resources set's own **set-scope** symbols, keyed by set id — a card's own
  /// thumbnail content (the underlay is deliberately left out, see this class's own doc comment on
  /// [_OcptFloorPlanSetGalleryCard]).
  final Map<String, List<OcptFloorPlanSymbol>> symbolsBySetId;

  /// The id of the set `ocptSceneSetSuggestionOf` suggests for the selected sequence's own
  /// heading, or null while it suggests none — shown first, starred.
  final String? suggestedSetId;

  /// Called with a set's id when its card is clicked, or null while withheld (a read-only preview,
  /// or the mode has nothing to link into).
  final ValueChanged<String>? onSetLinkRequested;

  /// Called with the location id a `Create a set…` menu entry names, or null (its own
  /// `New location…` entry) to mint one, or null itself, at the field level, while withheld.
  final void Function(String? locationId)? onSetCreationRequested;

  /// Class constructor
  const OcptFloorPlanSetGallery({
    super.key,
    required this.locations,
    required this.symbolsBySetId,
    required this.suggestedSetId,
    required this.onSetLinkRequested,
    required this.onSetCreationRequested,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    (OcptSet, String)? suggestedEntry;
    final otherEntries = <(OcptSet, String)>[];
    for (final location in locations) {
      for (final set in location.sets) {
        if (set.id == suggestedSetId) {
          suggestedEntry = (set, location.name);
        } else {
          otherEntries.add((set, location.name));
        }
      }
    }
    final entries = [if (suggestedEntry != null) suggestedEntry, ...otherEntries];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(tr.shotListFloorPlanGalleryTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              for (final (set, locationName) in entries)
                _OcptFloorPlanSetGalleryCard(
                  set: set,
                  locationName: locationName,
                  symbols: symbolsBySetId[set.id] ?? const [],
                  isSuggested: set.id == suggestedSetId,
                  onTap: onSetLinkRequested == null
                      ? null
                      : () => onSetLinkRequested!(set.id),
                ),
            ],
          ),
          if (onSetCreationRequested != null) ...[
            const SizedBox(height: 16),
            _buildCreateSetButton(context, tr),
          ],
        ],
      ),
    );
  }

  /// The `Create a set…` action: an outlined button opening the same location/`New location…`
  /// menu the set tabs' own `＋ Set` button does.
  Widget _buildCreateSetButton(BuildContext context, Tr tr) {
    final locationEntries = [
      for (final location in locations) (location.id, location.name),
    ];

    return MenuAnchor(
      menuChildren: [
        for (final (id, name) in locationEntries)
          MenuItemButton(
            onPressed: () => onSetCreationRequested!(id),
            child: Text(name),
          ),
        if (locationEntries.isNotEmpty) const Divider(height: 1),
        MenuItemButton(
          onPressed: () => onSetCreationRequested!(null),
          child: Text(tr.shotListFloorPlanNewLocationMenuAction),
        ),
      ],
      builder: (context, controller, child) => OutlinedButton(
        onPressed: () => controller.isOpen ? controller.close() : controller.open(),
        child: Text(tr.shotListFloorPlanGalleryCreateSetAction),
      ),
    );
  }
}

/// One set's own card: its thumbnail, name, location subtitle and code, starred while
/// [isSuggested] — the star badge carries [OcptFloorPlanSetGallery]'s own suggestion tooltip.
class _OcptFloorPlanSetGalleryCard extends StatelessWidget {
  /// The set this card shows.
  final OcptSet set;

  /// The name of the location holding [set].
  final String locationName;

  /// [set]'s own live set-scope symbols — the thumbnail's own content.
  final List<OcptFloorPlanSymbol> symbols;

  /// Whether this is the heading's own suggested set.
  final bool isSuggested;

  /// Called when the card is clicked, or null while withheld — the whole card ignores taps then,
  /// rather than only visually disabling one part of it.
  final VoidCallback? onTap;

  /// Class constructor
  const _OcptFloorPlanSetGalleryCard({
    required this.set,
    required this.locationName,
    required this.symbols,
    required this.isSuggested,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return InkWell(
      onTap: onTap,
      mouseCursor: onTap == null ? SystemMouseCursors.basic : ocptClickableCursor,
      borderRadius: BorderRadius.circular(ocptRadiusLarge),
      child: Container(
        width: _cardWidth,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(ocptRadiusLarge),
          border: isSuggested ? Border.all(color: theme.colorScheme.primary, width: 1.5) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(ocptRadiusSmall),
              child: SizedBox(
                width: _thumbnailWidth,
                height: _thumbnailHeight,
                child: ColoredBox(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: _buildThumbnail(context, theme),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    set.name,
                    style: theme.textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isSuggested)
                  Tooltip(
                    message: tr.shotListFloorPlanGallerySuggestedTooltip,
                    child: Icon(Icons.star, size: 16, color: theme.colorScheme.primary),
                  ),
              ],
            ),
            Text(
              set.code.isEmpty ? locationName : "$locationName · ${set.code}",
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  /// The thumbnail itself: [symbols] drawn through `OcptFloorPlanSheet.of` and the very same
  /// `OcptFloorPlanCanvasPainter` the real canvas paints from, fitted to the thumbnail's own size
  /// (`ocptFloorPlanFitOf`) — or the "empty" placeholder while the set carries no set-scope symbol
  /// at all.
  ///
  /// **The underlay is deliberately left out**: resolving and decoding a referenced image for
  /// every card of a project-wide gallery is not the "cheap" `docs/plans/storyboard.md` §10.4's own
  /// wording allows for — a card's thumbnail draws the room's own shapes alone, exactly as an empty
  /// plan draws nothing.
  Widget _buildThumbnail(BuildContext context, ThemeData theme) {
    final floorPlanSet = OcptFloorPlanSet(
      id: set.id,
      name: set.name,
      underlayAssetId: null,
      underlayPath: null,
      underlayXM: null,
      underlayYM: null,
      underlayWidthM: null,
      underlayHeightM: null,
      underlayRotationDeg: null,
      symbols: symbols,
      arrows: const [],
    );
    final sheet = OcptFloorPlanSheet.of(
      floorPlanSet: floorPlanSet,
      focusSceneId: "",
      focusShotId: null,
      shotRankByShotId: const {},
    );

    if (sheet.symbols.isEmpty) {
      return Center(
        child: Text(
          Tr.of(context).shotListFloorPlanGalleryEmptyPlanLabel,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    final fit = ocptFloorPlanFitOf(
      sheet: sheet,
      viewportWidthPx: _thumbnailWidth,
      viewportHeightPx: _thumbnailHeight,
    );

    return CustomPaint(
      size: const Size(_thumbnailWidth, _thumbnailHeight),
      painter: OcptFloorPlanCanvasPainter(
        sheet: sheet,
        zoom: fit.zoom,
        pan: Offset(fit.panXPx, fit.panYPx),
        selectedSymbolId: null,
        arrowAnchorSymbolId: null,
        liveOverride: null,
        symbolBorderColor: theme.colorScheme.outline,
        selectionColor: theme.colorScheme.primary,
        arrowAnchorColor: theme.colorScheme.secondary,
        arrowColor: theme.colorScheme.onSurface,
        labelTextColor: theme.colorScheme.onSurface,
        scaleColor: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
        scaleBarLabel: "",
        onionSkinOpacity: 1,
        metricLines: const [],
        metricLineColor: theme.colorScheme.tertiary,
      ),
    );
  }
}
