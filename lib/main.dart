// SPDX-FileCopyrightText: 2024 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/managers/global_manager.dart';
import 'package:open_cine_prod_tools/ui/main_app/main_app.dart';

/// The main entry point for the application.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await GlobalManager.instance.initLifeCycle();

  runApp(const MainApp());
}
