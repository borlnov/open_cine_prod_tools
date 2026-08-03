// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_coverage_palette.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_location.dart';
import 'package:open_cine_prod_tools/types/ocpt_location_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_permit_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_sheet_field.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_resources_labels.dart';

/// The width of the header's colour bar.
const double _colorBarWidth = 4;

/// The height of the header's colour bar.
const double _colorBarHeight = 34;

/// The location sheet's header, straight from the mock-up: the location's colour bar, its name as
/// an editable title, and its filming permit status as a tinted badge on the right.
///
/// The bar doubles as the colour picker, exactly as the person sheet's photo slot does — a location
/// has no portrait, and the bar is what identifies it in the left dock, so it is what one clicks to
/// change its colour. The badge doubles as the status picker: the permit card underneath holds
/// what the permit *is* (its reference, its date, its document), never the status again, so the
/// question is asked in one place only.
class OcptLocationSheetHeader extends StatelessWidget {
  /// The location this header shows.
  final OcptLocation location;

  /// [location]'s current value for `field`: a pending edit still in the bloc's debounce, or the
  /// location's own stored value.
  final String Function(OcptLocationField field) fieldValueOf;

  /// Called with a field's raw text on every keystroke, or null while the sheet may not be written
  /// to.
  final void Function(OcptLocationField field, String rawValue)? onFieldChanged;

  /// Called with the palette index picked, or null while the colour may not be changed: the bar
  /// then carries no popover at all.
  final ValueChanged<int>? onColorChanged;

  /// Called with the permit status picked, or null while it may not be changed: the badge then
  /// reads the current status out.
  final ValueChanged<OcptPermitStatus>? onPermitStatusChanged;

  /// Class constructor
  const OcptLocationSheetHeader({
    super.key,
    required this.location,
    required this.fieldValueOf,
    required this.onFieldChanged,
    required this.onColorChanged,
    required this.onPermitStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return Row(
      children: [
        _OcptLocationColorBar(
          colorIndex: location.colorIndex,
          onColorChanged: onColorChanged,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OcptResourcesSheetField(
            ownerId: location.id,
            label: "",
            value: fieldValueOf(OcptLocationField.name),
            hintText: tr.resourcesLocationNameHint,
            textStyle: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            onChanged: _onNameChangedOrNull(),
          ),
        ),
        const SizedBox(width: 12),
        _OcptPermitStatusBadge(status: location.permitStatus, onChanged: onPermitStatusChanged),
      ],
    );
  }

  /// The `onChanged` the name field is given: the one reporting to [onFieldChanged], or null while
  /// the sheet may not be written to, which is what makes the field read its value out instead of
  /// accepting a new one.
  ValueChanged<String>? _onNameChangedOrNull() {
    final onFieldChanged = this.onFieldChanged;
    if (onFieldChanged == null) {
      return null;
    }
    return (value) => onFieldChanged(OcptLocationField.name, value);
  }
}

/// The header's colour bar, doubling as the [MenuAnchor] popover picking a new colour when
/// [onColorChanged] is not null — built exactly as `OcptPersonSheetAvatar`'s own popover is.
class _OcptLocationColorBar extends StatelessWidget {
  /// The palette index the location currently holds.
  final int colorIndex;

  /// Called with the palette index picked, or null while the colour may not be changed.
  final ValueChanged<int>? onColorChanged;

  /// Class constructor
  const _OcptLocationColorBar({required this.colorIndex, required this.onColorChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final onColorChanged = this.onColorChanged;

    final bar = Container(
      width: _colorBarWidth,
      height: _colorBarHeight,
      decoration: BoxDecoration(
        color: Color(ocptCoverageColorAt(colorIndex)),
        borderRadius: BorderRadius.circular(_colorBarWidth),
      ),
    );

    if (onColorChanged == null) {
      return bar;
    }

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
                  onPressed: () => onColorChanged(index),
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Color(ocptCoveragePalette[index]),
                      shape: BoxShape.circle,
                      border: index == colorIndex
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
          borderRadius: BorderRadius.circular(ocptRadiusSmall),
          // The bar alone is 4 px wide: the padding is what makes it a target one can actually hit.
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4), child: bar),
        ),
      ),
    );
  }
}

/// The tinted badge naming the current [OcptPermitStatus], doubling as a [PopupMenuButton] picking
/// a new one when [onChanged] is not null — `OcptPersonSheetImageRightsCard`'s own badge, for the
/// other status this mode tracks.
class _OcptPermitStatusBadge extends StatelessWidget {
  /// The status shown.
  final OcptPermitStatus status;

  /// Called with the status picked, or null while it may not be changed.
  final ValueChanged<OcptPermitStatus>? onChanged;

  /// Class constructor
  const _OcptPermitStatusBadge({required this.status, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final color = ocptPermitStatusColor(context, status);
    final onChanged = this.onChanged;

    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: ocptSelectedStateAlpha),
        borderRadius: BorderRadius.circular(ocptRadiusLarge),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            ocptPermitStatusLabel(tr, status),
            style: theme.textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
          if (onChanged != null) ...[
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, size: 16, color: color),
          ],
        ],
      ),
    );

    if (onChanged == null) {
      return badge;
    }

    return PopupMenuButton<OcptPermitStatus>(
      tooltip: "",
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final option in OcptPermitStatus.values)
          PopupMenuItem<OcptPermitStatus>(
            value: option,
            child: Text(ocptPermitStatusLabel(tr, option)),
          ),
      ],
      child: badge,
    );
  }
}
