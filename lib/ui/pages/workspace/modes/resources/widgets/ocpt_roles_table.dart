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
import 'package:open_cine_prod_tools/ui/utils/ocpt_resources_labels.dart';

/// The sentinel value the cast member picker menu uses for its "uncast" entry, never a real
/// person id.
const String _uncastOption = "";

/// The width of the N° column.
const double _numberColumnWidth = 40;

/// The relative flex of the Role, Cast member and Other roles held columns.
const List<int> _columnFlex = [2, 3, 2];

/// The separator joining the names of the other roles a cast member holds.
const _otherRolesSeparator = ", ";

/// The number of lines the casting notes field is tall before it grows with what is typed into it.
const int _castingNotesMinLines = 2;

/// The resources mode's roles tab centre: a title and a one-line subtitle over a bordered table of
/// the whole cast — n°, role, cast member, other roles held — whose selected row expands in place
/// into an inline editor instead of opening a sheet or a dialog of its own.
///
/// The inline editor holds the cast member menu (every person of the address book, plus an entry
/// that uncasts), the role's kind, its casting notes, and — for a hand-added role only
/// (`OcptRole.isFromScreenplay` false) — its name field: an `isFromScreenplay` role's name is owned
/// by `OcptRoleIndexService.reconcile` and would be overwritten right back on the next save, so
/// that field is withheld for it and shown as read-only text instead, never disabled or silently
/// reverted. Deleting a role is answered inline inside the same expanded row, one confirm at a
/// time, mirroring how a version card asks its own questions — and it is withheld exactly where it
/// would not hold: a role the screenplay still speaks would be inserted right back by the next
/// save, so only a hand-added or an orphaned role carries the action (see
/// `_OcptRoleTableRowState._canBeDeleted`).
///
/// The `↗` affordance sits in the cast-member cell of the main row, present only while the role is
/// cast: a plain row click only selects the role (which is what expands its editor), never changes
/// tab on its own.
///
/// Every callback is always given by the caller (the mode always has the roles tab's content built
/// while this widget is shown); [isReadOnly] is what this widget uses to null every one of them
/// out before handing it to the part that owns the affordance, so a control added later cannot be
/// gated in one place and forgotten in the other. Empty carousels are the caller's job: this widget
/// assumes [roles] is not empty, matching `OcptShotListTable`'s own split with its mode's empty
/// state.
class OcptRolesTable extends StatelessWidget {
  /// The cast to show, in display order.
  final List<OcptRole> roles;

  /// The whole address book, offered by the cast member picker and used to resolve a role's other
  /// roles.
  final List<OcptPerson> people;

  /// The id of the selected role, whose row expands in place, or null while none is.
  final String? selectedRoleId;

  /// Whether what the mode shows is a project version being previewed read-only, which no
  /// callback of this table may write through.
  final bool isReadOnly;

  /// `role`'s current value for `field`: a pending edit still in the bloc's debounce, or the
  /// role's own stored value.
  final String Function(OcptRole role, OcptRoleField field) fieldValueOf;

  /// Called with a role's id when its row is clicked.
  final ValueChanged<String> onRoleSelected;

  /// Called with a role's id, the field edited and its raw text on every keystroke.
  final void Function(String roleId, OcptRoleField field, String rawValue) onFieldChanged;

  /// Called with a role's id and the person now cast in it, or null to uncast it.
  final void Function(String roleId, String? personId) onCastChanged;

  /// Called with a role's id and its newly picked kind.
  final void Function(String roleId, OcptRoleKind kind) onKindChanged;

  /// Called with a role's id once its inline delete confirmation is answered `Delete`.
  final ValueChanged<String> onDeleteRequested;

  /// Called with a person's id when the cast-member cell's `↗` affordance is clicked.
  final ValueChanged<String> onPersonSheetOpenRequested;

