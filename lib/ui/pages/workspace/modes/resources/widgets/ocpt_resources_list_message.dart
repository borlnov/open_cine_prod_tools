// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';

/// The one line a left dock list shows in place of its rows: the hint of a tab holding nothing yet,
/// or the "no match" line of a search that filtered every row out.
///
/// Shared by the four lists (`OcptPeopleList`, `OcptRolesList`, `OcptLocationsList`,
/// `OcptElementsList`), so a tab that is empty and a tab whose query found nothing can never end up
/// reading in two different type styles — the same reason `OcptResourcesNotesCard` and
/// `OcptResourcesDeleteAction` are one widget each rather than one per sheet.
class OcptResourcesListMessage extends StatelessWidget {
  /// The message to show.
  final String message;

  /// Class constructor
  const OcptResourcesListMessage({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        message,
        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}
