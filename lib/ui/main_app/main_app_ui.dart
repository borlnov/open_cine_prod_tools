// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:act_intl/act_intl.dart';
import 'package:act_platform_manager/act_platform_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/ui/main_app/main_app_bloc.dart';
import 'package:open_cine_prod_tools/ui/main_app/main_app_state.dart';

/// Builds the root [MaterialApp] shell of the application.
///
/// The app locale and theme both follow the preferences persisted through
/// [OcptGlobalManager]'s managers: [LocalesObserverWidget] and [OcptMainAppBloc] keep the wanted
/// locale, theme and brightness of the [MaterialApp.router] in sync with the local storage, so
/// they can later be changed live from the settings page.
///
/// The whole tree is wrapped in [ScreenUtilInit], which initialises `flutter_screenutil` before
/// calling its `builder` — so `.sp`/`.w`/`.r` are valid by the time the [BlocBuilder] below reads
/// them. On [PlatformManager.isMobile], the theme is rebuilt with those scalers
/// ([buildOcptThemeModel]); on desktop `isMobile` is false, so the app keeps the bloc state's own
/// theme model (the global [ocptTheme]) unchanged and `.sp`/`.w`/`.r` are never called.
class MainAppUi extends StatelessWidget {
  /// Creates the main app widget.
  const MainAppUi({super.key});

  @override
  Widget build(BuildContext context) {
    final router = globalGetIt().get<OcptRouterManager>().router;

    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      builder: (context, _) => LocalesObserverWidget(
        child: BlocProvider(
          create: (context) => OcptMainAppBloc(),
          child: BlocBuilder<OcptMainAppBloc, OcptMainAppState>(
            builder: (context, state) {
              final platform = globalGetIt().get<PlatformManager>();
              final themeModel = platform.isMobile
                  ? buildOcptThemeModel(sp: (v) => v.sp, w: (v) => v.w, r: (v) => v.r)
                  : state.currentTheme.themeData;

              return MaterialApp.router(
                // The app title is the one displayed in the window title bar.
                onGenerateTitle: (context) => Tr.of(context).appTitle,
                routerConfig: router,
                theme: themeModel.lightThemeData,
                darkTheme: themeModel.darkThemeData,
                themeMode: state.themeMode,
                locale: state.wantedLocale,
                localizationsDelegates: const [
                  Tr.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                supportedLocales: Tr.delegate.supportedLocales,
                builder: (context, child) {
                  OcptGlobalManager.instance.initInFirstView(context);

                  return child ?? const SizedBox.shrink();
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
