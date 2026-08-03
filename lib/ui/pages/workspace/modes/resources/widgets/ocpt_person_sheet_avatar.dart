// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_coverage_palette.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';

/// The width and height of the person sheet's photo slot.
const Size _slotSize = Size(104, 130);

/// The diameter of the colour avatar circle sitting inside the photo slot.
const double _avatarDiameter = 42;

/// The person sheet's header photo slot: a dashed-outline box (no photo asset picker yet — that
/// lands in a later milestone, see `OcptPerson.photoAssetId`'s own doc comment) holding a circular
/// avatar filled with `ocptCoverageColorAt(person.colorIndex)` and carrying the person's initials.
///
/// The whole slot is the one place a person's avatar colour can be changed: clicking it opens a
/// small popover of `ocptCoveragePalette`'s swatches, built on [MenuAnchor]/[MenuItemButton]
/// exactly as `OcptShotListColumnsMenu` uses them for its own popover, so picking a swatch closes
/// the menu for free. Withheld (no popover, a plain unclickable slot) while [onColorChanged] is
/// null, the read-only idiom every writing affordance of the sheet follows.
class OcptPersonSheetAvatar extends StatelessWidget {
  /// The person whose avatar is shown.
  final OcptPerson person;

  /// Called with the palette index picked, or null while the colour may not be changed (a project
  /// version being previewed read-only): the slot then shows no popover at all.
  final ValueChanged<int>? onColorChanged;

  /// Class constructor
  const OcptPersonSheetAvatar({super.key, required this.person, required this.onColorChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onColorChanged = this.onColorChanged;

    final avatar = CircleAvatar(
      radius: _avatarDiameter / 2,
      backgroundColor: Color(ocptCoverageColorAt(person.colorIndex)),
      child: Text(
        person.initials,
        style: theme.textTheme.titleSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );

    final slot = CustomPaint(
      painter: _OcptDashedRoundedRectPainter(color: theme.colorScheme.outline),
      child: Container(
        width: _slotSize.width,
        height: _slotSize.height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(ocptRadiusLarge),
        ),
        child: avatar,
      ),
    );

    if (onColorChanged == null) {
      return slot;
    }

    return _OcptPersonAvatarColorMenu(currentColorIndex: person.colorIndex, onSelected: onColorChanged, slot: slot);
  }
}

/// The [MenuAnchor] popover [OcptPersonSheetAvatar] opens on [OcptPersonSheetAvatar.onColorChanged].
class _OcptPersonAvatarColorMenu extends StatelessWidget {
  /// The palette index the person currently holds, marked in the popover.
  final int currentColorIndex;

  /// Called with the palette index picked.
  final ValueChanged<int> onSelected;

  /// The avatar slot the popover is anchored on.
  final Widget slot;

  /// Class constructor
  const _OcptPersonAvatarColorMenu({
    required this.currentColorIndex,
    required this.onSelected,
    required this.slot,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return MenuAnchor(
      menuChildren: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var index = 0; index < ocptCoveragePalette.length; index++)
                MenuItemButton(
                  style: MenuItemButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(28, 28),
                    shape: const CircleBorder(),
                  ),
                  onPressed: () => onSelected(index),
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Color(ocptCoveragePalette[index]),
                      shape: BoxShape.circle,
                      border: index == currentColorIndex
                          ? Border.all(color: theme.colorScheme.onSurface, width: 2)
                          : null,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
      builder: (context, controller, child) => Tooltip(
        message: tr.resourcesChangeColorTooltip,
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

/// Paints a dashed rounded-rectangle outline, the photo slot's own affordance (the mock-up's own
/// "drop a photo here" styling) that neither [BoxDecoration] nor any existing dependency draws:
/// Flutter has no stock dashed border, and this is a small enough shape to paint directly rather
/// than pull in a package for it.
class _OcptDashedRoundedRectPainter extends CustomPainter {
  /// The length, in logical pixels, of one dash and of the gap following it.
  static const double _dashLength = 5;

  /// The colour of the dashes.
  final Color color;

  /// Class constructor
  const _OcptDashedRoundedRectPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(ocptRadiusLarge),
    );
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + _dashLength;
        canvas.drawPath(metric.extractPath(distance, next.clamp(0, metric.length)), paint);
        distance = next + _dashLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _OcptDashedRoundedRectPainter oldDelegate) =>
      oldDelegate.color != color;
}
