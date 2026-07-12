// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <benoit.rolandeau@allcircuits.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';

/// A dialog asking the user for the name of the new project they want to create.
///
/// Shows a single, validated (non-empty) text field. Use [show] to display it and get back the
/// entered name, or null if the user cancelled.
class OcptNewProjectNameDialog extends StatefulWidget {
  /// Class constructor
  const OcptNewProjectNameDialog({super.key});

  /// Shows the dialog and returns the name entered by the user, or null if they cancelled it.
  static Future<String?> show(BuildContext context) =>
      showDialog<String>(context: context, builder: (context) => const OcptNewProjectNameDialog());

  @override
  State<OcptNewProjectNameDialog> createState() => _OcptNewProjectNameDialogState();
}

/// The state of [OcptNewProjectNameDialog].
class _OcptNewProjectNameDialogState extends State<OcptNewProjectNameDialog> {
  /// The form used to validate the entered name.
  final _formKey = GlobalKey<FormState>();

  /// The controller of the name text field.
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return AlertDialog(
      title: Text(tr.homeNewProjectDialogTitle),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _nameController,
          autofocus: true,
          decoration: InputDecoration(labelText: tr.homeNewProjectDialogNameLabel),
          validator: (value) =>
              (value == null || value.trim().isEmpty) ? tr.homeNewProjectDialogNameEmptyError : null,
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(tr.homeNewProjectDialogCancelAction),
        ),
        FilledButton(onPressed: _submit, child: Text(tr.homeNewProjectDialogCreateAction)),
      ],
    );
  }

  /// Validates the entered name and, if it's valid, pops the dialog returning it.
  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      Navigator.of(context).pop(_nameController.text.trim());
    }
  }
}