  /// Class constructor
  const OcptRolesTable({
    super.key,
    required this.roles,
    required this.people,
    required this.selectedRoleId,
    this.isReadOnly = false,
    required this.fieldValueOf,
    required this.onRoleSelected,
    required this.onFieldChanged,
    required this.onCastChanged,
    required this.onKindChanged,
    required this.onDeleteRequested,
    required this.onPersonSheetOpenRequested,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr.resourcesRolesTableTitle,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          tr.resourcesRolesTableSubtitle,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(ocptRadiusMedium),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _buildHeaderRow(theme, tr),
                Divider(height: 1, thickness: 1, color: theme.colorScheme.outlineVariant),
                Expanded(
                  child: ListView.builder(
                    itemCount: roles.length,
                    itemBuilder: (context, index) => _buildRow(context, roles[index]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Builds the table's fixed header row: the column labels, upper-cased and muted.
  Widget _buildHeaderRow(ThemeData theme, Tr tr) {
    final style = theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: _numberColumnWidth,
            child: Text(tr.resourcesRolesColumnNumber.toUpperCase(), style: style),
          ),
          Expanded(flex: _columnFlex[0], child: Text(tr.resourcesRolesColumnRole.toUpperCase(), style: style)),
          Expanded(
            flex: _columnFlex[1],
            child: Text(tr.resourcesRolesColumnCastMember.toUpperCase(), style: style),
          ),
          Expanded(
            flex: _columnFlex[2],
            child: Text(tr.resourcesRolesColumnOtherRoles.toUpperCase(), style: style),
          ),
        ],
      ),
    );
  }

  /// Builds one row of the table, resolving [role]'s cast member and other roles held from
  /// [people] and [roles].
  Widget _buildRow(BuildContext context, OcptRole role) {
    final castMember = _personOf(role.personId);
    final otherRoles = castMember == null
        ? const <OcptRole>[]
        : [for (final other in roles) if (other.id != role.id && other.personId == castMember.id) other];

    return _OcptRoleTableRow(
      key: ValueKey(role.id),
      role: role,
      castMember: castMember,
      otherRoles: otherRoles,
      people: people,
      isSelected: role.id == selectedRoleId,
      isReadOnly: isReadOnly,
      fieldValueOf: (field) => fieldValueOf(role, field),
      onSelected: () => onRoleSelected(role.id),
      onFieldChanged: (field, rawValue) => onFieldChanged(role.id, field, rawValue),
      onCastChanged: (personId) => onCastChanged(role.id, personId),
      onKindChanged: (kind) => onKindChanged(role.id, kind),
      onDeleteRequested: () => onDeleteRequested(role.id),
      onPersonSheetOpenRequested: onPersonSheetOpenRequested,
    );
  }

  /// The person [personId] names, or null when it is null or names nobody in [people] (a stale
  /// reference from a snapshot rebuilt underneath).
  OcptPerson? _personOf(String? personId) {
    if (personId == null) {
      return null;
    }

    for (final person in people) {
      if (person.id == personId) {
        return person;
      }
    }

    return null;
  }
}

/// One row of [OcptRolesTable]: the main row, and — while [isSelected] — its inline editor
/// expanded underneath.
///
/// A [StatefulWidget] (the documented RFL1 exception) because it owns the inline delete
/// confirmation's own ephemeral yes/no state: nothing outside this row needs to know a delete is
/// being confirmed, and the bloc's own state carries no such flag for a role (unlike a project
/// version's `versionPendingDeletionId`, this is never worth surviving a rebuild triggered by
/// something else).
class _OcptRoleTableRow extends StatefulWidget {
  /// The role this row shows.
  final OcptRole role;

  /// The person cast in [role], or null while it is uncast.
  final OcptPerson? castMember;

  /// The other roles [castMember] holds, or empty while uncast or holding only this one.
  final List<OcptRole> otherRoles;

  /// The whole address book, offered by the cast member picker.
  final List<OcptPerson> people;

  /// Whether this row is the selected one, expanding its inline editor.
  final bool isSelected;

  /// Whether the table may not be written to.
  final bool isReadOnly;

  /// [role]'s current value for a field: a pending edit still in the bloc's debounce, or the
  /// role's own stored value.
  final String Function(OcptRoleField field) fieldValueOf;

  /// Called when the row is clicked.
  final VoidCallback onSelected;

  /// Called with the field edited and its raw text on every keystroke.
  final void Function(OcptRoleField field, String rawValue) onFieldChanged;

  /// Called with the person now cast in this role, or null to uncast it.
  final ValueChanged<String?> onCastChanged;

  /// Called with this role's newly picked kind.
  final ValueChanged<OcptRoleKind> onKindChanged;

