// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import "package:equatable/equatable.dart";

/// The shape of an app version, as `git describe` and a stable release tag both produce it:
/// `MAJOR.MINOR.PATCH`, an optional `-<pre-release>` segment, an optional `+<build-metadata>`
/// segment. Build metadata is parsed only to be discarded — ADR 0029 draws the stable/pre-release
/// line on the pre-release segment alone.
///
/// A stable tag build (`v0.2.1`) parses with no pre-release segment; every other build CI produces
/// carries one, either a real pre-release label (`0.2.0-alpha.3`, `0.2.0-rc.2`) or `git describe`'s
/// own between-tags form (`0.2.0-3-g87a9b8d`, read as core `0.2.0` and pre-release `3-g87a9b8d`).
/// Both are pre-release: the schema promise in ADR 0029 is owed to a stable tag alone.
class OcptAppVersion extends Equatable {
  /// The `MAJOR.MINOR.PATCH` core this version was built from.
  final int major;

  /// The `MAJOR.MINOR.PATCH` core this version was built from.
  final int minor;

  /// The `MAJOR.MINOR.PATCH` core this version was built from.
  final int patch;

  /// The text after the first `-` and before any `+`, or null when the parsed string carried none
  /// — a stable release tag is exactly the case where this is null.
  final String? preRelease;

  /// Class constructor.
  const OcptAppVersion({
    required this.major,
    required this.minor,
    required this.patch,
    required this.preRelease,
  });

  /// Parses [raw] leniently, never throwing.
  ///
  /// A leading `v`/`V` is stripped first (CI already strips it from the tag it stamps a build
  /// with, but a defensive strip costs nothing here). Anything after the first `+` is build
  /// metadata and is dropped entirely. What remains splits on its **first** `-` into the
  /// `MAJOR.MINOR.PATCH` core and the pre-release text, so `git describe`'s own
  /// `0.2.0-3-g87a9b8d` reads as core `0.2.0`, pre-release `3-g87a9b8d`.
  ///
  /// A string this cannot make sense of — empty, missing a numeric core, a non-numeric component —
  /// is **never trusted as stable**: it parses to `0.0.0` with a non-null [preRelease] carrying
  /// [raw] itself, so [isPreRelease] reads true. An unknown build is treated the same way ADR 0029
  /// treats every build that is not a recognised stable tag: safest as a pre-release, never as one
  /// that owes the schema promise a stable release owes.
  factory OcptAppVersion.parse(String raw) {
    final trimmed = raw.trim();
    final unprefixed = trimmed.startsWith("v") || trimmed.startsWith("V")
        ? trimmed.substring(1)
        : trimmed;

    final withoutMetadata = unprefixed.split("+").first;

    final dashIndex = withoutMetadata.indexOf("-");
    final core = dashIndex == -1 ? withoutMetadata : withoutMetadata.substring(0, dashIndex);
    final preRelease = dashIndex == -1 ? null : withoutMetadata.substring(dashIndex + 1);

    final coreParts = core.split(".");
    if (coreParts.length != 3) {
      return OcptAppVersion(major: 0, minor: 0, patch: 0, preRelease: raw);
    }

    final major = int.tryParse(coreParts[0]);
    final minor = int.tryParse(coreParts[1]);
    final patch = int.tryParse(coreParts[2]);
    if (major == null || minor == null || patch == null) {
      return OcptAppVersion(major: 0, minor: 0, patch: 0, preRelease: raw);
    }

    return OcptAppVersion(major: major, minor: minor, patch: patch, preRelease: preRelease);
  }

  /// True iff a pre-release segment is present — everything but a stable release tag.
  bool get isPreRelease => preRelease != null;

  /// The `MAJOR.MINOR.PATCH` core, normalized back to a string.
  String get stableLine => "$major.$minor.$patch";

  /// True iff [other] shares this version's [stableLine], regardless of either one's pre-release
  /// segment.
  bool isSameStableLineAs(OcptAppVersion other) => stableLine == other.stableLine;

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "OcptAppVersion($stableLine${preRelease == null ? "" : "-$preRelease"})";

  /// Object properties.
  @override
  List<Object?> get props => [major, minor, patch, preRelease];
}
