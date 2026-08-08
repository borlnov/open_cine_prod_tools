// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_asset_ref.dart';
import 'package:open_cine_prod_tools/types/ocpt_location_editable_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_asset_file_line.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_person_sheet_date_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_sheet_card.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_sheet_field.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_resources_labels.dart';

/// "Filming permit": what the permit *is* — the reference it was granted under, the date that
/// happened, and the signed document itself.
///
/// The status itself is not here: it is the header's badge (see `OcptLocationSheetHeader`), where it
/// is read at a glance beside the location's name, and asking for it twice on one sheet would be
/// two controls answering one question.
///
/// The document is **referenced, never stored** (`docs/adr/0013-binary-assets-referenced-by-path.md`):
/// referencing another one replaces the reference, and neither file is ever read, copied or
/// deleted by this app.
///
/// Once a document is referenced, this card also shows its own **validity window** —
/// `OcptAssetRef.validFrom`/`validUntil` — right under its file line: a permit is a document with
/// dates, not a location field, so the dates belong to the document block rather than floating
/// beside it. **Either date left empty means nobody has recorded one, never "valid forever"** — the
/// same reading `OcptAssetsTable.validFrom`'s own doc comment gives, and the reading
/// `OcptSchedulePermitNotValidAlert` depends on to stay silent rather than advancing a claim
/// nobody entered; the card says so under the two fields rather than leaving the user to guess.
class OcptLocationSheetPermitCard extends StatelessWidget {
  /// The id of the location this card belongs to.
  final String locationId;

  /// The date the permit status last changed, or null.
  final DateTime? permitDate;

  /// The permit document this location references, or null while it references none.
  final OcptAssetRef? permitDocument;

  /// The location's current value for `field`.
  final String Function(OcptLocationField field) fieldValueOf;

  /// Called with a field's raw text on every keystroke, or null while the sheet may not be written
  /// to.
  final void Function(OcptLocationField field, String rawValue)? onFieldChanged;

  /// Called with the newly picked date (or null to clear it), or null while it may not be changed.
  final ValueChanged<DateTime?>? onPermitDateChanged;

  /// Called when the document is to be referenced (or replaced), or null while it may not be.
  final VoidCallback? onPermitDocumentPickRequested;

  /// Called when the document reference is to be dropped, or null while it may not be.
  final VoidCallback? onPermitDocumentCleared;

  /// Called with the document's newly picked "valid from" date (or null to clear it), or null while
  /// it may not be changed. Only ever offered while [permitDocument] is not null — there is nothing
  /// to date otherwise.
  final ValueChanged<DateTime?>? onPermitDocumentValidFromChanged;

  /// Called with the document's newly picked "valid until" date (or null to clear it), or null
  /// while it may not be changed. See [onPermitDocumentValidFromChanged].
  final ValueChanged<DateTime?>? onPermitDocumentValidUntilChanged;

  /// Class constructor
  const OcptLocationSheetPermitCard({
    super.key,
    required this.locationId,
    required this.permitDate,
    required this.permitDocument,
    required this.fieldValueOf,
    required this.onFieldChanged,
    required this.onPermitDateChanged,
    required this.onPermitDocumentPickRequested,
    required this.onPermitDocumentCleared,
    required this.onPermitDocumentValidFromChanged,
    required this.onPermitDocumentValidUntilChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final onFieldChanged = this.onFieldChanged;

    return OcptResourcesSheetCard(
      title: tr.resourcesLocationPermitCardTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OcptResourcesSheetField(
            ownerId: locationId,
            label: tr.resourcesLocationPermitLabelLabel,
            value: fieldValueOf(OcptLocationField.permitLabel),
            hintText: tr.resourcesLocationPermitLabelHint,
            onChanged: onFieldChanged == null
                ? null
                : (value) => onFieldChanged(OcptLocationField.permitLabel, value),
          ),
          const SizedBox(height: 10),
          OcptPersonSheetDateField(
            label: tr.resourcesLocationPermitDateLabel,
            value: permitDate,
            onChanged: onPermitDateChanged,
          ),
          const SizedBox(height: 10),
          _buildDocument(context, tr),
        ],
      ),
    );
  }

  /// The permit document: its own line once one is referenced, its validity window right under it,
  /// and the action referencing (or replacing) it. A read-only sheet with no document at all shows
  /// neither — there is nothing to say and nothing to do.
  Widget _buildDocument(BuildContext context, Tr tr) {
    final theme = Theme.of(context);
    final permitDocument = this.permitDocument;
    final onPermitDocumentPickRequested = this.onPermitDocumentPickRequested;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr.resourcesLocationPermitDocumentLabel.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        if (permitDocument != null)
          OcptAssetFileLine(asset: permitDocument, onRemoved: onPermitDocumentCleared)
        else if (onPermitDocumentPickRequested == null)
          Text(
            ocptResourcesEmptyValue,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        if (permitDocument != null) ...[
          const SizedBox(height: 10),
          OcptPersonSheetDateField(
            label: tr.resourcesLocationPermitValidFromLabel,
            value: permitDocument.validFrom,
            onChanged: onPermitDocumentValidFromChanged,
          ),
          const SizedBox(height: 10),
          OcptPersonSheetDateField(
            label: tr.resourcesLocationPermitValidUntilLabel,
            value: permitDocument.validUntil,
            onChanged: onPermitDocumentValidUntilChanged,
          ),
          const SizedBox(height: 6),
          Text(
            tr.resourcesLocationPermitValidityHint,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
        if (onPermitDocumentPickRequested != null) ...[
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onPermitDocumentPickRequested,
              child: Text(
                permitDocument == null
                    ? tr.resourcesReferenceDocumentAction
                    : tr.resourcesReplaceDocumentAction,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
