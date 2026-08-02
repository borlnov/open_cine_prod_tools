// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/services.dart' show rootBundle;
import 'package:fountain_kit/fountain_kit.dart';
import 'package:pdf/widgets.dart' as pw;

/// The directory of the asset bundle the 4 Courier Prime TTFs are read from.
const String _fontsAssetDirectory = "assets/fonts/courier_prime";

/// The 4 Courier Prime `pw.Font` variants loaded from the asset bundle, bundled together so a PDF
/// renderer only has to pass around one object instead of 4 separate futures.
///
/// Every PDF this app exports typesets its screenplay in Courier Prime, so this set is shared by
/// every renderer rather than embedded by each of them: two exports of the same screenplay must
/// print it with the very same glyphs. [OcptCourierPrimeFontsLoader] is what actually reads them.
class OcptCourierPrimeFonts {
  /// Creates an [OcptCourierPrimeFonts].
  const OcptCourierPrimeFonts({
    required this.regular,
    required this.bold,
    required this.italic,
    required this.boldItalic,
  });

  /// The regular (upright, non-bold) variant.
  final pw.Font regular;

  /// The bold variant.
  final pw.Font bold;

  /// The italic variant.
  final pw.Font italic;

  /// The bold-italic variant.
  final pw.Font boldItalic;

  /// Reads the 4 Courier Prime TTFs from the asset bundle and decodes each into a `pw.Font`.
  ///
  /// The `flutter: fonts:` block in `pubspec.yaml` makes these usable as an on-screen `TextStyle`
  /// family, but does not put their raw bytes within reach of `rootBundle.load`; that requires the
  /// same paths to also be listed under `flutter: assets:`, which they are.
  ///
  /// Go through [OcptCourierPrimeFontsLoader.load] rather than calling this directly: decoding a
  /// TTF is not free, and nothing about the result ever changes between two calls.
  static Future<OcptCourierPrimeFonts> load() async {
    Future<pw.Font> loadVariant(String fileName) async {
      final data = await rootBundle.load("$_fontsAssetDirectory/$fileName");
      return pw.Font.ttf(data);
    }

    final variants = await Future.wait([
      loadVariant("CourierPrime-Regular.ttf"),
      loadVariant("CourierPrime-Bold.ttf"),
      loadVariant("CourierPrime-Italic.ttf"),
      loadVariant("CourierPrime-BoldItalic.ttf"),
    ]);

    return OcptCourierPrimeFonts(
      regular: variants[0],
      bold: variants[1],
      italic: variants[2],
      boldItalic: variants[3],
    );
  }

  /// The font variant matching [bold]/[italic], mirroring how a [FountainStyledRun]'s own flags
  /// combine.
  pw.Font variant({required bool bold, required bool italic}) {
    if (bold && italic) {
      return boldItalic;
    }
    if (bold) {
      return this.bold;
    }
    if (italic) {
      return this.italic;
    }
    return regular;
  }
}

/// The one place [OcptCourierPrimeFonts] is read from the asset bundle, memoizing the load so
/// repeated exports within the same app session never decode the same 4 TTFs twice.
///
/// `OcptExportManager` builds a single loader and hands it to every renderer it owns, so the two
/// PDF exports share one cache instead of holding one each. A renderer built without one (a test,
/// typically) simply gets a loader of its own.
class OcptCourierPrimeFontsLoader {
  /// Class constructor
  OcptCourierPrimeFontsLoader();

  /// The memoized loading future, populated on first use.
  ///
  /// A `Future` rather than the resolved fonts themselves, so two exports racing before the first
  /// load finishes both await the same load instead of triggering it twice.
  Future<OcptCourierPrimeFonts>? _future;

  /// Loads (once) and returns the embedded Courier Prime font set.
  Future<OcptCourierPrimeFonts> load() => _future ??= OcptCourierPrimeFonts.load();
}
