// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';

/// The dialog every resources record is deleted through — a person, a role, a location, an
/// element.
///
/// One dialog for the four of them, and a dialog rather than an inline yes/no: deleting a record is
/// the same gesture whichever tab it is asked from, so it must be answered the same way everywhere,
/// the way `OcptShotDeleteConfirmDialog` already asks it in the shot list. Use [show] to display it
/// and get back whether the user confirmed the deletion; it is dismissed through
/// `OcptRouterManager.pop`, never `Navigator`.
///
/// The caller owns the wording ([title], [message]): what is being deleted, and what is lost along
/// with it, is the one thing this dialog cannot know — a person's message states that the deletion
/// is an **erasure** (`OcptPeopleService.deletePerson` tombstones the row *and* blanks its personal
/// columns in the same write), a location's that its sets go with it.
class OcptResourcesDeleteConfirmDialog extends StatelessWidget {
  /// The question the dialog asks, e.g. `Delete this location?`.
  final String title;

  /// The line stating what the deletion costs, shown under [title].
  final String message;

  /// Class constructor
  const OcptResourcesDeleteConfirmDialog({super.key, required this.title, required this.message});

  /// Shows the dialog and returns true if the user confirmed the deletion, false or null if they
  /// cancelled it.
  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String message,
  }) => showDialog<bool>(
    context: context,
    builder: (context) => OcptResourcesDeleteConfirmDialog(title: title, message: message),
  );

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return AlertDialog(
      title: Text(title),
      content: Text(message),
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
