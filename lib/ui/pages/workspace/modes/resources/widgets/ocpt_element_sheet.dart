// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_element.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_scene_ref.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_tracking_flag.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_element_sheet_header.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_element_sheet_scenes_card.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_element_sheet_sourcing_card.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_element_sheet_tracking_card.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_delete_action.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_notes_card.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_sheet_card.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_sheet_field.dart';

/// The resources mode's centre, once an element is selected: the whole element sheet, a single
/// scrolling column edited in place — the header (code, name, tracking badge, category,
/// sub-category, quantity), a two-column grid pairing where it comes from with how far along it is,
/// the full-width scenes card, the "why it is needed" and notes card, and `Delete this element` at
/// the very bottom.
///
/// It is `OcptPersonSheet`'s, `OcptRoleSheet`'s and `OcptLocationSheet`'s sibling and follows the
/// same grammar deliberately: the four tabs of the resources mode answer the same gesture — pick a
/// record on the left, edit it in the centre — so they share the header-then-cards shape and the
/// same card and field chrome (`OcptResourcesSheetCard`, `OcptResourcesSheetField`).
///
/// The mock-up shows this tab as a board of every element at once rather than as a sheet; the left
/// dock's list is what carries that grouping here, and the centre is where an item is actually
/// answered for — the tracking flags, the owner, the person bringing it and the scenes needing it
/// are all edits, and the board had nowhere to make them.
///
/// The scenes card is the one outside the grid: a row holds a scene, its own quantity and its own
/// note, which do not fit half a sheet's width — the same reason a person's unavailabilities sit
/// full-width.
///
/// Every callback is always given by the caller (the mode always has an element selected while this
/// widget is built); [isReadOnly] is what this widget uses to null every one of them out before
/// handing it to the part that owns the affordance, so a control added later cannot be gated in one
/// place and forgotten in the other. The mock-up's own "days" column is schedule data and is out of
/// scope here entirely, exactly as a person's and a location's are.
class OcptElementSheet extends StatelessWidget {
  /// The element this sheet shows.
  final OcptElement element;

  /// The person who owns it, or null while nobody of the address book does.
  final OcptPerson? owner;

  /// The person who brings it to set, or null while nobody does.
  final OcptPerson? bringer;

  /// The whole address book, offered by the owner and bringer pickers.
  final List<OcptPerson> people;

  /// Every scene of the project's screenplay, in source order: what the scenes card names its links
  /// with and picks a new one from.
  final List<OcptSceneRef> scenes;

  /// The current project's currency, an ISO 4217 code, shown as the cost field's suffix.
  final String currencyCode;

  /// Whether what the mode shows is a project version being previewed read-only, which no callback
  /// of this sheet may write through.
  final bool isReadOnly;

  /// [element]'s current value for `field`: a pending edit still in the bloc's debounce, or the
  /// element's own stored value.
  final String Function(OcptElementField field) fieldValueOf;

  /// Called with a field's raw text on every keystroke.
  final void Function(OcptElementField field, String rawValue) onFieldChanged;

  /// Called with the newly picked category.
  final ValueChanged<OcptElementCategory> onCategoryChanged;

  /// Called when the photo slot's reference entry is picked, the native dialog being the caller's
  /// to open.
  final VoidCallback onPhotoPickRequested;

  /// Called when the photo slot's remove entry is picked.
  final VoidCallback onPhotoCleared;

  /// Called with the newly picked provenance.
  final ValueChanged<OcptElementSourceKind> onSourceKindChanged;

  /// Called with the person who now owns it, or null to clear it.
  final ValueChanged<String?> onOwnerChanged;

  /// Called with the person who now brings it, or null to clear it.
  final ValueChanged<String?> onBringerChanged;

  /// Called with the tracking flag ticked or unticked and what it now holds.
  final void Function(OcptElementTrackingFlag flag, {required bool value}) onTrackingFlagChanged;

  /// Called with a scene's id when the scenes card's picker adds it.
  final ValueChanged<String> onSceneAssigned;

