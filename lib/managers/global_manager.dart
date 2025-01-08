// SPDX-FileCopyrightText: 2024 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: MIT

import 'package:bro_global_manager/bro_global_manager.dart';
import 'package:open_cine_prod_tools/managers/config_manager.dart';
import 'package:open_cine_prod_tools/managers/firebase/firebase_manager.dart';
import 'package:open_cine_prod_tools/managers/multi_logger_manager.dart';

/// This is the global manager of the application.
class GlobalManager extends AbsGlobalManager {
  /// The singleton instance of the global manager.
  static GlobalManager get instance => AbsGlobalManager.getCastedInstance(GlobalManager._);

  /// Private constructor.
  GlobalManager._() : super();

  /// {@macro bro_global_manager.AbsGlobalManager.registerManagers}
  @override
  void registerManagers(
    void Function<M extends AbsWithLifeCycle, B extends AbsManagerBuilder<M>>(B builder)
        registerManager,
  ) {
    registerManager<ConfigManager, ConfigManagerBuilder>(const ConfigManagerBuilder());
    registerManager<MultiLoggerManager, MultiLoggerBuilder>(const MultiLoggerBuilder());
    registerManager<FirebaseManager, FirebaseManagerBuilder>(const FirebaseManagerBuilder());
  }
}
