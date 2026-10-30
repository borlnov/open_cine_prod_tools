// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_foundation/act_foundation.dart';
import 'package:act_life_cycle/act_life_cycle.dart';
import 'package:flutter/foundation.dart' show protected;

/// The base of every `Ocpt…Service`.
///
/// A service is the unit of domain logic a manager is split into: it reads and writes one area of a
/// project (a database passed to each call), or builds one kind of document or file, and holds no
/// UI and no registration in `globalGetIt()` — the manager that owns it builds it and exposes it as
/// a field. It is not a manager: it is never registered, and its life cycle is driven by whoever
/// builds it, not by the global manager.
///
/// The life cycle is the one of [AbsWithLifeCycle]: its owner calls [initLifeCycle] when the owner
/// is itself initialised and [disposeLifeCycle] when it is disposed, in reverse order of building.
/// A service that builds services of its own owns them and drives theirs the same way. Both are
/// no-ops here and the constructor is `const`, so a service holding nothing to set up or release
/// stays `const` and needs neither call.
///
/// A service logs through the [logger] its owner hands it: a sub-logger of the owner's own, so the
/// category of a line reads `owner / service`. The owner builds it; a service never builds a
/// top-level logger of its own. It is typed by the interface rather than by the concrete helper so
/// a test can hand in a silent or a recording double.
abstract class AbsOcptService extends AbsWithLifeCycle {
  /// Class constructor
  const AbsOcptService({required this.logger});

  /// The logger this service writes to: a sub-logger built by its owner.
  @protected
  final MixinActLogger logger;
}
