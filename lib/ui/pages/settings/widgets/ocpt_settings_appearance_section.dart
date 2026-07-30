// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/types/ocpt_app_theme.dart';

/// The settings page's "Appearance" section card: a single brightness dropdown (System / Light /
/// Dark).
///
/// The application has a single theme ([OcptAppTheme.standard]), so there is no theme picker: only
/// the brightness preference is exposed here.
class OcptSettingsAppearanceSection extends StatelessWidget {
  /// The current brightness preference, null meaning "follow the system".
  final Brightness? brightness;

  /// Called when the user picks a different brightness option.
  final ValueChanged<Brightness?> onBrightnessChanged;

  /// Class constructor
  const OcptSettingsAppearanceSection({
    required this.brightness,
    required this.onBrightnessChanged,
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
            Text(tr.settingsAppearanceSectionTitle, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: Text(tr.settingsThemeLabel)),
                DropdownButton<Brightness?>(
                  value: brightness,
                  onChanged: onBrightnessChanged,
                  mouseCursor: ocptClickableCursor,
                  items: [
                    DropdownMenuItem(child: Text(tr.settingsThemeSystemOption)),
                    DropdownMenuItem(
                      value: Brightness.light,
                      child: Text(tr.settingsThemeLightOption),
                    ),
                    DropdownMenuItem(value: Brightness.dark, child: Text(tr.settingsThemeDarkOption)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
