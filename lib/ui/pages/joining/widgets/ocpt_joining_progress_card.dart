// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';

/// The Rejoindre screen's own busy state, shown for the whole of a join: fetching the relay's
/// snapshot, materialising it as a new project and opening it (`docs/plans/relay.md`, Phase C,
/// commit 4). An indefinite spinner rather than a percentage — nothing on the join path reports
/// incremental progress, unlike the mock-up's own illustrative "68 %".
class OcptJoiningProgressCard extends StatelessWidget {
  /// Class constructor
  const OcptJoiningProgressCard({super.key});

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3)),
            const SizedBox(width: 14),
            Expanded(child: Text(tr.joiningProgressTitle, style: theme.textTheme.titleSmall)),
          ],
        ),
      ),
    );
  }
}
