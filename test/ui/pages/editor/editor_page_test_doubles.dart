// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/workspace_bloc.dart';

/// The sample script every test loads: two scenes (the first heading deliberately lowercase, to
/// check the preview renders headings uppercase), one dialogue block and some action text.
const sampleText = """
int. kitchen - day

SARAH
(to herself)
Smells like Sunday.

EXT. GARDEN - NIGHT

Something moves in the dark.
""";

/// The navigator [wrapWithLocalization] mounts, so [RecordingRouterManager.pop] can close a
/// dialog opened through `showDialog` (the export panel, the PDF options dialog) exactly as the
/// real `GoRouter.pop` would — both push onto the very same root `Navigator`.
final navigatorKey = GlobalKey<NavigatorState>();

/// A router manager whose [pop] records every call and then pops [navigatorKey]'s own navigator,
/// so a dialog opened through `showDialog` genuinely closes: these page tests pump the editor page
/// directly, without a real GoRouter for `pop` to delegate to.
class RecordingRouterManager extends OcptRouterManager {
  /// Whether [pop] was called.
  bool popped = false;

  /// The value [pop] was last called with.
  Object? poppedValue;

  /// Records the call, then pops the navigator's own topmost route (the dialog it was called
  /// from) instead of delegating to the (never initialized) GoRouter.
  @override
  void pop<Y extends Object?>([Y? result]) {
    popped = true;
    poppedValue = result;
    final navigator = navigatorKey.currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.pop(result);
    }
  }
}

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve in tests,
/// [ocptTheme]'s light theme so widgets reading its `OcptSpecificColors` extension (the raw-mode
/// preview's backdrop) resolve one, just like the real app always does, and [navigatorKey] so
/// [RecordingRouterManager.pop] can close a dialog opened through `showDialog`.
Widget wrapWithLocalization(Widget child) => MaterialApp(
  navigatorKey: navigatorKey,
  theme: ocptTheme.lightThemeData,
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  // The real OcptWorkspacePage always provides this ancestor: OcptEditorPage now reads it for the
  // episode selector's episodes/selection, exactly as it already reads OcptEditorBloc.
  home: BlocProvider<OcptWorkspaceBloc>(create: (context) => OcptWorkspaceBloc(), child: child),
);

/// The miniature hunspell pair every test in this file spell-checks against, standing in for the
/// two ~1 MB dictionaries the real app bundles.
///
/// `OcptEditorPage` builds its own `OcptEditorBloc` with no test seam, so that bloc resolves the
/// real `OcptSpellCheckManager` from `globalGetIt()` and asks it to load whichever language the
/// project fixture was created with — which, against the real assets, would mean parsing a megabyte
/// of dictionary in an isolate before any of these tests could get on with what they are actually
/// about. The manager's own `loadAsset` seam takes this instead: the file names it asks for are
/// ignored, the words below are all it ever knows, and nothing in this file asserts on a
/// misspelling anyway.
Future<String> loadMiniatureDictionaryAsset(String assetKey) async =>
    assetKey.endsWith(".aff") ? "SET UTF-8\n" : "2\nthe\nscene\n";
