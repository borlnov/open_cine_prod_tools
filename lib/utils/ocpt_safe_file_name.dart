// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The characters Windows refuses anywhere in a file or folder name, exactly as its own
/// `GetFullPathName` documentation lists them (`\ / : * ? " < > |`), plus every ASCII control
/// character (`\x00`-`\x1F`, and `\x7F`, `DEL`) — a name a text field happily stores but no
/// filesystem should be handed.
///
/// Linux only forbids `/`, and macOS only `/` and, at the Finder layer, `:` — but a package built
/// on one platform has to unpack cleanly on either of the other two
/// (`docs/adr/0021-the-portable-project-package.md`), so [ocptSafeFileNameOf] applies the
/// **strictest** of the three rules everywhere rather than the one the exporting machine happens to
/// enforce.
final RegExp _ocptForbiddenFileNameCharacters = RegExp(r'[\\/:*?"<>|\x00-\x1F\x7F]');

/// Runs of whitespace **or** of the placeholder [_ocptForbiddenFileNameCharacters] were just
/// replaced with, collapsed to one space: `Les Vagues : acte 2` loses its colon to a space, and
/// this is what stops it becoming `Les Vagues   acte 2`.
final RegExp _ocptRepeatedSeparators = RegExp(r'\s+');

/// A leading or trailing run of whitespace or dots — the pattern trimmed off both ends of the
/// result, once after collapsing separators and once more after capping the length.
///
/// Windows treats a trailing dot or space as if it weren't there at all (and silently strips it
/// when it creates the entry), and a **leading** dot is what Linux and macOS read as "hidden" — a
/// project called `...` or `. ` must not turn into an invisible folder nobody can find in a file
/// picker.
final RegExp _ocptLeadingOrTrailingClutter = RegExp(r'^[\s.]+|[\s.]+$');

/// The longest name [ocptSafeFileNameOf] ever returns.
///
/// Windows caps a full path at 260 characters unless long-path support is opted into, and a
/// project's folder is only the first segment of a deeper one (`<name>/assets/<assetId>/<file>`,
/// `docs/adr/0021-the-portable-project-package.md`) — 80 leaves comfortable room for everything that
/// gets appended under it without being so short that two differently-punctuated titles collapse
/// into the same stem more often than they already would.
const ocptSafeFileNameMaxLength = 80;

/// Turns [name] — a project's free-typed display name — into a name a filesystem accepts on
/// Linux, Windows and macOS alike, falling back to [fallback] when nothing usable is left.
///
/// Nothing here is filesystem-specific state, so this stays in `lib/utils/` rather than beside
/// whichever manager first needed it (`AGENTS.md`): a rule two layers read belongs where both can,
/// and both the export side (naming a package after its project) and the import side (naming the
/// folder unpacked from one) need exactly the same answer for the same name.
///
/// The steps, in order:
/// 1. every character [_ocptForbiddenFileNameCharacters] lists becomes a space, so a title read
///    as several words stays legible instead of running together (`Les Vagues : acte 2` becomes
///    `Les Vagues   acte 2`, not `Les Vagues  acte 2` glued at the colon);
/// 2. runs of whitespace collapse to one space ([_ocptRepeatedSeparators]);
/// 3. whitespace and dots are trimmed off both ends ([_ocptLeadingOrTrailingClutter]);
/// 4. the result is capped at [ocptSafeFileNameMaxLength] characters, and trimmed a second time —
///    a cut that lands mid-run of spaces or dots would otherwise leave one behind at the new end.
///
/// [fallback] is returned as-is, untouched, when every one of those steps leaves nothing behind
/// (an empty [name], or one made entirely of dots and whitespace like `...`): the caller names a
/// sensible default rather than this function inventing one, since only the caller knows what the
/// name was *for* (a project, say).
String ocptSafeFileNameOf(String name, {required String fallback}) {
  final withoutForbiddenCharacters = name.replaceAll(_ocptForbiddenFileNameCharacters, ' ');
  final withoutRepeatedSeparators = withoutForbiddenCharacters.replaceAll(
    _ocptRepeatedSeparators,
    ' ',
  );
  final trimmed = withoutRepeatedSeparators.replaceAll(_ocptLeadingOrTrailingClutter, '');

  final capped = trimmed.length > ocptSafeFileNameMaxLength
      ? trimmed.substring(0, ocptSafeFileNameMaxLength)
      : trimmed;
  final result = capped.replaceAll(_ocptLeadingOrTrailingClutter, '');

  return result.isEmpty ? fallback : result;
}
