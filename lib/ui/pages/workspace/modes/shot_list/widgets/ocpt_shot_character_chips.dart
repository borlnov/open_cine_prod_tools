// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';

/// The shot inspector's "Characters in shot" chips: one toggleable chip per role of the whole
/// production's cast, plus a trailing **`＋ Add`** affordance resolving or creating one by name
/// (`docs/adr/0030-a-shots-characters-are-the-productions-roles.md`, decision 1).
///
/// Every attached role is necessarily one of [roles]: a shot now points at a role that always
/// exists (the store is roleId-keyed, decision 6), so there is no more struck-through "removed"
/// case to report here — an orphaned role's own alert is `OcptRoleAlertBanner`'s job, shown above
/// the table, not this chip row's.
///
/// Toggling a chip writes immediately — there is no typing debounce for this. The `＋ Add`
/// affordance opens a small inline text field on click: a typed name matching a live role attaches
/// it, one matching none creates a hand-added silent role and attaches it — the resolve-or-create
/// itself is the bloc's job, this widget only ever hands the typed name back through
/// [onCharacterAdded].
class OcptShotCharacterChips extends StatelessWidget {
  /// Every role of the whole production's cast, in display order.
  final List<OcptRole> roles;

  /// The ids of [roles] currently attached to this shot.
  final List<String> attachedRoleIds;

  /// Called with a role's id when its chip is clicked, or null while the cast may not be changed (a
  /// project version being previewed read-only): the chips then read out who is in the shot without
  /// reacting to a click.
  final ValueChanged<String>? onToggled;

  /// Called with a typed name when the `＋ Add` field is submitted, or null to withhold the whole
  /// affordance (a project version being previewed read-only).
  final ValueChanged<String>? onCharacterAdded;

  /// Class constructor
  const OcptShotCharacterChips({
    super.key,
    required this.roles,
    required this.attachedRoleIds,
    required this.onToggled,
    required this.onCharacterAdded,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final onToggled = this.onToggled;
    final onCharacterAdded = this.onCharacterAdded;

    if (roles.isEmpty && onCharacterAdded == null) {
      return Text(
        tr.shotListCharactersEmptyHint,
        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final role in roles)
          _OcptCharacterChip(
            name: role.name.isEmpty ? tr.resourcesRoleUnnamed : role.name,
            isAttached: attachedRoleIds.contains(role.id),
            onTap: onToggled == null ? null : () => onToggled(role.id),
          ),
        if (onCharacterAdded != null) _OcptAddCharacterChip(onSubmitted: onCharacterAdded),
      ],
    );
  }
}

/// One chip of [OcptShotCharacterChips].
class _OcptCharacterChip extends StatelessWidget {
  /// The role's display name.
  final String name;

  /// Whether this role is currently attached to the shot.
  final bool isAttached;

  /// Called when this chip is clicked, or null when the chip may not be toggled at all.
  final VoidCallback? onTap;

  /// Class constructor
  const _OcptCharacterChip({required this.name, required this.isAttached, required this.onTap});

  @override
  Widget build(BuildContext context) => FilterChip(
    label: Text(name),
    selected: isAttached,
    onSelected: onTap == null ? null : (_) => onTap!(),
  );
}

/// The trailing `＋ Add` affordance of [OcptShotCharacterChips]: a chip that turns into a small
/// inline text field on click, submitting the typed name to [onSubmitted] and collapsing back —
/// on `Enter`, or on losing focus with something typed. Losing focus with nothing typed simply
/// collapses back with no call at all.
class _OcptAddCharacterChip extends StatefulWidget {
  /// Called with the typed name once the field is submitted.
  final ValueChanged<String> onSubmitted;

  /// Class constructor
  const _OcptAddCharacterChip({required this.onSubmitted});

  @override
  State<_OcptAddCharacterChip> createState() => _OcptAddCharacterChipState();
}

/// The state of [_OcptAddCharacterChip]: whether the inline field is currently shown, and its
/// controller.
class _OcptAddCharacterChipState extends State<_OcptAddCharacterChip> {
  /// The width of the inline text field, wide enough for a first and last name.
  static const double _fieldWidth = 160;

  /// Whether the inline field is shown in place of the `＋ Add` chip.
  bool _isEditing = false;

  /// The inline field's own text.
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Submits the typed name (trimmed) if it isn't empty, then collapses back to the chip either
  /// way, clearing the field.
  void _submit() {
    final value = _controller.text.trim();
    if (value.isNotEmpty) {
      widget.onSubmitted(value);
    }
    setState(() {
      _isEditing = false;
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isEditing) {
      return ActionChip(
        avatar: const Icon(Icons.add, size: 16),
        label: Text(Tr.of(context).shotListAddCharacterAction),
        onPressed: () => setState(() => _isEditing = true),
      );
    }

    return SizedBox(
      width: _fieldWidth,
      child: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          isDense: true,
          hintText: Tr.of(context).shotListAddCharacterHint,
          border: const OutlineInputBorder(),
        ),
        onSubmitted: (_) => _submit(),
        onTapOutside: (_) => _submit(),
      ),
    );
  }
}
