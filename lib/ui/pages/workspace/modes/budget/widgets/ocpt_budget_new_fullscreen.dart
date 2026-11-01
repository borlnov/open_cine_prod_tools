// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';

/// The compact rendering, below `ocptCompactWidthBreakpoint` — mirrors
/// `OcptNewProjectNameDialog`'s own `Dialog.fullscreen` shell, holding the exact same three-step
/// content the `AlertDialog` would otherwise hold. The trail-carrying title moves into the
/// `AppBar`, tall enough to hold it whether or not step 2/3's own trail row is drawn, and the
/// leading `×` cancels the whole wizard — never a step-back, which stays in [stepActions]
/// alongside `Continue`/`Save`, both now living in a bottom bar since there is no `AlertDialog`
/// left to draw them as.
class OcptBudgetNewFullscreen extends StatelessWidget {
  /// The wizard's title, trail included.
  final Widget title;

  /// The current step's content.
  final Widget stepContent;

  /// The current step's actions.
  final List<Widget> stepActions;

  /// Whether the title carries a trail row, which makes the app bar taller.
  final bool showsTrail;

  /// Called when the leading `×` is pressed.
  final VoidCallback onCancelRequested;

  /// Class constructor
  const OcptBudgetNewFullscreen({
    super.key,
    required this.title,
    required this.stepContent,
    required this.stepActions,
    required this.showsTrail,
    required this.onCancelRequested,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);

    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: showsTrail ? kToolbarHeight + 28 : kToolbarHeight,
          leading: IconButton(
            key: const Key("ocptBudgetNewFullscreenCloseButton"),
            onPressed: onCancelRequested,
            icon: const Icon(Icons.close),
            tooltip: tr.budgetEntryDialogCancelAction,
          ),
          title: title,
        ),
        body: SafeArea(
          child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: stepContent),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: theme.dividerColor)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: OverflowBar(alignment: MainAxisAlignment.end, spacing: 8, children: stepActions),
          ),
        ),
      ),
    );
  }
}
