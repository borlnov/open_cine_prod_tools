// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async' show unawaited;

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:act_global_manager/act_global_manager.dart';
import 'package:act_intl/act_intl.dart';
import 'package:act_platform_manager/act_platform_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_config_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/ui/main_app/main_app_bloc.dart';
import 'package:open_cine_prod_tools/ui/main_app/main_app_state.dart';
import 'package:open_cine_prod_tools/utils/ocpt_responsive.dart';

/// The extra factor the mobile UI is scaled up by, on top of `flutter_screenutil`'s own
/// design-size scaling.
///
/// On a phone the screenutil-scaled sizes still read a touch small, so the mobile theme grows its
/// font sizes (the text theme's `sp`) and its widget dimensions (paddings, icon sizes, field
/// metrics — the theme's `w`) by this factor. Corner radii (`r`) are left alone, as are the fixed
/// `ocpt*` chrome constants (the top toolbar height, the bottom mode-switcher band and their
/// buttons) which never pass through a scaler — so the toolbar and the mode switcher keep the size
/// they already have while the content around them grows. A starting value, tuned against the real
/// device.
const double _ocptMobileUiScale = 1.2;

/// Builds the root [MaterialApp] shell of the application.
///
/// The app locale and theme both follow the preferences persisted through
/// [OcptGlobalManager]'s managers: [LocalesObserverWidget] and [OcptMainAppBloc] keep the wanted
/// locale, theme and brightness of the [MaterialApp.router] in sync with the local storage, so
/// they can later be changed live from the settings page.
///
/// The whole tree is wrapped in [ScreenUtilInit], which initialises `flutter_screenutil` before
/// calling its `builder` — so `.sp`/`.w`/`.r` are valid by the time the [BlocBuilder] below reads
/// them. On a **phone** (mobile, and a shortest side below [ocptPhoneWidthBreakpoint]) the theme is
/// rebuilt with those scalers ([buildOcptThemeModel]); on a tablet and on desktop it is not — a
/// tablet has desktop-class room, especially in landscape, so magnifying every size by the phone
/// design-size ratio would blow the type and the controls up out of proportion. There the app keeps
/// the bloc state's own theme model (the global [ocptTheme]) unchanged and `.sp`/`.w`/`.r` are never
/// called. Phones and tablets are told apart by the rotation-invariant shortest side, the same 600dp
/// line the orientation policy and Android's `sw600dp` qualifier draw.
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
              // The screenutil-based scaling is a phone concern: only there is the room tight enough
              // to want the whole UI grown by the phone design-size ratio. A tablet has desktop-class
              // room, so it keeps the unscaled desktop theme and reads like the desktop build rather
              // than magnifying every size. The two are told apart by the rotation-invariant shortest
              // side — [ScreenUtil] is already initialised here, so its screen dimensions are the
              // measure to hand.
              final screenUtil = ScreenUtil();
              final shortestSide = screenUtil.screenWidth < screenUtil.screenHeight
                  ? screenUtil.screenWidth
                  : screenUtil.screenHeight;
              final isPhone = platform.isMobile && shortestSide < ocptPhoneWidthBreakpoint;
              final themeModel = isPhone
                  ? buildOcptThemeModel(
                      sp: (v) => (v * _ocptMobileUiScale).sp,
                      w: (v) => (v * _ocptMobileUiScale).w,
                      r: (v) => v.r,
                    )
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

                  return _EdgeToEdgeShell(child: child ?? const SizedBox.shrink());
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Wraps every route the [MaterialApp.router] builds so no screen ever hides behind the platform's
/// system bars, while still letting the app paint edge to edge under them.
///
/// Android 15 (`targetSdk` 35) draws apps edge to edge: the status bar and the navigation bar
/// overlay the content instead of insetting it, so a screen that does not account for them slips
/// underneath. Rather than repeat a `SafeArea` in every page and every future one, this single shell
/// does three things once, for the whole app:
///
/// - it makes both system bars transparent and picks their icon brightness from the active theme,
///   through an [AnnotatedRegion] that re-evaluates whenever the theme flips, so the bars read as a
///   seamless extension of the app in light and in dark;
/// - it paints [ThemeData.scaffoldBackgroundColor] across the entire window — behind the bars
///   included, since the [ColoredBox] sits *outside* the [SafeArea] — so the strips under the bars
///   carry the app's own surface colour rather than a bare window background;
/// - it insets [child] with a [SafeArea] so the routed content clears the bars.
///
/// On desktop there are no system insets, so the [SafeArea] adds no padding and the
/// [AnnotatedRegion] is inert: the shell is a no-op there and changes nothing.
///
/// It is also where the app's device-orientation policy is applied, for the same reason it is the
/// one wrapper every route passes through: see [_EdgeToEdgeShellState._lockOrientationForDeviceClass].
class _EdgeToEdgeShell extends StatefulWidget {
  /// The routed content to inset — the [MaterialApp.router]'s own `child`.
  final Widget child;

  /// Class constructor
  const _EdgeToEdgeShell({required this.child});

  @override
  State<_EdgeToEdgeShell> createState() => _EdgeToEdgeShellState();
}

/// State of [_EdgeToEdgeShell]: applies the orientation policy once its [MediaQuery] is available.
class _EdgeToEdgeShellState extends State<_EdgeToEdgeShell> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _lockOrientationForDeviceClass();
  }

  /// On a mobile build, pins a phone to portrait and leaves a tablet free to rotate.
  ///
  /// A phone has too little room to lay a production mode out in landscape, so it is kept upright; a
  /// tablet has the space, so every orientation stays available. The two are told apart by the
  /// screen's shortest side — the one measure that does not itself change when the device rotates —
  /// against [ocptPhoneWidthBreakpoint], the same 600dp line Android's own `sw600dp` tablet
  /// qualifier draws. A desktop build reaches none of this: it has no device orientation to
  /// constrain, and [PlatformManager.isMobile] gates the whole thing out there.
  void _lockOrientationForDeviceClass() {
    if (!globalGetIt().get<PlatformManager>().isMobile) {
      return;
    }

    final isPhone = MediaQuery.sizeOf(context).shortestSide < ocptPhoneWidthBreakpoint;
    unawaited(
      SystemChrome.setPreferredOrientations(
        isPhone
            ? const [DeviceOrientation.portraitUp]
            : const [
                DeviceOrientation.portraitUp,
                DeviceOrientation.portraitDown,
                DeviceOrientation.landscapeLeft,
                DeviceOrientation.landscapeRight,
              ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final barIconBrightness = isDark ? Brightness.light : Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: barIconBrightness,
        // iOS reads the status bar text brightness from the opposite field.
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: barIconBrightness,
        // Keep Android from laying its own translucent scrim over the transparent nav bar, so the
        // surface colour below shows through unaltered.
        systemNavigationBarContrastEnforced: false,
      ),
      child: ColoredBox(
        color: theme.scaffoldBackgroundColor,
        // A corner banner naming the environment (blue "QUALIF", red "DEV") over every screen's top
        // toolbar — withheld entirely for a release build in `Environment.production`, so a stable
        // release shows nothing. `EnvBanner` reads `OcptConfigManager`'s own env and is consumed
        // unchanged (ACT's default colours), the single insertion point being this one wrapper every
        // route passes through.
        child: SafeArea(
          child: EnvBanner.displayAppBarBanner<OcptConfigManager>(child: widget.child),
        ),
      ),
    );
  }
}
