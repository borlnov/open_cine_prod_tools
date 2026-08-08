// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_asset_ref.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_dashed_rounded_rect_painter.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_referenced_image.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_color_swatches.dart';

/// The width and height of a sheet header's photo slot.
const Size ocptPhotoSlotSize = Size(104, 130);

/// A sheet header's photo slot: the referenced photo, or [placeholderBuilder]'s answer inside a
/// dashed outline while there is none, over the menu that references one, drops it, and picks the
/// record's fallback colour.
///
/// Shared by the person sheet's header and the element sheet's, which differ only in what they show
/// while no photo is referenced — a person's initials on their colour, an element's category icon.
///
/// **One anchor, both things a slot is about.** Referencing a photo and picking a colour are the
/// same question asked twice — what this record looks like — and the colour is the *fallback* for
/// the photo rather than a competing setting, so they belong behind one click rather than two
/// controls fighting for 104 px. The palette is the shared [OcptResourcesColorSwatches] grid, which
/// is also what the location sheet's colour bar opens.
///
/// A record with **no colour of its own** passes a null [currentColorIndex] and the menu then holds
/// the photo entries alone: `elements` carries no `colorIndex` column, unlike `people` and
/// `locations`, an element being read by its category's own colour
/// (`ocptBreakdownColorOf`) rather than by one somebody picked for it.
///
/// Withheld the way every writing affordance of these sheets is: with both [onPhotoPickRequested]
/// and [onColorChanged] null the slot is a plain, unclickable, menu-less picture — which is exactly
/// what a project version being previewed should show.
class OcptResourcesPhotoSlot extends StatelessWidget {
  /// The photo this slot shows, or null while the record references none.
  final OcptAssetRef? photo;

  /// What fills the slot while no photo is referenced, or while the file at [photo]'s path resolves
  /// to nothing — see [OcptReferencedImage] for why the two read the same.
  final WidgetBuilder placeholderBuilder;

  /// The palette index the record currently wears, ringed in the menu's grid, or null while the
  /// record has no colour of its own — the grid is then not part of the menu at all.
  final int? currentColorIndex;

  /// Called when the menu's "reference a photo" entry is picked, or null while the sheet may not be
  /// written to.
  final VoidCallback? onPhotoPickRequested;

  /// Called when the menu's "remove the photo" entry is picked. Rendered only while [photo] is not
  /// null and this is not null.
  final VoidCallback? onPhotoCleared;

  /// Called with the palette index picked from the menu's grid, or null while it may not be
  /// changed — the grid is then not rendered at all, as it isn't for a null [currentColorIndex].
  final ValueChanged<int>? onColorChanged;

  /// Class constructor
  const OcptResourcesPhotoSlot({
    super.key,
    required this.photo,
    required this.placeholderBuilder,
    required this.currentColorIndex,
    required this.onPhotoPickRequested,
    required this.onPhotoCleared,
    required this.onColorChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photo = this.photo;
    final onPhotoPickRequested = this.onPhotoPickRequested;
    final onColorChanged = this.onColorChanged;

    final content = ClipRRect(
      borderRadius: BorderRadius.circular(ocptRadiusLarge),
      child: SizedBox(
        width: ocptPhotoSlotSize.width,
        height: ocptPhotoSlotSize.height,
        child: ColoredBox(
          color: theme.colorScheme.surfaceContainer,
          child: OcptReferencedImage(path: photo?.path, fallbackBuilder: placeholderBuilder),
        ),
      ),
    );

    // The dashed outline says "there could be a photo here"; a slot that has one is a picture and
    // needs no invitation drawn around it.
    final slot = photo == null
        ? CustomPaint(
            painter: OcptDashedRoundedRectPainter(color: theme.colorScheme.outline),
            child: content,
          )
        : content;

    if (onPhotoPickRequested == null && onColorChanged == null) {
      return slot;
    }

    return _OcptPhotoSlotMenu(
      hasPhoto: photo != null,
      currentColorIndex: currentColorIndex,
      // Both halves have to be there for the grid to mean anything: an index with no callback is a
      // read-only preview, and a callback with no index names no record's colour to ring.
      showsColors: currentColorIndex != null && onColorChanged != null,
      onPhotoPickRequested: onPhotoPickRequested,
      onPhotoCleared: onPhotoCleared,
      onColorChanged: onColorChanged,
      slot: slot,
    );
  }
}

/// The [MenuAnchor] popover [OcptResourcesPhotoSlot] opens: the two photo entries, then the palette.
class _OcptPhotoSlotMenu extends StatelessWidget {
  /// Whether a photo is referenced, which is what decides the wording of the first entry and
  /// whether the second one exists at all.
  final bool hasPhoto;

  /// The palette index the record currently wears, or null while it has none.
  final int? currentColorIndex;

  /// Whether the menu carries the palette grid at all.
  final bool showsColors;

  /// Called when the reference entry is picked, or null while it may not be used.
  final VoidCallback? onPhotoPickRequested;

  /// Called when the remove entry is picked, or null while it may not be used.
  final VoidCallback? onPhotoCleared;

  /// Called with the palette index picked, or null while it may not be changed.
  final ValueChanged<int>? onColorChanged;

  /// The slot the popover is anchored on.
  final Widget slot;

  /// Class constructor
  const _OcptPhotoSlotMenu({
    required this.hasPhoto,
    required this.currentColorIndex,
    required this.showsColors,
    required this.onPhotoPickRequested,
    required this.onPhotoCleared,
    required this.onColorChanged,
    required this.slot,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final onPhotoPickRequested = this.onPhotoPickRequested;
    final onPhotoCleared = this.onPhotoCleared;
    final onColorChanged = this.onColorChanged;

    return MenuAnchor(
      menuChildren: [
        if (onPhotoPickRequested != null)
          MenuItemButton(
            leadingIcon: const Icon(Icons.image_outlined, size: 16),
            onPressed: onPhotoPickRequested,
            child: Text(
              hasPhoto ? tr.resourcesReplacePhotoAction : tr.resourcesReferencePhotoAction,
            ),
          ),
        if (hasPhoto && onPhotoCleared != null)
          MenuItemButton(
            leadingIcon: const Icon(Icons.close, size: 16),
            onPressed: onPhotoCleared,
            child: Text(tr.resourcesRemovePhotoAction),
          ),
        if (onPhotoPickRequested != null && showsColors) const Divider(height: 1),
        if (showsColors && onColorChanged != null)
          OcptResourcesColorSwatches(
            currentColorIndex: currentColorIndex!,
            onSelected: onColorChanged,
          ),
      ],
      builder: (context, controller, child) => Tooltip(
        message: showsColors ? tr.resourcesPhotoSlotTooltip : tr.resourcesPhotoSlotPhotoOnlyTooltip,
        child: InkWell(
          onTap: () => controller.isOpen ? controller.close() : controller.open(),
          mouseCursor: ocptClickableCursor,
          borderRadius: BorderRadius.circular(ocptRadiusLarge),
          child: slot,
        ),
      ),
    );
  }
}
