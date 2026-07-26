// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_page.dart';

/// The workspace page, hosting whichever production mode is active.
///
/// The `OcptRouterManager` workspace guard guarantees a project is open when this page is
/// reached. For now the screenplay editor is the only mode: the bottom mode switcher and the
/// other production modes land in a later change.
class WorkspacePage extends StatelessWidget {
  /// Creates the workspace page.
  const WorkspacePage({super.key});

  @override
  Widget build(BuildContext context) => const EditorPage();
}
