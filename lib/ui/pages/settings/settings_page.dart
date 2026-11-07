// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/settings/settings_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/settings/settings_view.dart';

/// Display the application settings: appearance (brightness), language, calendar, and an about
/// section.
class OcptSettingsPage extends StatelessWidget {
  /// Create the settings page.
  const OcptSettingsPage({super.key});

  /// Build the settings page as a [BlocProvider].
  @override
  Widget build(BuildContext context) =>
      BlocProvider(create: (context) => OcptSettingsBloc(), child: const OcptSettingsView());
}
