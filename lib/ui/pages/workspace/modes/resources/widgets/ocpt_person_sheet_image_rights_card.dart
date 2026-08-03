// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_specific_colors.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_person_sheet_card.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_person_sheet_date_field.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_resources_labels.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_warning_color.dart';

/// "Image rights": [OcptImageRightsStatus] as a tinted badge doubling as its own selector, and the
/// date it last changed.
///
/// Deliberately holds no upload button and no "Generate the document" action: the asset picker and
/// document generation are both out of scope this milestone, and a control that would do nothing
/// is not rendered — the status and the date are the whole of what a production tracks by hand
/// until a generator exists.
class OcptPersonSheetImageRightsCard extends StatelessWidget {
  /// The person's current image rights status.
  final OcptImageRightsStatus status;

  /// The date [status] last changed, or null.
  final DateTime? date;

  /// Called with the status picked, or null while it may not be changed: the badge then reads the
  /// current status out with no popover.
  final ValueChanged<OcptImageRightsStatus>? onStatusChanged;

  /// Called with the newly picked date (or null to clear it), or null while it may not be changed.
  final ValueChanged<DateTime?>? onDateChanged;

  /// Class constructor
  const OcptPersonSheetImageRightsCard({
    super.key,
    required this.status,
    required this.date,
    required this.onStatusChanged,
    required this.onDateChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return OcptPersonSheetCard(
      title: tr.resourcesImageRightsTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _OcptImageRightsStatusBadge(status: status, onChanged: onStatusChanged),
          const SizedBox(height: 10),
          OcptPersonSheetDateField(
            label: tr.resourcesImageRightsDateLabel,
            value: date,
            onChanged: onDateChanged,
          ),
        ],
      ),
    );
  }
}

/// The tinted badge naming the current [OcptImageRightsStatus], doubling as a [PopupMenuButton]
/// picking a new one when [onChanged] is not null.
class _OcptImageRightsStatusBadge extends StatelessWidget {
  /// The status shown.
  final OcptImageRightsStatus status;

  /// Called with the status picked, or null while it may not be changed.
  final ValueChanged<OcptImageRightsStatus>? onChanged;

  /// Class constructor
  const _OcptImageRightsStatusBadge({required this.status, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final color = _colorFor(context, status);
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
            ocptImageRightsStatusLabel(tr, status),
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

    return PopupMenuButton<OcptImageRightsStatus>(
      tooltip: "",
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final option in OcptImageRightsStatus.values)
          PopupMenuItem<OcptImageRightsStatus>(
            value: option,
            child: Text(ocptImageRightsStatusLabel(tr, option)),
          ),
      ],
      child: badge,
    );
  }

  /// The colour [status] is tinted with: muted for [OcptImageRightsStatus.notApplicable], the
  /// workspace's warning colour while a release still has to be drafted, the accent while it is
  /// drafted and awaiting a signature, and the "already shot" green once it is signed.
  Color _colorFor(BuildContext context, OcptImageRightsStatus status) {
    final theme = Theme.of(context);
    return switch (status) {
      OcptImageRightsStatus.notApplicable => theme.colorScheme.onSurfaceVariant,
      OcptImageRightsStatus.toGenerate => ocptWarningColor(context),
      OcptImageRightsStatus.generated => theme.colorScheme.primary,
      OcptImageRightsStatus.signed =>
        theme.extension<OcptSpecificColors>()?.shotStatusShot ?? theme.colorScheme.primary,
    };
  }
}