  /// Called once the inline delete confirmation is answered `Delete`.
  final VoidCallback onDeleteRequested;

  /// Called with the cast member's id when the `↗` affordance is clicked.
  final ValueChanged<String> onPersonSheetOpenRequested;

  /// Class constructor
  const _OcptRoleTableRow({
    super.key,
    required this.role,
    required this.castMember,
    required this.otherRoles,
    required this.people,
    required this.isSelected,
    required this.isReadOnly,
    required this.fieldValueOf,
    required this.onSelected,
    required this.onFieldChanged,
    required this.onCastChanged,
    required this.onKindChanged,
    required this.onDeleteRequested,
    required this.onPersonSheetOpenRequested,
  });

  @override
  State<_OcptRoleTableRow> createState() => _OcptRoleTableRowState();
}

/// The state of [_OcptRoleTableRow]: the row's own inline delete confirmation flag.
class _OcptRoleTableRowState extends State<_OcptRoleTableRow> {
  /// Whether this row currently shows its inline delete confirmation instead of the delete action.
  bool _isConfirmingDelete = false;

  /// Whether deleting this role would actually remove it, which is what decides that the delete
  /// action exists at all.
  ///
  /// False for a role the screenplay still speaks: `OcptRoleIndexService.reconcile` only ever
  /// reads live rows, so the next save would insert that character right back as a fresh, uncast
  /// role — the deletion would cost the casting and the notes without removing anything. Its
  /// existence belongs to the screenplay, exactly as a scene's does to the scene index, so the way
  /// to remove it is to remove the character's cues. A hand-added role, and an orphaned one (whose
  /// character is gone, so nothing will re-insert it), are deleted for good and keep the action.
  bool get _canBeDeleted => !widget.role.isFromScreenplay || widget.role.orphanedName != null;

