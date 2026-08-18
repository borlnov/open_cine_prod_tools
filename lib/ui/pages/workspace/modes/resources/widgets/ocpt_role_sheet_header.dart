// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_sheet_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_role_avatar.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_resources_labels.dart';
import 'package:open_cine_prod_tools/utils/ocpt_role_origin.dart';

/// The radius of the header's own avatar, the cast member's colour standing in for the photo slot
/// the person sheet has (a role has no portrait of its own — the actor does).
const double _avatarRadius = 26;

/// The role sheet's header: the cast member's avatar on the left, and on the right the role's name
/// as a title, the cast member's line under it — name and `↗` together, the whole line opening
/// their own sheet — the kind picker, and the role's rank in the cast as a badge.
///
/// The name is a title-styled [OcptResourcesSheetField] for a hand-added role and plain text for a
/// role reconciled from the screenplay, whose name `OcptRoleIndexService.reconcile` owns and would
/// write right back on the next save — it is stated as a note under the title rather than offered
/// as a disabled field, so nothing ever looks editable that isn't. The note itself says which of the
/// two ways the role was reconciled — cued in dialogue, or only ever named in capitals in the
/// action ([ocptRoleIsActionDetected]) — since the two are deleted differently (see
/// `OcptRoleSheet._canBeDeleted`), and a note that read the same for both would hide that. The same
/// reasoning governs the delete action `OcptRoleSheet` puts at the bottom of the sheet.
///
/// The jump to the cast member lives here rather than beside the casting card's picker: this line
/// is the "who plays this part" answer, and a jump target next to a dropdown would compete with
/// it.
class OcptRoleSheetHeader extends StatelessWidget {
  /// The role this header shows.
  final OcptRole role;

  /// The person cast in [role], or null while it is uncast.
  final OcptPerson? castMember;

  /// [role]'s current value for `field`: a pending edit still in the bloc's debounce, or the
  /// role's own stored value.
  final String Function(OcptRoleField field) fieldValueOf;

  /// Called with a field's raw text on every keystroke, or null while the sheet may not be written
  /// to.
  final void Function(OcptRoleField field, String rawValue)? onFieldChanged;

  /// Called with the newly picked kind, or null while it may not be changed.
  final ValueChanged<OcptRoleKind>? onKindChanged;

  /// Called with the cast member's id when their line is clicked. Never null: reading a cast
  /// member's sheet is not a write.
  final ValueChanged<String> onPersonSheetOpenRequested;

  /// Class constructor
  const OcptRoleSheetHeader({
    super.key,
    required this.role,
    required this.castMember,
    required this.fieldValueOf,
    required this.onFieldChanged,
    required this.onKindChanged,
    required this.onPersonSheetOpenRequested,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OcptRoleAvatar(castMember: castMember, radius: _avatarRadius),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildName(context, tr)),
                  const SizedBox(width: 12),
                  _buildNumberBadge(context, tr),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _buildCastMemberLine(context, tr)),
                  const SizedBox(width: 12),
                  _buildKindPicker(context, tr),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Builds the role's name: an editable title for a hand-added role, the name as plain text
  /// followed by its explanatory note for a role owned by the screenplay — the note itself telling
  /// a cued role from an action-detected one apart, since only the note names the reason the
  /// field is withheld.
  Widget _buildName(BuildContext context, Tr tr) {
    final theme = Theme.of(context);
    final titleStyle = theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700);

    if (!role.isFromScreenplay) {
      return OcptResourcesSheetField(
        ownerId: role.id,
        label: "",
        value: fieldValueOf(OcptRoleField.name),
        hintText: tr.resourcesRoleNameHint,
        textStyle: titleStyle,
        onChanged: _onNameChangedOrNull(),
      );
    }

    final isActionDetected = ocptRoleIsActionDetected(
      isFromScreenplay: role.isFromScreenplay,
      kind: role.kind,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(role.name.isEmpty ? tr.resourcesRoleUnnamed : role.name, style: titleStyle),
        const SizedBox(height: 4),
        Text(
          isActionDetected
              ? tr.resourcesRoleNameFromActionNote
              : tr.resourcesRoleNameFromScreenplayNote,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  /// Builds the `N° {number}` badge: the role's rank in the cast, read-only — it is derived from
  /// the `sortKey` order, never stored (see `OcptRole.number`).
  Widget _buildNumberBadge(BuildContext context, Tr tr) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(ocptRadiusSmall),
        ),
        child: Text(
          tr.resourcesRoleNumberBadge(role.number),
          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }

  /// Builds the cast member line: their name and the `↗`, the whole line being what opens their own
  /// sheet, or a muted italic "Not cast" — plain text, since there is no sheet to open then.
  ///
  /// The name and the arrow are one target rather than a label beside a 14 px icon button: the name
  /// *is* the person, so it is what one aims at, and the arrow only says that clicking leads
  /// somewhere.
  Widget _buildCastMemberLine(BuildContext context, Tr tr) {
    final theme = Theme.of(context);
    final castMember = this.castMember;

    if (castMember == null) {
      return Text(
        tr.resourcesRoleNotCast,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Tooltip(
        message: tr.resourcesOpenPersonSheetTooltip,
        child: InkWell(
          onTap: () => onPersonSheetOpenRequested(castMember.id),
          mouseCursor: ocptClickableCursor,
          borderRadius: BorderRadius.circular(ocptRadiusSmall),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    castMember.displayName.isEmpty
                        ? tr.resourcesUnnamedPerson
                        : castMember.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.north_east, size: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the kind picker: a badge doubling as a [PopupMenuButton] over every [OcptRoleKind],
  /// withheld (a plain badge, no menu) while the sheet may not be written to.
  Widget _buildKindPicker(BuildContext context, Tr tr) {
    final theme = Theme.of(context);
    final onKindChanged = this.onKindChanged;

    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(ocptRadiusSmall),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(ocptRoleKindLabel(tr, role.kind), style: theme.textTheme.labelMedium),
          if (onKindChanged != null) ...[
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, size: 16, color: theme.colorScheme.onSurfaceVariant),
          ],
        ],
      ),
    );

    if (onKindChanged == null) {
      return badge;
    }

    return PopupMenuButton<OcptRoleKind>(
      tooltip: "",
      onSelected: onKindChanged,
      itemBuilder: (context) => [
        for (final kind in OcptRoleKind.values)
          PopupMenuItem<OcptRoleKind>(value: kind, child: Text(ocptRoleKindLabel(tr, kind))),
      ],
      child: badge,
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
    return (value) => onFieldChanged(OcptRoleField.name, value);
  }
}