  /// Called with a link's id and its two fields once a row's local edit is ready to be written.
  final void Function(String id, {required String quantity, required String notes}) onLinkUpdated;

  /// Called with a link's id when its row's remove control is clicked.
  final ValueChanged<String> onLinkRemoved;

  /// Called when the sheet's own delete action is clicked, the confirmation dialog being the
  /// caller's to open.
  final VoidCallback onDeleteRequested;

  /// Called with a person's id when the `↗` beside the owner or the bringer is clicked.
  final ValueChanged<String> onPersonSheetOpenRequested;

  /// Class constructor
  const OcptElementSheet({
    super.key,
    required this.element,
    required this.owner,
    required this.bringer,
    required this.people,
    required this.scenes,
    required this.currencyCode,
    this.isReadOnly = false,
    required this.fieldValueOf,
    required this.onFieldChanged,
    required this.onCategoryChanged,
    required this.onPhotoPickRequested,
    required this.onPhotoCleared,
    required this.onSourceKindChanged,
    required this.onOwnerChanged,
    required this.onBringerChanged,
    required this.onTrackingFlagChanged,
    required this.onSceneAssigned,
    required this.onLinkUpdated,
    required this.onLinkRemoved,
    required this.onDeleteRequested,
    required this.onPersonSheetOpenRequested,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(26, 20, 26, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OcptElementSheetHeader(
            element: element,
            fieldValueOf: fieldValueOf,
            onFieldChanged: isReadOnly ? null : onFieldChanged,
            onCategoryChanged: isReadOnly ? null : onCategoryChanged,
            onPhotoPickRequested: isReadOnly ? null : onPhotoPickRequested,
            onPhotoCleared: isReadOnly ? null : onPhotoCleared,
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: OcptElementSheetSourcingCard(
                  element: element,
                  owner: owner,
                  bringer: bringer,
                  people: people,
                  currencyCode: currencyCode,
                  fieldValueOf: fieldValueOf,
                  onFieldChanged: isReadOnly ? null : onFieldChanged,
                  onSourceKindChanged: isReadOnly ? null : onSourceKindChanged,
                  onOwnerChanged: isReadOnly ? null : onOwnerChanged,
                  onBringerChanged: isReadOnly ? null : onBringerChanged,
                  onPersonSheetOpenRequested: onPersonSheetOpenRequested,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OcptElementSheetTrackingCard(
                  element: element,
                  fieldValueOf: fieldValueOf,
                  onFieldChanged: isReadOnly ? null : onFieldChanged,
                  onTrackingFlagChanged: isReadOnly ? null : onTrackingFlagChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OcptElementSheetScenesCard(
            sceneLinks: element.sceneLinks,
            scenes: scenes,
            onSceneAssigned: isReadOnly ? null : onSceneAssigned,
            onLinkUpdated: isReadOnly ? null : onLinkUpdated,
            onLinkRemoved: isReadOnly ? null : onLinkRemoved,
          ),
          const SizedBox(height: 12),
          OcptResourcesSheetCard(
            title: tr.resourcesElementPurposeLabel,
            child: OcptResourcesSheetField(
              ownerId: element.id,
              label: "",
              value: fieldValueOf(OcptElementField.purposeNotes),
              multiline: true,
              onChanged: isReadOnly
                  ? null
                  : (value) => onFieldChanged(OcptElementField.purposeNotes, value),
            ),
          ),
          const SizedBox(height: 12),
          OcptResourcesNotesCard(
            title: tr.resourcesNotesTitle,
            ownerId: element.id,
            value: fieldValueOf(OcptElementField.notes),
            onChanged: isReadOnly
                ? null
                : (value) => onFieldChanged(OcptElementField.notes, value),
          ),
          if (!isReadOnly) ...[
            const SizedBox(height: 20),
            OcptResourcesDeleteAction(
              label: tr.resourcesDeleteElementAction,
              onDeleteRequested: onDeleteRequested,
            ),
          ],
        ],
      ),
    );
  }
}
