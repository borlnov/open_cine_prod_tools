// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/types/ocpt_person_editable_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_person_sheet_card.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_person_sheet_field.dart';

/// "Meals, health, skills": [OcptPerson.dietaryNotes] and [OcptPerson.allergies] (both free text,
/// through the sheet's own `OcptPersonField` debounce), and the skills as removable chips plus an
/// add affordance.
///
/// The costume sizes are **not** here: they belong to `OcptPersonSheetHmcCard`, beside the
/// measurements a fitting reads them with, rather than beside a person's allergies and driving
/// licences.
class OcptPersonSheetMealsHealthCard extends StatelessWidget {
  /// The person these fields belong to.
  final String personId;

  /// The person's skills, in display order.
  final List<OcptPersonSkill> skills;

  /// [personId]'s current value for `field`: a pending edit still in the bloc's debounce, or the
  /// person's own stored value.
  final String Function(OcptPersonField field) fieldValueOf;

  /// Called with a field's raw text on every keystroke, or null while the sheet may not be
  /// written to.
  final void Function(OcptPersonField field, String rawValue)? onFieldChanged;

  /// Called with a new skill's label when the add affordance is submitted, or null while none may
  /// be added.
  final ValueChanged<String>? onSkillAdded;

  /// Called with a skill's id when its chip's remove control is clicked, or null while it may not
  /// be removed.
  final ValueChanged<String>? onSkillRemoved;

  /// Class constructor
  const OcptPersonSheetMealsHealthCard({
    super.key,
    required this.personId,
    required this.skills,
    required this.fieldValueOf,
    required this.onFieldChanged,
    required this.onSkillAdded,
    required this.onSkillRemoved,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return OcptPersonSheetCard(
      title: tr.resourcesMealsHealthTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OcptPersonSheetField(
            personId: personId,
            label: tr.resourcesDietaryNotesLabel,
            value: fieldValueOf(OcptPersonField.dietaryNotes),
            onChanged: _onFieldChangedOrNull(OcptPersonField.dietaryNotes),
          ),
          const SizedBox(height: 10),
          OcptPersonSheetField(
            personId: personId,
            label: tr.resourcesAllergiesLabel,
            value: fieldValueOf(OcptPersonField.allergies),
            onChanged: _onFieldChangedOrNull(OcptPersonField.allergies),
          ),
          const SizedBox(height: 10),
          Text(
            tr.resourcesSkillsLabel.toUpperCase(),
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 6),
          _OcptPersonSkillChips(skills: skills, onAdded: onSkillAdded, onRemoved: onSkillRemoved),
        ],
      ),
    );
  }

  /// The `onChanged` a field of [field] is given: the one reporting to [onFieldChanged], or null
  /// while the sheet may not be written to.
  ValueChanged<String>? _onFieldChangedOrNull(OcptPersonField field) {
    final onFieldChanged = this.onFieldChanged;
    if (onFieldChanged == null) {
      return null;
    }
    return (value) => onFieldChanged(field, value);
  }
}

/// The person's skills as a [Wrap] of removable chips, plus a trailing add affordance that opens
/// an inline text field on tap.
class _OcptPersonSkillChips extends StatefulWidget {
  /// The skills to show.
  final List<OcptPersonSkill> skills;

  /// Called with a new skill's label, or null while none may be added: the add affordance itself
  /// disappears then.
  final ValueChanged<String>? onAdded;

  /// Called with a skill's id when its chip's remove control is clicked, or null while it may not
  /// be removed: every chip's remove control disappears then.
  final ValueChanged<String>? onRemoved;

  /// Class constructor
  const _OcptPersonSkillChips({required this.skills, required this.onAdded, required this.onRemoved});

  @override
  State<_OcptPersonSkillChips> createState() => _OcptPersonSkillChipsState();
}

/// The state of [_OcptPersonSkillChips]: whether the inline add field is currently shown.
class _OcptPersonSkillChipsState extends State<_OcptPersonSkillChips> {
  /// The inline add field's own controller.
  final TextEditingController _addController = TextEditingController();

  /// The inline add field's own focus node, so it can be given the focus the moment it appears.
  final FocusNode _addFocusNode = FocusNode();

  /// Whether the inline add field is currently shown in place of the `+` affordance.
  bool _isAdding = false;

  @override
  void dispose() {
    _addController.dispose();
    _addFocusNode.dispose();
    super.dispose();
  }

  /// Shows the inline add field and gives it the focus.
  void _startAdding() {
    setState(() => _isAdding = true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _addFocusNode.requestFocus());
  }

  /// Submits whatever the add field currently holds, if not blank, then hides it again.
  void _submit() {
    final label = _addController.text.trim();
    if (label.isNotEmpty) {
      widget.onAdded?.call(label);
    }
    _addController.clear();
    setState(() => _isAdding = false);
  }

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final onAdded = widget.onAdded;

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final skill in widget.skills)
          _OcptSkillChip(
            label: skill.label,
            onRemoved: widget.onRemoved == null ? null : () => widget.onRemoved!(skill.id),
          ),
        if (onAdded != null)
          if (_isAdding)
            SizedBox(
              width: 140,
              child: TextField(
                controller: _addController,
                focusNode: _addFocusNode,
                style: Theme.of(context).textTheme.labelMedium,
                decoration: InputDecoration(isDense: true, hintText: tr.resourcesAddSkillHint),
                onSubmitted: (_) => _submit(),
                onEditingComplete: _submit,
              ),
            )
          else
            ActionChip(label: const Text("+"), onPressed: _startAdding),
      ],
    );
  }
}

/// One removable skill chip.
class _OcptSkillChip extends StatelessWidget {
  /// The skill's label.
  final String label;

  /// Called when the chip's remove control is clicked, or null while it may not be removed (a
  /// plain, non-deletable chip is shown then).
  final VoidCallback? onRemoved;

  /// Class constructor
  const _OcptSkillChip({required this.label, required this.onRemoved});

  @override
  Widget build(BuildContext context) {
    final onRemoved = this.onRemoved;
    final labelWidget = Text(label, style: Theme.of(context).textTheme.labelMedium);

    if (onRemoved == null) {
      return Chip(label: labelWidget);
    }

    return InputChip(
      label: labelWidget,
      onDeleted: onRemoved,
      deleteButtonTooltipMessage: Tr.of(context).resourcesRemoveSkillTooltip,
    );
  }
}
