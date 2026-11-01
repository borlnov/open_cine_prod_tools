// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/managers/export/services/ocpt_courier_prime_fonts.dart';

/// The one place [OcptCourierPrimeFonts] is read from the asset bundle, memoizing the load so
/// repeated exports within the same app session never decode the same 4 TTFs twice.
///
/// `OcptExportManager` builds a single loader and hands it to every renderer it owns, so the two
/// PDF exports share one cache instead of holding one each. A renderer built without one (a test,
/// typically) simply gets a loader of its own.
class OcptCourierPrimeFontsLoader {
  /// The memoized loading future, populated on first use.
  ///
  /// A `Future` rather than the resolved fonts themselves, so two exports racing before the first
  /// load finishes both await the same load instead of triggering it twice.
  Future<OcptCourierPrimeFonts>? _future;

  /// Class constructor
  OcptCourierPrimeFontsLoader();

  /// Loads (once) and returns the embedded Courier Prime font set.
  Future<OcptCourierPrimeFonts> load() => _future ??= OcptCourierPrimeFonts.load();
}
