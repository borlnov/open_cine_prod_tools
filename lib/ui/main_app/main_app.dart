// SPDX-FileCopyrightText: 2024 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: MIT

import 'dart:async';

import 'package:bro_global_manager/bro_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/managers/global_manager.dart';
import 'package:open_cine_prod_tools/ui/home/home_page.dart';

/// This is the main application widget.
class MainApp extends StatelessWidget {
  /// Constructs the [MainApp] widget.
  const MainApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Flutter Demo',
        theme: ThemeData(
          // This is the theme of your application.
          //
          // TRY THIS: Try running your application with "flutter run". You'll see
          // the application has a purple toolbar. Then, without quitting the app,
          // try changing the seedColor in the colorScheme below to Colors.green
          // and then invoke "hot reload" (save your changes or press the "hot
          // reload" button in a Flutter-supported IDE, or press "r" if you used
          // the command line to start the app).
          //
          // Notice that the counter didn't reset back to zero; the application
          // state is not lost during the reload. To reset the state, use hot
          // restart instead.
          //
          // This works for code too, not just values: Most code changes can be
          // tested with just a hot reload.
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.indigo,
            brightness: Brightness.dark,
          ),

          useMaterial3: true,
        ),
        home: const HomePage(title: 'Flutter Demo Home Page'),
        builder: (context, child) {
          if (child != null &&
              GlobalManager.instance.currentStatus == GlobalManagerStatus.created) {
            unawaited(GlobalManager.instance.initAfterViewBuilt(context));
          }

          return child ?? const SizedBox();
        },
      );
}
