// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <benoit.rolandeau@allcircuits.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';

/// Displays the editor as a temporary landing page.
///
/// This is a placeholder page; it will be replaced by the real editor content once the feature is
/// implemented. In the meantime, it shows the name of the project currently open (via
/// [OcptProjectsManager]) instead of a static title, so it's obvious which project is being
/// edited. The `OcptRouterManager` editor guard normally guarantees a project is always open when
/// this page is reached; the static title is only a fallback for that edge case (e.g. this widget
/// pumped directly in a test).
class EditorPage extends StatelessWidget {
  /// Creates the editor page.
  const EditorPage({super.key});

  @override
  Widget build(BuildContext context) {
    final currentProjectName = globalGetIt().get<OcptProjectsManager>().currentProject?.name;

    return Scaffold(body: Center(child: Text(currentProjectName ?? Tr.of(context).editorPageTitle)));
  }
}
