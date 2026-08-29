// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import "package:flutter_test/flutter_test.dart";
import "package:open_cine_prod_tools/utils/ocpt_app_version.dart";

void main() {
  group("OcptAppVersion.parse", () {
    test("a bare MAJOR.MINOR.PATCH tag is stable", () {
      for (final raw in ["0.1.0", "0.2.1", "1.0.0"]) {
        final version = OcptAppVersion.parse(raw);

        expect(version.isPreRelease, isFalse, reason: raw);
        expect(version.stableLine, raw, reason: raw);
      }
    });

    test("a labelled pre-release suffix is a pre-release", () {
      for (final raw in ["0.2.0-alpha.3", "0.2.0-beta", "0.2.0-rc.2"]) {
        final version = OcptAppVersion.parse(raw);

        expect(version.isPreRelease, isTrue, reason: raw);
        expect(version.stableLine, "0.2.0", reason: raw);
      }
    });

    test("git describe's between-tags form is a pre-release", () {
      final version = OcptAppVersion.parse("0.2.0-3-g87a9b8d");

      expect(version.isPreRelease, isTrue);
      expect(version.stableLine, "0.2.0");
      expect(version.preRelease, "3-g87a9b8d");
    });

    test("build metadata after + is stripped entirely", () {
      final version = OcptAppVersion.parse("0.1.0-1-gabc123+build.5");

      expect(version.isPreRelease, isTrue);
      expect(version.stableLine, "0.1.0");
      expect(version.preRelease, "1-gabc123");
    });

    test("a stable tag with build metadata drops it and stays stable", () {
      final version = OcptAppVersion.parse("0.1.0+build.5");

      expect(version.isPreRelease, isFalse);
      expect(version.stableLine, "0.1.0");
    });

    test("a leading v or V is stripped before parsing", () {
      expect(OcptAppVersion.parse("v0.1.0"), OcptAppVersion.parse("0.1.0"));
      expect(OcptAppVersion.parse("V0.1.0"), OcptAppVersion.parse("0.1.0"));
    });

    test("an empty or unparseable string falls back to a pre-release 0.0.0", () {
      for (final raw in ["", "garbage", "1.2", "a.b.c"]) {
        final version = OcptAppVersion.parse(raw);

        expect(version.isPreRelease, isTrue, reason: raw);
        expect(version.stableLine, "0.0.0", reason: raw);
      }
    });
  });

  group("OcptAppVersion.isSameStableLineAs", () {
    test("true when the MAJOR.MINOR.PATCH core matches, pre-release or not", () {
      final stable = OcptAppVersion.parse("0.2.0");
      final preRelease = OcptAppVersion.parse("0.2.0-3-g87a9b8d");

      expect(stable.isSameStableLineAs(preRelease), isTrue);
      expect(preRelease.isSameStableLineAs(stable), isTrue);
    });

    test("false when the core differs", () {
      final a = OcptAppVersion.parse("0.2.0");
      final b = OcptAppVersion.parse("0.2.1");

      expect(a.isSameStableLineAs(b), isFalse);
    });
  });

  group("value equality", () {
    test("two versions parsed from the same string are equal", () {
      expect(OcptAppVersion.parse("0.2.0-alpha.3"), OcptAppVersion.parse("0.2.0-alpha.3"));
    });

    test("a differing pre-release makes two versions unequal", () {
      expect(OcptAppVersion.parse("0.2.0-alpha.3"), isNot(OcptAppVersion.parse("0.2.0-alpha.4")));
    });
  });
}
