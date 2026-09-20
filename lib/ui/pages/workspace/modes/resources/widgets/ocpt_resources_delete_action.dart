// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';

/// The destructive action every resources sheet carries at its very bottom — `Delete this person`,
/// `Delete this role`, `Delete this location`, `Delete this element`.
///
/// It only asks: the question itself is `OcptResourcesDeleteConfirmDialog`, shown by the mode, so
/// the four sheets stay unaware of how the answer is obtained and every deletion in the app is
/// confirmed the same way. The action only ever renders when the sheet may be written to, so it
/// takes a plain non-null callback rather than a nullable one.
///
/// It is a **solid, error-filled** button — the same `error`/`onError` fill `OcptConfirmDialog`
/// gives its own destructive confirm — rather than a plain text button, so the one irreversible
/// action on the sheet reads as such at a glance instead of hiding among the fields above it.
class OcptResourcesDeleteAction extends StatelessWidget {
  /// The action's own label, e.g. `Delete this location`.
  final String label;

  /// Called when the action is clicked, before anything is deleted: the confirmation the caller
  /// opens is what decides.
  final VoidCallback onDeleteRequested;

  /// Class constructor
  const OcptResourcesDeleteAction({
    super.key,
    required this.label,
    required this.onDeleteRequested,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Align(
      alignment: Alignment.centerRight,
      child: FilledButton(
        onPressed: onDeleteRequested,
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.error,
          foregroundColor: colorScheme.onError,
        ),
        child: Text(label),
      ),
    );
  }
}
