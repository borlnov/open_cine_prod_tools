// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';

/// What the user filled in [OcptProjectVersionCreateDialog], handed back to the mode that opened
/// it.
typedef OcptProjectVersionCreationFields = ({String name, String note});

/// The dialog naming a new project version: a required name, and an optional free-text note.
///
/// Use [show] to display it and get the fields back, or null if the user cancelled. Dismissed
/// through `OcptRouterManager.pop`, never `Navigator`, exactly like every other dialog of the app.
///
/// The name is required because it is the only thing telling two versions apart in the list; the
/// note is not, since plenty of checkpoints ("end of the day") need no explanation.
class OcptProjectVersionCreateDialog extends StatefulWidget {
  /// Class constructor
  const OcptProjectVersionCreateDialog({super.key});

  /// Shows the dialog and returns the fields the user confirmed, or null if they cancelled it.
  static Future<OcptProjectVersionCreationFields?> show(BuildContext context) =>
      showDialog<OcptProjectVersionCreationFields>(
        context: context,
        builder: (context) => const OcptProjectVersionCreateDialog(),
      );

  @override
  State<OcptProjectVersionCreateDialog> createState() => _OcptProjectVersionCreateDialogState();
}

/// The state of [OcptProjectVersionCreateDialog].
class _OcptProjectVersionCreateDialogState extends State<OcptProjectVersionCreateDialog> {
  /// The form used to validate the entered name.
  final _formKey = GlobalKey<FormState>();

  /// The controller of the version name field.
  final _nameController = TextEditingController();

  /// The controller of the version note field.
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return AlertDialog(
      title: Text(tr.projectVersionCreateDialogTitle),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr.projectVersionCreateDialogMessage),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              autofocus: true,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(labelText: tr.projectVersionCreateNameLabel),
              validator: (value) =>
                  (value ?? "").trim().isEmpty ? tr.projectVersionCreateNameRequiredError : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _noteController,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(labelText: tr.projectVersionCreateNoteLabel),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => globalGetIt().get<OcptRouterManager>().pop(),
          child: Text(tr.projectVersionCreateCancelAction),
        ),
        FilledButton(onPressed: _submit, child: Text(tr.projectVersionCreateConfirmAction)),
      ],
    );
  }

  /// Validates the entered name and, if it is valid, pops the dialog returning both fields
  /// trimmed.
  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    globalGetIt().get<OcptRouterManager>().pop<OcptProjectVersionCreationFields>((
      name: _nameController.text.trim(),
      note: _noteController.text.trim(),
    ));
  }
}
