// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <benoit.rolandeau@allcircuits.com>
//
// SPDX-License-Identifier: LicenseRef-ALLCircuits-ACT-1.1

import 'package:act_life_cycle/src/services/abs_with_life_cycle.dart';
import 'package:flutter/widgets.dart';

/// This mixin is used to add methods to services and managers linked to the UI life cycle
mixin MixinUiLifeCycle on AbsWithLifeCycle {
  /// {@template act_life_cycle.MixinUiLifeCycle.initAfterManagersAndBeforeViews}
  /// This method is called after all the managers are initialized but before the first view is
  /// built.
  ///
  /// This method can be called in the same time as the other managers
  /// [initAfterManagersAndBeforeViews] method, so it should not be used to call methods from other
  /// managers, but it can be used to initialize some variables or do some operations that need
  /// to be done before the first view is built.
  /// {@endtemplate}
  ///
  /// Call `super.initAfterManagersAndBeforeViews()` first in the derived class method (unless
  /// otherwise specified by a derived class)
  @mustCallSuper
  Future<void> initAfterManagersAndBeforeViews() async {}

  /// {@template act_life_cycle.MixinUiLifeCycle.initAfterView}
  /// Method called asynchronously after the view is initialized
  ///
  /// This [BuildContext] is above the Navigator (therefore it can't be used to access it)
  /// {@endtemplate}
  ///
  /// Call `super.initAfterView()` first in the derived class method (unless otherwise specified by
  /// a derived class)
  @mustCallSuper
  Future<void> initAfterView(BuildContext context) async {}
}
