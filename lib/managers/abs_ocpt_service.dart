// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_life_cycle/act_life_cycle.dart';

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
abstract class AbsOcptService extends AbsWithLifeCycle {
  /// Class constructor
  const AbsOcptService();
}