  @override
  void didUpdateWidget(covariant _OcptRoleTableRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Collapsing the row (or a preview turning the table read-only mid-confirmation, or the role
    // ceasing to be deletable at all because its character came back) always resets the question:
    // reopening it later should ask again, not resume where it left off.
    if (!widget.isSelected || widget.isReadOnly || !_canBeDeleted) {
      _isConfirmingDelete = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        InkWell(
          onTap: widget.onSelected,
          mouseCursor: ocptClickableCursor,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? theme.colorScheme.primary.withValues(alpha: ocptSelectedStateAlpha)
                  : Colors.transparent,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: _buildMainRow(context, theme),
            ),
          ),
        ),
        if (widget.isSelected) _buildExpandedEditor(context, theme),
        Divider(height: 1, thickness: 1, color: theme.colorScheme.outlineVariant),
      ],
    );
  }

  /// Builds the main row's four cells: the number, the role's name, the cast member (with the `↗`
  /// affordance while cast), and the other roles the same person holds.
  Widget _buildMainRow(BuildContext context, ThemeData theme) {
    final tr = Tr.of(context);
    final role = widget.role;
    final castMember = widget.castMember;
    final roleName = role.name.isEmpty ? tr.resourcesRoleUnnamed : role.name;
    final otherRolesText = widget.otherRoles.isEmpty
        ? ocptResourcesEmptyValue
        : widget.otherRoles
              .map((other) => other.name.isEmpty ? tr.resourcesRoleUnnamed : other.name)
              .join(_otherRolesSeparator);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: _numberColumnWidth,
          child: Text("${role.number}", style: theme.textTheme.bodySmall),
        ),
        Expanded(
          flex: _columnFlex[0],
          child: Text(
            roleName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          flex: _columnFlex[1],
          child: Row(
            children: [
              Expanded(
                child: Text(
                  castMember == null
                      ? tr.resourcesRoleNotCast
                      : (castMember.displayName.isEmpty
                            ? tr.resourcesUnnamedPerson
                            : castMember.displayName),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: castMember == null ? theme.colorScheme.onSurfaceVariant : null,
                    fontStyle: castMember == null ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              ),
              if (castMember != null)
                IconButton(
                  icon: const Icon(Icons.north_east, size: 14),
                  tooltip: tr.resourcesOpenPersonSheetTooltip,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => widget.onPersonSheetOpenRequested(castMember.id),
                ),
            ],
          ),
        ),
        Expanded(
          flex: _columnFlex[2],
          child: Text(
            otherRolesText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }

  /// Builds the inline editor expanded under the main row: the name field (or its read-only note
  /// for an `isFromScreenplay` role), the cast member and kind pickers side by side, the casting
  /// notes field, and last the delete action or its inline confirmation.
  Widget _buildExpandedEditor(BuildContext context, ThemeData theme) {
    final tr = Tr.of(context);
    final isReadOnly = widget.isReadOnly;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(ocptRadiusMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildNameField(context, tr),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildCastPicker(context, tr)),
              const SizedBox(width: 16),
              Expanded(child: _buildKindPicker(context, tr)),
            ],
          ),
          const SizedBox(height: 12),
          _OcptRoleTextField(
            roleId: widget.role.id,
            label: tr.resourcesRoleCastingNotesLabel,
            value: widget.fieldValueOf(OcptRoleField.castingNotes),
            multiline: true,
            hintText: tr.resourcesRoleCastingNotesHint,
            onChanged: isReadOnly
                ? null
                : (value) => widget.onFieldChanged(OcptRoleField.castingNotes, value),
          ),
          if (!isReadOnly && _canBeDeleted) ...[
            const SizedBox(height: 12),
            if (_isConfirmingDelete)
              _buildDeleteConfirmation(context, theme, tr)
            else
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => setState(() => _isConfirmingDelete = true),
                  style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
                  child: Text(tr.resourcesRoleDeleteAction),
                ),
              ),
          ],
        ],
      ),
    );
  }

  /// Builds the name field: editable for a hand-added role, read-only text with an explanatory
  /// note for an `isFromScreenplay` one, whose name `OcptRoleIndexService.reconcile` owns.
  Widget _buildNameField(BuildContext context, Tr tr) {
    final role = widget.role;

    if (!role.isFromScreenplay) {
      return _OcptRoleTextField(
        roleId: role.id,
        label: tr.resourcesRoleNameLabel,
        value: widget.fieldValueOf(OcptRoleField.name),
        onChanged: widget.isReadOnly
            ? null
            : (value) => widget.onFieldChanged(OcptRoleField.name, value),
      );
    }

    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr.resourcesRoleNameLabel.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        Text(
          role.name.isEmpty ? tr.resourcesRoleUnnamed : role.name,
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 2),
        Text(
          tr.resourcesRoleNameFromScreenplayNote,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  /// Builds the cast member picker: a label over a badge doubling as a [PopupMenuButton] listing
  /// every person of the address book plus an entry that uncasts, withheld (a plain badge, no
  /// menu) while the table may not be written to.
  Widget _buildCastPicker(BuildContext context, Tr tr) {
    final theme = Theme.of(context);
    final castMember = widget.castMember;
    final currentLabel = castMember == null
        ? tr.resourcesRoleNotCast
        : (castMember.displayName.isEmpty ? tr.resourcesUnnamedPerson : castMember.displayName);

    final badge = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            currentLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
        ),
        if (!widget.isReadOnly) ...[
          const SizedBox(width: 4),
          Icon(Icons.arrow_drop_down, size: 16, color: theme.colorScheme.onSurfaceVariant),
        ],
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr.resourcesRolesColumnCastMember.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        if (widget.isReadOnly)
          badge
        else
          PopupMenuButton<String>(
            tooltip: "",
            onSelected: (value) =>
                widget.onCastChanged(value == _uncastOption ? null : value),
            itemBuilder: (context) => [
              PopupMenuItem<String>(value: _uncastOption, child: Text(tr.resourcesRoleNotCast)),
              const PopupMenuDivider(),
              for (final person in widget.people)
                PopupMenuItem<String>(
                  value: person.id,
                  child: Text(
                    person.displayName.isEmpty ? tr.resourcesUnnamedPerson : person.displayName,
                  ),
                ),
            ],
            child: badge,
          ),
      ],
    );
  }

  /// Builds the role's kind picker: a label over a badge doubling as a [PopupMenuButton] listing
  /// every [OcptRoleKind], withheld (a plain badge, no menu) while the table may not be written to.
  Widget _buildKindPicker(BuildContext context, Tr tr) {
    final theme = Theme.of(context);
    final currentLabel = ocptRoleKindLabel(tr, widget.role.kind);

    final badge = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(currentLabel, style: theme.textTheme.bodySmall),
        if (!widget.isReadOnly) ...[
          const SizedBox(width: 4),
          Icon(Icons.arrow_drop_down, size: 16, color: theme.colorScheme.onSurfaceVariant),
        ],
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr.resourcesRoleKindFieldLabel.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        if (widget.isReadOnly)
          badge
        else
          PopupMenuButton<OcptRoleKind>(
            tooltip: "",
            onSelected: widget.onKindChanged,
            itemBuilder: (context) => [
              for (final kind in OcptRoleKind.values)
                PopupMenuItem<OcptRoleKind>(value: kind, child: Text(ocptRoleKindLabel(tr, kind))),
            ],
            child: badge,
          ),
      ],
    );
  }

  /// Builds the inline delete confirmation shown in place of the delete action: the warning, then
  /// the two answers to it.
  Widget _buildDeleteConfirmation(BuildContext context, ThemeData theme, Tr tr) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        tr.resourcesRoleDeleteConfirmMessage,
        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
      ),
      const SizedBox(height: 6),
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => setState(() => _isConfirmingDelete = false),
            child: Text(tr.resourcesRoleDeleteCancelAction),
          ),
          const SizedBox(width: 6),
          FilledButton(
            onPressed: () {
              setState(() => _isConfirmingDelete = false);
              widget.onDeleteRequested();
            },
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            child: Text(tr.resourcesRoleDeleteConfirmAction),
          ),
        ],
      ),
    ],
  );
}

