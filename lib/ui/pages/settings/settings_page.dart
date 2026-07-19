// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:act_intl_ui/act_intl_ui.dart';
import 'package:act_themes_manager/act_themes_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/ui/pages/settings/settings_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/settings/settings_state.dart';
import 'package:open_cine_prod_tools/ui/pages/settings/widgets/ocpt_settings_about_section.dart';
import 'package:open_cine_prod_tools/ui/pages/settings/widgets/ocpt_settings_appearance_section.dart';
import 'package:open_cine_prod_tools/ui/pages/settings/widgets/ocpt_settings_language_section.dart';

/// The maximum width of the settings page's content, keeping the section cards readable on a
/// wide desktop window.
const _maxContentWidth = 720.0;

/// Displays the application settings: appearance (brightness), language, and an about section.
class SettingsPage extends StatelessWidget {
  /// Creates the settings page.
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) =>
      BlocProvider(create: (context) => OcptSettingsBloc(), child: const OcptSettingsView());
}

/// The content of [SettingsPage], separated from it so [SettingsPage] only wires the
/// [OcptSettingsBloc] up (RFL3).
///
/// Unlike sibling pages' private `_XxxView`, this one is public: it lets widget tests pump it
/// directly with a `BlocProvider.value` wrapping an [OcptSettingsBloc] built with an injected
/// version, instead of going through [SettingsPage] (whose default `OcptSettingsBloc()` would
/// otherwise resolve the real, unmocked `PackageInfo.fromPlatform()`).
class OcptSettingsView extends StatelessWidget {
  /// Class constructor
  const OcptSettingsView({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: BackButton(onPressed: () => globalGetIt().get<OcptRouterManager>().pop()),
      title: Text(Tr.of(context).settingsPageTitle),
    ),
    body: BlocBuilder<OcptSettingsBloc, OcptSettingsState>(
      builder: (context, state) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxContentWidth),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OcptSettingsAppearanceSection(
                  brightness: state.brightness,
                  onBrightnessChanged: (brightness) => _onBrightnessChanged(context, brightness),
                ),
                const SizedBox(height: 16),
                OcptSettingsLanguageSection(
                  wantedLocale: state.wantedLocale,
                  onLocaleChanged: (locale) => _onLocaleChanged(context, locale),
                ),
                const SizedBox(height: 16),
                OcptSettingsAboutSection(appVersion: state.appVersion),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  /// Dispatches the event that updates the app-wide brightness preference.
  void _onBrightnessChanged(BuildContext context, Brightness? brightness) {
    context.read<OcptSettingsBloc>().add(AskToUpdateBrightnessEvent(newBrightness: brightness));
  }

  /// Dispatches the event that updates the app-wide wanted locale.
  void _onLocaleChanged(BuildContext context, Locale? locale) {
    context.read<OcptSettingsBloc>().add(NewLocaleWantedByUserEvent(wantedLocale: locale));
  }
}
