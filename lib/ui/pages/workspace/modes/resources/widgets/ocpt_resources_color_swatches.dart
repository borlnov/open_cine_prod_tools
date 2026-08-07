// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_coverage_palette.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';

/// The side of a swatch's tap target: the circle itself is small, and a colour is picked with a
/// pointer, so the target is what has to be comfortable.
const double _swatchTargetSide = 28;

/// The diameter of the coloured circle drawn inside a swatch's tap target.
const double _swatchDiameter = 20;

/// The ring drawn around the swatch the record currently wears.
const double _currentSwatchRingWidth = 2;

/// The gap between two swatches, horizontally and vertically alike.
const double _swatchSpacing = 6;

/// The padding around the whole grid, so the outermost swatches don't touch the popover's edge.
const double _gridPadding = 8;

/// The palette grid every colour picker of the resources mode shows: one round swatch per
/// `ocptCoveragePalette` entry, the one currently worn carrying a ring, wrapped over as many rows
/// as the popover affords.
///
/// Shared by the person sheet's avatar and the location sheet's colour bar, which are the two
/// places a record's colour is chosen: the grid, its sizes and the way a pick closes the popover
/// are stated once here so the two cannot drift apart.
///
/// **A swatch is deliberately not a `MenuItemButton`**, even though this grid only ever appears
/// inside a [MenuAnchor]'s `menuChildren`. A menu item lays its child out inside an [Expanded],
/// itself inside a [Row] sized to the maximum, which is fine down a menu's single column and
/// throws the moment a [Wrap] hands it the unbounded width a wrap always gives its children —
/// the assertion reads `RenderFlex children have non-zero flex but incoming width constraints are
/// unbounded`. A swatch has no label, no leading icon and no shortcut, so there is nothing a menu
/// item would lay out for it anyway: it is an [InkWell], and it closes the popover itself through
/// [MenuController.maybeOf], which is exactly what the menu item was being used for.
class OcptResourcesColorSwatches extends StatelessWidget {
  /// The palette index the record currently wears, ringed in the grid.
  final int currentColorIndex;

  /// Called with the palette index picked. The popover is closed before this runs, so a caller
  /// rebuilding the whole sheet from it cannot leave an orphaned menu behind.
  final ValueChanged<int> onSelected;

  /// Class constructor
  const OcptResourcesColorSwatches({
    super.key,
    required this.currentColorIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(_gridPadding),
    child: Wrap(
      spacing: _swatchSpacing,
      runSpacing: _swatchSpacing,
      children: [
        for (var index = 0; index < ocptCoveragePalette.length; index++)
          _OcptColorSwatch(
            colorIndex: index,
            isCurrent: index == currentColorIndex,
            onSelected: onSelected,
          ),
      ],
    ),
  );
}

/// One swatch of [OcptResourcesColorSwatches]: the coloured circle, its tap target, and the pick
/// that closes the popover holding it.
class _OcptColorSwatch extends StatelessWidget {
  /// The palette index this swatch stands for.
  final int colorIndex;

  /// Whether this is the swatch the record currently wears, which is what the ring says.
  final bool isCurrent;

  /// Called with [colorIndex] once the popover has been closed.
  final ValueChanged<int> onSelected;

  /// Class constructor
  const _OcptColorSwatch({
    required this.colorIndex,
    required this.isCurrent,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () {
        // Closed first: reporting the pick rebuilds the sheet the anchor lives in, and a menu left
        // open over a tree that has just been replaced is the one ordering that misbehaves.
        MenuController.maybeOf(context)?.close();
        onSelected(colorIndex);
      },
      mouseCursor: ocptClickableCursor,
      customBorder: const CircleBorder(),
      child: SizedBox.square(
        dimension: _swatchTargetSide,
        child: Center(
          child: Container(
            width: _swatchDiameter,
            height: _swatchDiameter,
            decoration: BoxDecoration(
              color: Color(ocptCoveragePalette[colorIndex]),
              shape: BoxShape.circle,
              border: isCurrent
                  ? Border.all(color: theme.colorScheme.onSurface, width: _currentSwatchRingWidth)
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
