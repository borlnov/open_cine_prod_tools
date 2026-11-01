// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/types/ocpt_editor_right_dock_tab.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_event.dart';

/// A toolbar button showing, and toggling, one tab of the right dock: filled while the tab is the
/// active one, outlined otherwise.
class OcptEditorDockTabToggle extends StatelessWidget {
  /// The tab this button selects.
  final OcptEditorRightDockTab tab;

  /// Whether the dock currently shows [tab].
  final bool isActive;

  /// The icon drawn while [tab] is the active one.
  final IconData activeIcon;

  /// The icon drawn otherwise.
  final IconData inactiveIcon;

  /// The localized tooltip.
  final String tooltip;

  /// Class constructor
  const OcptEditorDockTabToggle({
    required this.tab,
    required this.isActive,
    required this.activeIcon,
    required this.inactiveIcon,
    required this.tooltip,
    super.key,
  });

  @override
  Widget build(BuildContext context) => IconButton(
    icon: Icon(isActive ? activeIcon : inactiveIcon, size: 20),
    tooltip: tooltip,
    isSelected: isActive,
    onPressed: () =>
        context.read<OcptEditorBloc>().add(OcptEditorRightDockTabSelectedEvent(tab: tab)),
  );
}
