// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// Checks the repository's markdown files against the mechanical rules the `markdown_lint` CI
/// workflow enforces, so a violation is caught before it is pushed rather than by a red build.
///
/// The workflow runs `markdownlint-cli2`, which needs a Node runtime the devcontainer deliberately
/// does not carry any more. Rather than reinstate one for a single linter, this script re-implements
/// the handful of rules that need no markdown parsing — the ones a long paragraph or an editor's
/// whitespace handling actually trips — reading their settings from `.markdownlint.yaml`:
///
/// - **MD013** (line length): the rule that motivated this script. A line longer than the limit is
///   only reported when it *can* be wrapped, matching markdownlint's own non-strict default: a line
///   with no space past the limit (a long URL, a wide code token) is left alone, and table rows are
///   exempt because the configuration turns `tables` off.
/// - **MD009** (trailing spaces): trailing whitespace, except the exactly two spaces that mean a
///   hard line break, and never on an otherwise blank line.
/// - **MD010** (hard tabs): a tab anywhere in a line.
/// - **MD047** (single trailing newline): the file ends with exactly one newline.
///
/// This is a fast pre-flight, **not** a replacement for the workflow: every other markdown rule is
/// still only checked in CI. A file passing here can still fail there — but the reverse should not
/// happen, so a failure reported here is real.
///
/// Line lengths are measured in UTF-16 code units, which is what `String.length` counts in Dart and
/// what markdownlint counts in JavaScript, so an em dash or an ellipsis is one unit in both.
///
/// The files checked are the ones git knows about — tracked, plus untracked files that are not
/// ignored, so a document written but not yet committed is covered too — minus the paths the
/// workflow's globs exclude.
///
/// Run it from the repository root:
///
/// ```sh
/// dart run tool/check_markdown.dart
/// ```
///
/// It prints one `path:line:column rule message` per violation and exits non-zero when there is at
/// least one, so it can be chained with `&&` in front of a commit or a push.
library;

import 'dart:io';

/// The configuration file the rules below read their settings from.
const _configPath = ".markdownlint.yaml";

/// The line length used when [_configPath] holds no `line_length` of its own.
const _defaultLineLength = 80;

/// The path prefixes the `markdown_lint` workflow's globs exclude, kept in the same order as the
/// `!` entries of its `globs` block so the two lists can be compared at a glance.
const _excludedPrefixes = [
  "actlibs/",
  "build/",
  ".dart_tool/",
  "test/",
  "node_modules/",
];

/// Checks every markdown file of the repository and reports what the CI linter would reject.
Future<void> main() async {
  final files = await _markdownFiles();

  if (files.isEmpty) {
    stderr.writeln("No markdown file to check: is this the repository root?");
    exitCode = 1;
    return;
  }

  final lineLength = await _configuredLineLength();
  final violations = <String>[];

  for (final path in files) {
    violations.addAll(_checkFile(path, lineLength: lineLength));
  }

  if (violations.isEmpty) {
    stdout.writeln("${files.length} markdown files checked, no violation found.");
    return;
  }

  violations.forEach(stdout.writeln);
  stdout.writeln();
  stdout.writeln("${violations.length} violation(s) in ${files.length} markdown files.");
  exitCode = 1;
}

/// Lists the markdown files to check: the ones git tracks plus the untracked ones it does not
/// ignore, minus [_excludedPrefixes].
///
/// Asking git rather than walking the tree keeps the generated and vendored directories out for
/// free, and matches what a push actually carries.
Future<List<String>> _markdownFiles() async {
  final result = await Process.run("git", [
    "ls-files",
    "--cached",
    "--others",
    "--exclude-standard",
    "*.md",
  ]);

  if (result.exitCode != 0) {
    stderr.writeln("git ls-files failed: ${result.stderr}");
    return const [];
  }

  final paths = (result.stdout as String)
      .split("\n")
      .map((path) => path.trim())
      .where((path) => path.isNotEmpty)
      .where((path) => !_excludedPrefixes.any(path.startsWith))
      .toSet()
      .toList()
    ..sort();

  return paths;
}

/// Reads the `line_length` of the `MD013` block of [_configPath], falling back to
/// [_defaultLineLength] when the file or the setting is missing.
///
/// The block is read line by line rather than through a YAML parser: this script has no package
/// dependencies of its own so that it can run before `flutter pub get` has ever been called.
Future<int> _configuredLineLength() async {
  final config = File(_configPath);

  if (!config.existsSync()) {
    return _defaultLineLength;
  }

  var inMd013 = false;

  for (final line in await config.readAsLines()) {
    if (line.startsWith("MD013:")) {
      inMd013 = true;
      continue;
    }

    // Any other top-level key ends the block: the settings of a rule are the indented lines
    // following it.
    if (inMd013 && line.isNotEmpty && !line.startsWith(RegExp(r"\s|#"))) {
      break;
    }

    if (!inMd013) {
      continue;
    }

    final match = RegExp(r"^\s+line_length:\s*(\d+)").firstMatch(line);

    if (match != null) {
      return int.parse(match.group(1)!);
    }
  }

  return _defaultLineLength;
}

/// Returns one message per rule violation found in the file at [path], empty when it is clean.
List<String> _checkFile(String path, {required int lineLength}) {
  final content = File(path).readAsStringSync();
  final lines = content.split("\n");
  final violations = <String>[];

  for (var index = 0; index < lines.length; index++) {
    final line = lines[index];
    final number = index + 1;

    final tabIndex = line.indexOf("\t");

    if (tabIndex >= 0) {
      violations.add("$path:$number:${tabIndex + 1} MD010/no-hard-tabs Hard tab");
    }

    final trailing = line.length - line.trimRight().length;

    // Two trailing spaces are a hard line break, which the rule allows on a line that has content.
    if (trailing > 0 && !(trailing == 2 && line.trimRight().isNotEmpty)) {
      violations.add(
        "$path:$number:${line.length - trailing + 1} MD009/no-trailing-spaces "
        "Trailing spaces [Expected: 0 or 2; Actual: $trailing]",
      );
    }

    if (_isTooLong(line, lineLength: lineLength)) {
      violations.add(
        "$path:$number:${lineLength + 1} MD013/line-length "
        "Line length [Expected: $lineLength; Actual: ${line.length}]",
      );
    }
  }

  // `split("\n")` leaves one trailing empty entry for a file ending on a single newline, and two
  // for one ending on a blank line.
  if (lines.length < 2 || lines.last.isNotEmpty || lines[lines.length - 2].isEmpty) {
    violations.add("$path:${lines.length} MD047/single-trailing-newline "
        "Files should end with a single newline character");
  }

  return violations;
}

/// Whether [line] breaks MD013 as the project configures it.
///
/// A line over [lineLength] is only a violation when it could be wrapped — markdownlint's own
/// default with `strict` and `stern` both off — and table rows are exempt, the configuration
/// setting `tables: false`.
bool _isTooLong(String line, {required int lineLength}) {
  if (line.length <= lineLength) {
    return false;
  }

  if (line.trimLeft().startsWith("|")) {
    return false;
  }

  return line.substring(lineLength).contains(" ");
}
