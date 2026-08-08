// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_asset_ref.dart';
import 'package:open_cine_prod_tools/models/ocpt_specific_colors.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_asset_file_line.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_person_sheet_date_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_sheet_card.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_resources_labels.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_warning_color.dart';

/// "Image rights": [OcptImageRightsStatus] as a tinted badge doubling as its own selector, and the
/// date that status was reached.
///
/// The date's label **is** its meaning, so it follows the status: `Generated on` for a release
/// that has been drafted, `Signed on` for one that has come back signed. A bare `Date` beside a
/// status said nothing about which of the two it held. The field is not shown at all for the two
/// statuses that date nothing yet — nothing has happened for [OcptImageRightsStatus.notApplicable]
/// and nothing has happened *yet* for [OcptImageRightsStatus.toGenerate] — while a date already
/// stored survives untouched, so flipping the status back shows it again.
///
/// Under the two, the **signed release itself**: an `OcptAssetFileLine` naming the referenced file
/// while there is one, and the control referencing another otherwise — the location sheet's permit
/// card, for the other document this mode files.
///
/// **Referencing a document never touches [status].** A production files a draft as readily as a
/// signature, so deducing "signed" from the presence of a file would put a claim in the project
/// nobody made; the badge above stays the only thing that says where the release stands.
///
/// It still holds no "Generate the document" action: generating one is out of scope, and a control
/// that would do nothing is not rendered.
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

  /// The signed release this person references, or null while they reference none.
  final OcptAssetRef? document;

  /// Called when the reference action is clicked, or null while the sheet may not be written to —
  /// the action is then not rendered at all.
  final VoidCallback? onDocumentPickRequested;

  /// Called when the referenced document's remove control is clicked, or null while it may not be
  /// used.
  final VoidCallback? onDocumentCleared;

  /// Class constructor
  const OcptPersonSheetImageRightsCard({
    super.key,
    required this.status,
    required this.date,
    required this.onStatusChanged,
    required this.onDateChanged,
    required this.document,
    required this.onDocumentPickRequested,
    required this.onDocumentCleared,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final dateLabel = _dateLabelOf(tr, status);
    final document = this.document;
    final onDocumentPickRequested = this.onDocumentPickRequested;

    return OcptResourcesSheetCard(
      title: tr.resourcesImageRightsTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _OcptImageRightsStatusBadge(status: status, onChanged: onStatusChanged),
          if (dateLabel != null) ...[
            const SizedBox(height: 10),
            OcptPersonSheetDateField(label: dateLabel, value: date, onChanged: onDateChanged),
          ],
          const SizedBox(height: 10),
          if (document != null)
            OcptAssetFileLine(asset: document, onRemoved: onDocumentCleared)
          else if (onDocumentPickRequested != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.attach_file, size: 14),
                label: Text(tr.resourcesReferenceDocumentAction),
                onPressed: onDocumentPickRequested,
              ),
            ),
        ],
      ),
    );
  }

  /// What [status] dates, or null when it dates nothing: the label of the date field, and the
  /// answer to whether that field is shown at all.
  String? _dateLabelOf(Tr tr, OcptImageRightsStatus status) => switch (status) {
    OcptImageRightsStatus.notApplicable || OcptImageRightsStatus.toGenerate => null,
    OcptImageRightsStatus.generated => tr.resourcesImageRightsGeneratedOnLabel,
    OcptImageRightsStatus.signed => tr.resourcesImageRightsSignedOnLabel,
  };
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
