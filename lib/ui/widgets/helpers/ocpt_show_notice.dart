// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';

/// Show [message] as the one notice of the nearest [ScaffoldMessenger], replacing the one still
/// on screen.
///
/// Every outcome the app reports in passing goes through here, and nowhere else shows a
/// `SnackBar`, so a failure never looks like a success: when [isError] is true the notice takes
/// the error container colours of the theme and an error icon, and otherwise it keeps the
/// default look of a SnackBar.
void ocptShowNotice(BuildContext context, String message, {required bool isError}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: isError ? Theme.of(context).colorScheme.errorContainer : null,
        content: OcptNoticeContent(message: message, isError: isError),
      ),
    );
}

/// The content of a notice: its [message], preceded by an error icon when [isError] is true.
class OcptNoticeContent extends StatelessWidget {
  /// The text the notice reports.
  final String message;

  /// Whether the notice reports a failure.
  final bool isError;

  /// Class constructor
  const OcptNoticeContent({required this.message, required this.isError, super.key});

  /// Build the message, with the error icon and the error colours when [isError] is true.
  @override
  Widget build(BuildContext context) {
    if (!isError) {
      return Text(message);
    }

    final onErrorContainer = Theme.of(context).colorScheme.onErrorContainer;

    return Row(
      children: [
        Icon(Icons.error_outline, color: onErrorContainer),
        const SizedBox(width: 12),
        Expanded(
          child: Text(message, style: TextStyle(color: onErrorContainer)),
        ),
      ],
    );
  }
}
