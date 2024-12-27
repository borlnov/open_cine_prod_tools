// SPDX-FileCopyrightText: 2024 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: MIT

import 'package:bro_global_manager/bro_global_manager.dart';

/// This is the global manager of the application.
class GlobalManager extends AbsGlobalManager {
  /// The singleton instance of the global manager.
  static GlobalManager get instance {
    if (AbsGlobalManager.absInstance == null) {
      AbsGlobalManager.setInstance(GlobalManager._());
    }

    return AbsGlobalManager.getCastedInstance();
  }

  /// Private constructor.
  GlobalManager._() : super();

  /// {@macro AbsWithLifeCycle.initLifeCycle}
  @override
  Future<void> initLifeCycle() async {
    await super.initLifeCycle();
  }
}
