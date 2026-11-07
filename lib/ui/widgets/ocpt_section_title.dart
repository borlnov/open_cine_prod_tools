// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';

/// One section title: the accent-coloured header that separates the sections of an inspector
/// panel.
class OcptSectionTitle extends StatelessWidget {
  /// The title's text.
  final String title;

  /// Class constructor
  const OcptSectionTitle({super.key, required this.title});

  /// Build the section title as a [Text].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Text(
      title,
      style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary),
    );
  }
}
