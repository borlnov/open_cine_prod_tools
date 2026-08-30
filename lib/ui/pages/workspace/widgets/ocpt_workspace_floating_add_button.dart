// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';

/// Overlays [child] — a production mode's own centre content — with a floating "add" affordance,
/// drawn only at a compact width.
///
/// Below `ocptCompactWidthBreakpoint` the workspace shell's side docks reduce to edge drawers
/// (`OcptWorkspaceShell`), so a record can no longer be added from a persistent dock: the shot list
/// mode's `+ Shot` sits in the left dock, and the budget mode's `+ New` sits in the header band that
/// stays reachable, but neither is worth summoning a drawer for on a phone or a tablet. This widget
/// gives the centre its own way in, wired to the very same creation flow the desktop control already
/// fires — never a new one — so the two stay in lockstep by construction.
///
/// [isVisible] is the caller's own `ocptIsCompactWidth` reading of the workspace's width, taken
/// *outside* this widget (over the shell's own row width, not [child]'s own — narrowed by whichever
/// docks are open at an expanded width, which would misdetect compactness): a mode measures it once,
/// alongside every other width-keyed decision the shell's own [LayoutBuilder] makes.
///
/// [onPressed] is withheld — a null callback, never a disabled button — exactly when the desktop
/// affordance it mirrors would be: under a read-only version preview, or whenever nothing can be
/// added right now. A null [onPressed] draws no button at all, matching the app's standing read-only
/// idiom (`CLAUDE.md`).
class OcptWorkspaceFloatingAddButton extends StatelessWidget {
  /// The mode's own centre content, drawn unchanged under the floating button.
  final Widget child;

  /// Whether the workspace is at a compact width — see the class doc comment for how the caller
  /// reads it.
  final bool isVisible;

  /// The label the button carries — the same word its desktop sibling already uses (`+ Shot`,
  /// `New`), resolved by the mode so no manager ever sees a `Tr`.
  final String label;

  /// A leading icon to draw before [label], or null when the label already carries its own visual
  /// cue (the shot list's `+ Shot` reads as a plus sign on its own).
  final IconData? icon;

  /// Fires the mode's existing record-creation flow, or null to withhold the button entirely.
  final VoidCallback? onPressed;

  /// Class constructor
  const OcptWorkspaceFloatingAddButton({
    super.key,
    required this.child,
    required this.isVisible,
    required this.label,
    this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final onPressed = this.onPressed;
    if (!isVisible || onPressed == null) {
      return child;
    }

    final icon = this.icon;

    return Stack(
      children: [
        Positioned.fill(child: child),
        Positioned(
          right: 16,
          bottom: 16,
          child: icon == null
              ? FloatingActionButton.extended(onPressed: onPressed, label: Text(label))
              : FloatingActionButton.extended(
                  onPressed: onPressed,
                  icon: Icon(icon),
                  label: Text(label),
                ),
        ),
      ],
    );
  }
}
