// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/utils/ocpt_responsive.dart';

/// A dialog asking the user for the name of the new project they want to create.
///
/// Shows a single, validated (non-empty) text field. Use [show] to display it and get back the
/// entered name, or null if the user cancelled. Renders as a centered `AlertDialog` above the
/// compact-width breakpoint and as a full-screen dialog with its own `AppBar` below it, so the
/// keyboard never squeezes a phone-sized dialog into an unreadable sliver.
class OcptNewProjectNameDialog extends StatefulWidget {
  /// Class constructor
  const OcptNewProjectNameDialog({super.key});

  /// Shows the dialog and returns the name entered by the user, or null if they cancelled it.
  static Future<String?> show(BuildContext context) => showDialog<String>(
    context: context,
    builder: (context) => const OcptNewProjectNameDialog(),
  );

  @override
  State<OcptNewProjectNameDialog> createState() =>
      _OcptNewProjectNameDialogState();
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

    final nameField = TextFormField(
      controller: _nameController,
      autofocus: true,
      decoration: InputDecoration(labelText: tr.homeNewProjectDialogNameLabel),
      validator: (value) => (value == null || value.trim().isEmpty)
          ? tr.homeNewProjectDialogNameEmptyError
          : null,
      onFieldSubmitted: (_) => _submit(),
    );

    if (ocptIsCompactWidth(MediaQuery.sizeOf(context).width)) {
      return Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              onPressed: () => globalGetIt().get<OcptRouterManager>().pop(),
              icon: const Icon(Icons.close),
              tooltip: tr.homeNewProjectDialogCancelAction,
            ),
            title: Text(tr.homeNewProjectDialogTitle),
            actions: [
              TextButton(
                onPressed: _submit,
                child: Text(tr.homeNewProjectDialogCreateAction),
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(key: _formKey, child: nameField),
          ),
        ),
      );
    }

    return AlertDialog(
      title: Text(tr.homeNewProjectDialogTitle),
      content: Form(key: _formKey, child: nameField),
      actions: [
        TextButton(
          onPressed: () => globalGetIt().get<OcptRouterManager>().pop(),
          child: Text(tr.homeNewProjectDialogCancelAction),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(tr.homeNewProjectDialogCreateAction),
        ),
      ],
    );
  }

  /// Validates the entered name and, if it's valid, pops the dialog returning it.
  ///
  /// The dialog is dismissed through the router manager (RFL31: navigation only via the router
  /// manager), whose pop delivers the trimmed name back to the [OcptNewProjectNameDialog.show]
  /// caller.
  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      final trimmedName = _nameController.text.trim();
      globalGetIt().get<OcptRouterManager>().pop<String>(trimmedName);
    }
  }
}
