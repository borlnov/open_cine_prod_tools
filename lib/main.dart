// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/ui/main_app/main_app_ui.dart';

/// Starts the application by running it on top of the global manager.
Future<void> main() async => OcptGlobalManager.instance.runActApp(const MainAppUi());
