// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';

/// A dialog confirming that a person is about to be erased from the address book.
///
/// Use [show] to display it and get back whether the user confirmed the deletion. Modelled on
/// `OcptShotDeleteConfirmDialog`: dismissed through `OcptRouterManager.pop`, never `Navigator`. Its
/// message is deliberately explicit that this is an **erasure** — `OcptPeopleService.deletePerson`
/// tombstones the row *and* blanks its personal columns in the same write — and that it cannot be
/// undone.
class OcptPersonDeleteConfirmDialog extends StatelessWidget {
  /// The display name of the person about to be erased, already resolved to
  /// `resourcesUnnamedPerson` when they have none.
  final String personName;

  /// Class constructor
  const OcptPersonDeleteConfirmDialog({super.key, required this.personName});

  /// Shows the dialog and returns true if the user confirmed the deletion, false or null if they
  /// cancelled it.
  static Future<bool?> show(BuildContext context, {required String personName}) =>
      showDialog<bool>(
        context: context,
        builder: (context) => OcptPersonDeleteConfirmDialog(personName: personName),
      );

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return AlertDialog(
      title: Text(tr.resourcesDeleteConfirmTitle),
      content: Text(tr.resourcesDeleteConfirmMessage(personName)),
      actions: [
        TextButton(
          onPressed: () => globalGetIt().get<OcptRouterManager>().pop(),
          child: Text(tr.resourcesDeleteConfirmCancelAction),
        ),
        FilledButton(
          onPressed: () => globalGetIt().get<OcptRouterManager>().pop<bool>(true),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          child: Text(tr.resourcesDeleteConfirmDeleteAction),
        ),
      ],
    );
  }
}
