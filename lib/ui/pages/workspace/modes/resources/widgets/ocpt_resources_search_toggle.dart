// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_event.dart';

/// The resources mode's own toolbar action: the search toggle, shown selected while the field is
/// open. Never withheld while a project version is being previewed read-only — search only reads,
/// it never writes to the project.
class OcptResourcesSearchToggle extends StatelessWidget {
  /// Whether the search field is open.
  final bool isSearchVisible;

  /// Class constructor
  const OcptResourcesSearchToggle({super.key, required this.isSearchVisible});

  @override
  Widget build(BuildContext context) => IconButton(
    icon: const Icon(Icons.search, size: 20),
    tooltip: Tr.of(context).resourcesToggleSearchTooltip,
    isSelected: isSearchVisible,
    onPressed: () => context.read<OcptResourcesBloc>().add(const OcptResourcesSearchToggledEvent()),
  );
}
