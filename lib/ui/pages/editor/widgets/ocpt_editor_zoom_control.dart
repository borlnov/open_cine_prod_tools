// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart' as ocpt_theme;
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_page_zoom.dart';

/// The page zoom control of the editor's status bar: a minus button, the current zoom as a
/// percentage and a plus button.
///
/// The percentage opens a menu listing every step and the "fit to width" mode, the current one
/// ticked. A button that has nowhere to go (the minus button at the smallest step, the plus button
/// at the largest) is withheld through its null callback: an empty box of its size stays, so the
/// percentage doesn't move.
class OcptEditorZoomControl extends StatelessWidget {
  /// The size of the minus and plus buttons, in logical pixels.
  static const double _buttonSize = 24;

  /// The factor the page is typeset at, shown as a percentage.
  final double factor;

  /// Whether the "fit to width" mode, rather than a step, is what the zoom currently is.
  final bool isFitToWidth;

  /// Called to zoom one step out, or null to withhold the minus button.
  final VoidCallback? onZoomOutRequested;

  /// Called to zoom one step in, or null to withhold the plus button.
  final VoidCallback? onZoomInRequested;

  /// Called with the zoom picked in the menu.
  final ValueChanged<OcptPageZoom> onZoomSelected;

  /// Class constructor
  const OcptEditorZoomControl({
    required this.factor,
    required this.isFitToWidth,
    required this.onZoomOutRequested,
    required this.onZoomInRequested,
    required this.onZoomSelected,
    super.key,
  });

  /// Build the zoom control as a [Row].
  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final style = Theme.of(context).textTheme.labelSmall;
    final percent = OcptPageZoom.percentOf(factor);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _OcptZoomStepButton(
          icon: Icons.remove,
          tooltip: tr.editorZoomOutTooltip,
          onPressed: onZoomOutRequested,
        ),
        MenuAnchor(
          menuChildren: [
            for (final step in OcptPageZoom.steps)
              MenuItemButton(
                leadingIcon: Icon(
                  Icons.check,
                  size: 16,
                  color: !isFitToWidth && OcptPageZoom.percentOf(step) == percent
                      ? null
                      : Colors.transparent,
                ),
                onPressed: () => onZoomSelected(OcptPageZoom.nearestStep(step)),
                child: Text(tr.editorZoomPercent(OcptPageZoom.percentOf(step))),
              ),
            const Divider(height: 1),
            MenuItemButton(
              leadingIcon: Icon(
                Icons.check,
                size: 16,
                color: isFitToWidth ? null : Colors.transparent,
              ),
              onPressed: () => onZoomSelected(const OcptPageZoom.fitToWidth()),
              child: Text(tr.editorZoomFitToWidth),
            ),
          ],
          builder: (context, controller, child) => Tooltip(
            message: tr.editorZoomMenuTooltip,
            child: InkWell(
              mouseCursor: ocpt_theme.ocptClickableCursor,
              borderRadius: BorderRadius.circular(ocpt_theme.ocptRadiusSmall),
              onTap: () => controller.isOpen ? controller.close() : controller.open(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: Text(tr.editorZoomPercent(percent), style: style),
              ),
            ),
          ),
        ),
        _OcptZoomStepButton(
          icon: Icons.add,
          tooltip: tr.editorZoomInTooltip,
          onPressed: onZoomInRequested,
        ),
      ],
    );
  }
}

/// One of the control's two step buttons, or an empty box of its size while [onPressed] is null.
class _OcptZoomStepButton extends StatelessWidget {
  /// The glyph of the button.
  final IconData icon;

  /// The tooltip of the button.
  final String tooltip;

  /// Called when the button is pressed, or null to withhold it.
  final VoidCallback? onPressed;

  /// Class constructor
  const _OcptZoomStepButton({required this.icon, required this.tooltip, required this.onPressed});

  /// Build the step button as an [InkWell], or a [SizedBox] when withheld.
  @override
  Widget build(BuildContext context) {
    final onPressed = this.onPressed;
    if (onPressed == null) {
      return const SizedBox.square(dimension: OcptEditorZoomControl._buttonSize);
    }

    return Tooltip(
      message: tooltip,
      child: InkWell(
        mouseCursor: ocpt_theme.ocptClickableCursor,
        borderRadius: BorderRadius.circular(ocpt_theme.ocptRadiusSmall),
        onTap: onPressed,
        child: SizedBox.square(
          dimension: OcptEditorZoomControl._buttonSize,
          child: Icon(icon, size: 16),
        ),
      ),
    );
  }
}