/// One editable text field of the roles table's expanded row: an upper-cased, `onSurfaceVariant`
/// label over a themed text field, following the same controller-sync idiom as
/// `OcptPersonSheetField` (see its own doc comment) without being the same widget — the roles
/// table stays independent of the person sheet.
///
/// [value] is the field's current authoritative value — a pending edit still sitting in
/// `OcptResourcesState.pendingRoleFieldEdits`, or the role's own stored value otherwise. The
/// internal controller is only ever reset to it when [roleId] changes or when [value] genuinely
/// differs from what the controller already holds, so the caret never jumps mid-typing.
class _OcptRoleTextField extends StatefulWidget {
  /// The id of the role this field belongs to, used only to detect a role switch.
  final String roleId;

  /// The field's label, upper-cased for display.
  final String label;

  /// The field's current authoritative value, raw.
  final String value;

  /// Whether this field is written as several lines instead of a single one.
  final bool multiline;

  /// The greyed placeholder shown while the field is empty, or null for none.
  final String? hintText;

  /// Called with the field's raw text on every keystroke, or null while the field may not be
  /// written to: it then reads its value out — selectable, so it can still be copied — with no
  /// reaction to typing.
  final ValueChanged<String>? onChanged;

  /// Class constructor
  const _OcptRoleTextField({
    required this.roleId,
    required this.label,
    required this.value,
    this.multiline = false,
    this.hintText,
    required this.onChanged,
  });

  @override
  State<_OcptRoleTextField> createState() => _OcptRoleTextFieldState();
}

/// The state of [_OcptRoleTextField]: owns the controller the class doc comment explains the
/// reasoning for.
class _OcptRoleTextFieldState extends State<_OcptRoleTextField> {
  /// The field's own text editing controller, seeded from the widget's initial value and kept in
  /// sync with it afterward, see [didUpdateWidget].
  late final TextEditingController _controller = TextEditingController(text: widget.value);

  /// The [_OcptRoleTextField.roleId] the controller was last synced against, so a role switch is
  /// detected even when the two roles happen to share the same field value.
  late String _trackedRoleId = widget.roleId;

  @override
  void didUpdateWidget(covariant _OcptRoleTextField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.roleId != _trackedRoleId || widget.value != _controller.text) {
      _controller.text = widget.value;
      _trackedRoleId = widget.roleId;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: _controller,
          readOnly: widget.onChanged == null,
          onChanged: widget.onChanged,
          maxLines: widget.multiline ? null : 1,
          minLines: widget.multiline ? _castingNotesMinLines : 1,
          style: theme.textTheme.bodySmall,
          decoration: InputDecoration(isDense: true, hintText: widget.hintText),
        ),
      ],
    );
  }
}
