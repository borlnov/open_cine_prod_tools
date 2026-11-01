// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/workspace_bloc.dart';

/// The navigator [wrapWithLocalization] mounts, so [RecordingRouterManager.pop] can close a
/// dialog opened through `showDialog` (the export panel, the scenario coverage options dialog)
/// exactly as the real `GoRouter.pop` would — both push onto the very same root `Navigator`. See
/// `test/ui/pages/editor/editor_page_test.dart`'s own instance of the same pattern.
final navigatorKey = GlobalKey<NavigatorState>();

/// A router manager whose [pop] records every call and then pops [navigatorKey]'s own navigator,
/// so a dialog opened through `showDialog` genuinely closes: this mode's own bloc resolves its
/// router manager from `globalGetIt()`, with no real GoRouter for `pop` to delegate to.
class RecordingRouterManager extends OcptRouterManager {
  @override
  void pop<Y extends Object?>([Y? result]) {
    final navigator = navigatorKey.currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.pop(result);
    }
  }
}

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve in tests,
/// [navigatorKey] so [RecordingRouterManager.pop] can close a dialog opened through
/// `showDialog`, a bare [Scaffold]: unlike `OcptEditorPage`, a production mode expects the real
/// `OcptWorkspacePage` to provide one, and an `OcptWorkspaceBloc` ancestor — `OcptWorkspacePage`
/// always provides one too, and this mode now reads it for the toolbar episode selector's
/// episodes/selection.
Widget wrapWithLocalization(Widget child) => MaterialApp(
  navigatorKey: navigatorKey,
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: BlocProvider<OcptWorkspaceBloc>(
    create: (context) => OcptWorkspaceBloc(),
    child: Scaffold(body: child),
  ),
);
