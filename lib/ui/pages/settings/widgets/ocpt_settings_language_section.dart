// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';

/// The settings page's "Language" section card: a single language dropdown (System / one entry
/// per [Tr.delegate]'s supported locale).
class OcptSettingsLanguageSection extends StatelessWidget {
  /// The locale wanted by the user, null meaning "follow the system".
  final Locale? wantedLocale;

  /// Called when the user picks a different language option.
  final ValueChanged<Locale?> onLocaleChanged;

  /// Class constructor
  const OcptSettingsLanguageSection({
    required this.wantedLocale,
    required this.onLocaleChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr.settingsLanguageSectionTitle, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: Text(tr.settingsLanguageLabel)),
                DropdownButton<Locale?>(
                  value: wantedLocale,
                  onChanged: onLocaleChanged,
                  mouseCursor: ocptClickableCursor,
                  items: [
                    DropdownMenuItem(child: Text(tr.settingsLanguageSystemOption)),
                    for (final locale in Tr.delegate.supportedLocales)
                      DropdownMenuItem(value: locale, child: Text(_localeOwnLanguageLabel(locale))),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Labels [locale] in its own language, the usual convention for a language picker: unlike every
  /// other string on this page, a language's own name doesn't go through [Tr], since it must not
  /// change when the app's current locale changes.
  static String _localeOwnLanguageLabel(Locale locale) => switch (locale.languageCode) {
    "fr" => "Français",
    "en" => "English",
    _ => locale.languageCode,
  };
}
