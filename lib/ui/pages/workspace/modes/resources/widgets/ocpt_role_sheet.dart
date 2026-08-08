// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_element.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_removed_role_alert.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_removed_role_banner.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_delete_action.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_person_picker.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_sheet_card.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_sheet_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_role_sheet_elements_card.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_role_sheet_header.dart';

/// The separator joining the names of the other roles a cast member holds.
const String _otherRolesSeparator = ", ";

/// The resources mode's centre, once a role is selected: the whole role sheet, a single scrolling
/// column edited in place — the header (avatar, name, cast member, kind, rank), the removed-role
/// alert when this very role is the orphaned one, the casting card, the things card naming what the
/// role wears, carries and is made up with, the casting notes card, and `Delete this role` at the
/// very bottom.
///
/// It is `OcptPersonSheet`'s sibling and follows the same grammar deliberately: the two tabs of the
/// resources mode answer the same gesture — pick a record on the left, edit it in the centre — so
/// they share the header-then-cards shape and the same card and field chrome
/// (`OcptResourcesSheetCard`, `OcptResourcesSheetField`).
///
/// The things card sits between the casting and the notes because that is the order the questions
/// are asked in: who plays them, what they wear, then everything still to say about the casting.
///
/// The removed-role alert is shown **inside the sheet of the role it names**, not stacked above
/// whichever sheet happens to be open: the cast list of the left dock is what points at it, so the
/// alert sits where the answers to it apply. It follows that a project with three orphaned roles
/// shows one alert at a time rather than three at once, and that an orphaned role's deletion is
/// asked for in the banner rather than at the bottom of the sheet (see [_showsDeleteAction]).
///
/// Every callback is always given by the caller (the mode always has a role selected while this
/// widget is built); [isReadOnly] is what this widget uses to null every one of them out before
/// handing it to the part that owns the affordance, so a control added later cannot be gated in
/// one place and forgotten in the other.
class OcptRoleSheet extends StatelessWidget {
  /// The role this sheet shows.
  final OcptRole role;

  /// The person cast in [role], or null while it is uncast.
  final OcptPerson? castMember;

  /// The other roles [castMember] holds, or empty while [role] is uncast or its cast member holds
  /// only this one.
  final List<OcptRole> otherRoles;

  /// The whole address book, offered by the cast member picker.
  final List<OcptPerson> people;

  /// The whole elements catalogue: what the things card reads this role's links out of, and what
  /// its picker offers.
  final List<OcptElement> elements;

  /// The alert to report inside this sheet, or null while [role] is not orphaned.
  final OcptRemovedRoleAlert? removedRoleAlert;

  /// Whether what the mode shows is a project version being previewed read-only, which no callback
  /// of this sheet may write through.
  final bool isReadOnly;

  /// [role]'s current value for `field`: a pending edit still in the bloc's debounce, or the
  /// role's own stored value.
  final String Function(OcptRoleField field) fieldValueOf;

  /// Called with a field's raw text on every keystroke.
  final void Function(OcptRoleField field, String rawValue) onFieldChanged;

  /// Called with the person now cast in this role, or null to uncast it.
  final ValueChanged<String?> onCastChanged;

  /// Called with this role's newly picked kind.
  final ValueChanged<OcptRoleKind> onKindChanged;

  /// Called when the sheet's own delete action is clicked, the confirmation dialog being the
  /// caller's to open.
  final VoidCallback onDeleteRequested;

  /// Called when the orphaned role's alert is answered `Keep as a silent role`.
  final VoidCallback onOrphanedRoleKept;

  /// Called with a person's id when the header's cast member line is clicked.
  final ValueChanged<String> onPersonSheetOpenRequested;

  /// Called with an element's id when the things card's picker links it to this role.
  final ValueChanged<String> onElementLinked;

  /// Called with a link's id and its note once a things row's local edit is ready to be written.
  final void Function(String id, String notes) onRoleElementUpdated;

  /// Called with a link's id when a things row's remove control is clicked.
  final ValueChanged<String> onRoleElementRemoved;

  /// Class constructor
  const OcptRoleSheet({
    super.key,
    required this.role,
    required this.castMember,
    required this.otherRoles,
    required this.people,
    required this.elements,
    required this.removedRoleAlert,
    this.isReadOnly = false,
    required this.fieldValueOf,
    required this.onFieldChanged,
    required this.onCastChanged,
    required this.onKindChanged,
    required this.onDeleteRequested,
    required this.onOrphanedRoleKept,
    required this.onPersonSheetOpenRequested,
    required this.onElementLinked,
    required this.onRoleElementUpdated,
    required this.onRoleElementRemoved,
  });

