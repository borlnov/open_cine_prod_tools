// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_element.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_person_picker.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_sheet_card.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_sheet_field.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_resources_labels.dart';
import 'package:open_cine_prod_tools/utils/ocpt_cost_amount.dart';

/// "Where it comes from": how the production got the element, who owns it, who brings it to set,
/// and what it costs.
///
/// The owner is asked twice on purpose, and the two answers are not alternatives to pick between:
/// a person of the address book when the owner is somebody the production already has a phone
/// number for ("M. et Mme Schmit"), free text when it is an organisation ("Rétro-Loc"). Both may
/// hold something — a rental house *and* the person there who answers the phone.
///
/// Who brings it is a different question from who owns it, and the one that actually fails on the
/// day: it is what the reference spreadsheets track under "Qui l'apporte ?".
class OcptElementSheetSourcingCard extends StatelessWidget {
  /// The element this card belongs to.
  final OcptElement element;

  /// The person who owns it, or null while nobody of the address book does.
  final OcptPerson? owner;

  /// The person who brings it to set, or null while nobody does.
  final OcptPerson? bringer;

  /// The whole address book, offered by the two pickers.
  final List<OcptPerson> people;

  /// The current project's currency, an ISO 4217 code, shown as the cost field's suffix.
  final String currencyCode;

  /// The element's current value for `field`.
  final String Function(OcptElementField field) fieldValueOf;

  /// Called with a field's raw text on every keystroke, or null while the sheet may not be written
  /// to.
  final void Function(OcptElementField field, String rawValue)? onFieldChanged;

  /// Called with the newly picked provenance, or null while it may not be changed.
  final ValueChanged<OcptElementSourceKind>? onSourceKindChanged;

  /// Called with the person who now owns it, or null to clear it; itself null while the owner may
  /// not be changed.
  final ValueChanged<String?>? onOwnerChanged;

  /// Called with the person who now brings it, or null to clear it; itself null while it may not be
  /// changed.
  final ValueChanged<String?>? onBringerChanged;

  /// Called with a person's id when the `↗` beside either picker is clicked. Never null: reading a
  /// person's sheet is not a write.
  final ValueChanged<String> onPersonSheetOpenRequested;

  /// Class constructor
  const OcptElementSheetSourcingCard({
    super.key,
    required this.element,
    required this.owner,
    required this.bringer,
    required this.people,
    required this.currencyCode,
    required this.fieldValueOf,
    required this.onFieldChanged,
    required this.onSourceKindChanged,
    required this.onOwnerChanged,
    required this.onBringerChanged,
    required this.onPersonSheetOpenRequested,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return OcptResourcesSheetCard(
      title: tr.resourcesElementSourcingCardTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSourceKindPicker(context, tr),
          const SizedBox(height: 10),
          OcptResourcesPersonPicker(
            people: people,
            selectedPerson: owner,
            label: tr.resourcesElementOwnerLabel,
            emptyLabel: tr.resourcesElementNoOwner,
            onChanged: onOwnerChanged,
            onPersonSheetOpenRequested: onPersonSheetOpenRequested,
          ),
          const SizedBox(height: 8),
          _field(OcptElementField.ownerNotes, tr.resourcesElementOwnerNotesLabel),
          const SizedBox(height: 10),
          OcptResourcesPersonPicker(
            people: people,
            selectedPerson: bringer,
            label: tr.resourcesElementBringerLabel,
            emptyLabel: tr.resourcesElementNoBringer,
            onChanged: onBringerChanged,
            onPersonSheetOpenRequested: onPersonSheetOpenRequested,
          ),
          const SizedBox(height: 10),
          _field(
            OcptElementField.cost,
            tr.resourcesElementCostLabel,
            suffixText: NumberFormat.simpleCurrency(name: currencyCode).currencySymbol,
            errorTextOf: (value) => _costErrorOf(tr, value),
          ),
        ],
      ),
    );
  }

  /// The provenance picker: a label over a badge doubling as a [PopupMenuButton] over every
  /// [OcptElementSourceKind], withheld (a plain badge, no menu) while the sheet may not be written
  /// to.
  Widget _buildSourceKindPicker(BuildContext context, Tr tr) {
    final theme = Theme.of(context);
    final onSourceKindChanged = this.onSourceKindChanged;

    final badge = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            ocptElementSourceKindLabel(tr, element.sourceKind),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
        ),
        if (onSourceKindChanged != null) ...[
          const SizedBox(width: 4),
          Icon(Icons.arrow_drop_down, size: 16, color: theme.colorScheme.onSurfaceVariant),
        ],
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr.resourcesElementSourceKindFieldLabel.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        if (onSourceKindChanged == null)
          badge
        else
          PopupMenuButton<OcptElementSourceKind>(
            tooltip: "",
            onSelected: onSourceKindChanged,
            itemBuilder: (context) => [
              for (final sourceKind in OcptElementSourceKind.values)
                PopupMenuItem<OcptElementSourceKind>(
                  value: sourceKind,
                  child: Text(ocptElementSourceKindLabel(tr, sourceKind)),
                ),
            ],
            child: badge,
          ),
      ],
    );
  }

  /// One text field of the card, labelled [label] and writing [field].
  Widget _field(
    OcptElementField field,
    String label, {
    String? suffixText,
    String? Function(String value)? errorTextOf,
  }) {
    final onFieldChanged = this.onFieldChanged;

    return OcptResourcesSheetField(
      ownerId: element.id,
      label: label,
      value: fieldValueOf(field),
      suffixText: suffixText,
      errorTextOf: errorTextOf,
      onChanged: onFieldChanged == null ? null : (value) => onFieldChanged(field, value),
    );
  }

  /// What is wrong with the cost [value], or null when there is nothing to say about it.
  ///
  /// A **remark, never a gate** (decision 11 of the plan this ships under, the rule the email field
  /// already follows and the coordinates repeat): the value is written either way — as no cost at
  /// all, since an item whose price nobody typed is not a free one — and the field says so once it
  /// loses the focus. An empty field is not an error: most props are never priced.
  String? _costErrorOf(Tr tr, String value) {
    if (value.trim().isEmpty || ocptCostCentsOf(value) != null) {
      return null;
    }

    return tr.resourcesElementCostFormatError;
  }
}
