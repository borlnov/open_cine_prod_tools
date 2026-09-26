// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';

/// The dialog opened the moment a character symbol is placed on the floor plans canvas (R2, "the
/// name popover on placement"), setting or changing its own free-text `label`.
///
/// [suggestedNames] — the selected shot's own `OcptShot.characters` — are offered as one-click
/// picks, **a convenience only**: a character symbol carries no `roleId`, and **the same name may
/// be set on several symbols on purpose** (showing one person's own movement between two
/// placements with an arrow), so nothing here enforces uniqueness. Free text always works too, and
/// [initialValue] is already the placement's own default pre-fill
/// (`OcptShotListBloc._defaultCharacterLabelFor`), so dismissing this dialog without changing
/// anything simply keeps it.
///
/// Purely presentational, modelled on `OcptScheduleShotPickerDialog`: [show] opens it and returns
/// the name picked (trimmed), or null if the user dismissed it. The router manager
/// (`OcptRouterManager`, never `Navigator`) is what actually pops it.
class OcptFloorPlanCharacterNamePickerDialog extends StatefulWidget {
  /// The symbol's own current label, pre-filling the free-text field.
  final String initialValue;

  /// The selected shot's own characters, offered as one-click picks, in their own order,
  /// deduplicated.
  final List<String> suggestedNames;

  /// Class constructor
  const OcptFloorPlanCharacterNamePickerDialog({
    super.key,
    required this.initialValue,
    required this.suggestedNames,
  });

  /// Shows the dialog and returns the name picked (trimmed), or null if the user dismissed it.
  static Future<String?> show(
    BuildContext context, {
    required String initialValue,
    required List<String> suggestedNames,
  }) => showDialog<String>(
    context: context,
    builder: (context) => OcptFloorPlanCharacterNamePickerDialog(
      initialValue: initialValue,
      suggestedNames: suggestedNames,
    ),
  );

  @override
  State<OcptFloorPlanCharacterNamePickerDialog> createState() =>
      _OcptFloorPlanCharacterNamePickerDialogState();
}

class _OcptFloorPlanCharacterNamePickerDialogState
    extends State<OcptFloorPlanCharacterNamePickerDialog> {
  /// The free-text field's own controller, pre-filled from [OcptFloorPlanCharacterNamePickerDialog
  /// .initialValue].
  late final TextEditingController _controller = TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(tr.shotListFloorPlanCharacterNamePickerTitle),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                isDense: true,
                hintText: tr.shotListFloorPlanCharacterNamePickerFieldHint,
              ),
              onSubmitted: _submit,
            ),
            if (widget.suggestedNames.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                tr.shotListFloorPlanCharacterNamePickerSuggestionsTitle,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final name in widget.suggestedNames)
                    ActionChip(label: Text(name), onPressed: () => _submit(name)),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => globalGetIt().get<OcptRouterManager>().pop(),
          child: Text(tr.shotListFloorPlanCharacterNamePickerCancelAction),
        ),
        FilledButton(
          onPressed: () => _submit(_controller.text),
          child: Text(tr.shotListFloorPlanCharacterNamePickerSetAction),
        ),
      ],
    );
  }

  /// Pops the dialog with [value], trimmed.
  void _submit(String value) => globalGetIt().get<OcptRouterManager>().pop<String>(value.trim());
}