  /// Whether deleting this role would actually remove it, which is what decides that the delete
  /// action exists at all.
  ///
  /// False for a role the screenplay still speaks: `OcptRoleIndexService.reconcile` only ever reads
  /// live rows, so the next save would insert that character right back as a fresh, uncast role —
  /// the deletion would cost the casting and the notes without removing anything. Its existence
  /// belongs to the screenplay, exactly as a scene's does to the scene index, so the way to remove
  /// it is to remove the character's cues. A hand-added role, and an orphaned one (whose character
  /// is gone, so nothing will re-insert it), are deleted for good and keep the action.
  bool get _canBeDeleted => !role.isFromScreenplay || role.orphanedName != null;

  /// Whether the sheet shows its own `Delete this role` action at the bottom.
  ///
  /// An orphaned role is deletable but shows nothing here: `OcptRemovedRoleBanner` already offers
  /// that very answer, paired with the other one — keeping it as a silent role — and the two belong
  /// together. Repeating the action at the bottom of the sheet would ask the same question twice,
  /// once with its alternative and once without.
  bool get _showsDeleteAction => _canBeDeleted && removedRoleAlert == null;

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final removedRoleAlert = this.removedRoleAlert;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(26, 20, 26, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OcptRoleSheetHeader(
            role: role,
            castMember: castMember,
            fieldValueOf: fieldValueOf,
            onFieldChanged: isReadOnly ? null : onFieldChanged,
            onKindChanged: isReadOnly ? null : onKindChanged,
            onPersonSheetOpenRequested: onPersonSheetOpenRequested,
          ),
          if (removedRoleAlert != null) ...[
            const SizedBox(height: 16),
            OcptRemovedRoleBanner(
              alert: removedRoleAlert,
              isReadOnly: isReadOnly,
              onDeleteRequested: onDeleteRequested,
              onKeepRequested: onOrphanedRoleKept,
            ),
          ],
          const SizedBox(height: 16),
          _buildCastingCard(context, tr),
          const SizedBox(height: 12),
          OcptRoleSheetElementsCard(
            roleId: role.id,
            elements: elements,
            onElementLinked: isReadOnly ? null : onElementLinked,
            onLinkUpdated: isReadOnly ? null : onRoleElementUpdated,
            onLinkRemoved: isReadOnly ? null : onRoleElementRemoved,
          ),
          const SizedBox(height: 12),
          OcptResourcesSheetCard(
            title: tr.resourcesRoleCastingNotesLabel,
            child: OcptResourcesSheetField(
              ownerId: role.id,
              label: "",
              value: fieldValueOf(OcptRoleField.castingNotes),
              multiline: true,
              hintText: tr.resourcesRoleCastingNotesHint,
              onChanged: isReadOnly
                  ? null
                  : (value) => onFieldChanged(OcptRoleField.castingNotes, value),
            ),
          ),
          if (!isReadOnly && _showsDeleteAction) ...[
            const SizedBox(height: 20),
            OcptResourcesDeleteAction(
              label: tr.resourcesRoleDeleteAction,
              onDeleteRequested: onDeleteRequested,
            ),
          ],
        ],
      ),
    );
  }

  /// Builds the casting card: the cast member picker, and the muted line naming the other roles
  /// that same person holds — a read-only remark, the way to reach one of them being the cast list
  /// of the left dock.
  Widget _buildCastingCard(BuildContext context, Tr tr) {
    final theme = Theme.of(context);

    return OcptResourcesSheetCard(
      title: tr.resourcesRoleCastingCardTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCastPicker(tr),
          if (otherRoles.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              tr.resourcesRolesListOtherRolesLabel(
                otherRoles
                    .map((other) => other.name.isEmpty ? tr.resourcesRoleUnnamed : other.name)
                    .join(_otherRolesSeparator),
              ),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Builds the cast member picker: the shared [OcptResourcesPersonPicker] over the whole address
  /// book, withheld (a plain badge, no menu) while the sheet may not be written to.
  ///
  /// It offers no `↗` of its own: the header's cast member line already is the jump to their sheet,
  /// and a second arrow next to the drop-down would compete with it (see `OcptRoleSheetHeader`).
  Widget _buildCastPicker(Tr tr) => OcptResourcesPersonPicker(
    people: people,
    selectedPerson: castMember,
    label: tr.resourcesRoleCastMemberLabel,
    emptyLabel: tr.resourcesRoleNotCast,
    onChanged: isReadOnly ? null : onCastChanged,
  );
}
