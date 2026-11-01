// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:flutter_test/flutter_test.dart';

/// The placeholder comment the equality getters carried before each one said what it lists.
const _placeholderComment = "/// Object properties";

/// A readable name for [member], for the failure message.
String _nameOf(ClassMember member) {
  switch (member) {
    case FieldDeclaration(:final fields):
      return fields.variables.map((variable) => variable.name.lexeme).join(", ");
    case ConstructorDeclaration(:final typeName, :final name):
      return "${typeName?.name}${name == null ? "" : ".${name.lexeme}"}";
    case MethodDeclaration(:final name):
      return name.lexeme;
    default:
      return member.runtimeType.toString();
  }
}

/// A readable name for the top-level [declaration], for the failure message.
String _topLevelNameOf(CompilationUnitMember declaration) {
  switch (declaration) {
    case ClassDeclaration(:final namePart):
      return namePart.typeName.lexeme;
    case MixinDeclaration(:final name):
      return name.lexeme;
    case EnumDeclaration(:final namePart):
      return namePart.typeName.lexeme;
    case ExtensionDeclaration(:final name):
      return name?.lexeme ?? "<unnamed extension>";
    case ExtensionTypeDeclaration(:final primaryConstructor):
      return primaryConstructor.typeName.lexeme;
    case FunctionDeclaration(:final name):
      return name.lexeme;
    case TopLevelVariableDeclaration(:final variables):
      return variables.variables.map((variable) => variable.name.lexeme).join(", ");
    case GenericTypeAlias(:final name):
      return name.lexeme;
    case FunctionTypeAlias(:final name):
      return name.lexeme;
    default:
      return declaration.runtimeType.toString();
  }
}

/// The members of the container [declaration] declares, or an empty list when it has none.
List<ClassMember> _membersOf(CompilationUnitMember declaration) {
  switch (declaration) {
    case ClassDeclaration(:final body) when body is BlockClassBody:
      return body.members;
    case MixinDeclaration(:final body):
      return body.members;
    case ExtensionDeclaration(:final body):
      return body.members;
    case ExtensionTypeDeclaration(:final body) when body is BlockClassBody:
      return body.members;
    case EnumDeclaration(:final body):
      return body.members;
    default:
      return const [];
  }
}

/// Lists the declarations of [file] that have no doc comment, and those whose comment is the
/// placeholder, as "path:line name".
List<String> _offencesOf(File file) {
  final parsed = parseFile(
    path: file.absolute.path,
    featureSet: FeatureSet.latestLanguageVersion(),
  );
  final offences = <String>[];

  void check(AnnotatedNode node, String name) {
    final line = parsed.lineInfo.getLocation(node.firstTokenAfterCommentAndMetadata.offset);
    final comment = node.documentationComment;
    if (comment == null) {
      offences.add("${file.path}:${line.lineNumber} $name has no doc comment");
    } else if (comment.tokens.length == 1 &&
        comment.tokens.first.lexeme.trim() == _placeholderComment) {
      offences.add("${file.path}:${line.lineNumber} $name has a placeholder doc comment");
    }
  }

  for (final declaration in parsed.unit.declarations) {
    check(declaration, _topLevelNameOf(declaration));
    for (final member in _membersOf(declaration)) {
      check(member, "${_topLevelNameOf(declaration)}.${_nameOf(member)}");
    }
  }

  return offences;
}

/// The third-person verbs a doc comment must not open with: it opens with the imperative instead
/// (`Build`, not `Builds`).
const _thirdPersonVerbs = <String>{
  "Abandons",
  "Adds",
  "Advances",
  "Anchors",
  "Answers",
  "Antialiases",
  "Appends",
  "Applies",
  "Asks",
  "Assigns",
  "Attaches",
  "Authenticates",
  "Bends",
  "Blanks",
  "Brings",
  "Buckets",
  "Builds",
  "Calls",
  "Cancels",
  "Capitalizes",
  "Captures",
  "Carries",
  "Casts",
  "Chains",
  "Checks",
  "Clamps",
  "Classifies",
  "Clears",
  "Clips",
  "Closes",
  "Collects",
  "Commits",
  "Completes",
  "Composes",
  "Computes",
  "Confirms",
  "Converts",
  "Convokes",
  "Copies",
  "Counts",
  "Creates",
  "Decides",
  "Decodes",
  "Deduces",
  "Delegates",
  "Deletes",
  "Derives",
  "Detaches",
  "Determines",
  "Dismisses",
  "Dispatches",
  "Displays",
  "Disposes",
  "Does",
  "Draws",
  "Drives",
  "Drops",
  "Duplicates",
  "Emboldens",
  "Emits",
  "Empties",
  "Encodes",
  "Ends",
  "Enters",
  "Erases",
  "Escapes",
  "Estimates",
  "Expands",
  "Exports",
  "Falls",
  "Fetches",
  "Files",
  "Fills",
  "Filters",
  "Finds",
  "Finishes",
  "Fires",
  "Fits",
  "Flattens",
  "Flushes",
  "Focuses",
  "Folds",
  "Forgets",
  "Formats",
  "Forwards",
  "Freezes",
  "Generates",
  "Groups",
  "Handles",
  "Hands",
  "Has",
  "Hashes",
  "Hides",
  "Highlights",
  "Indexes",
  "Inserts",
  "Installs",
  "Interpolates",
  "Joins",
  "Keeps",
  "Kills",
  "Labels",
  "Lays",
  "Leaves",
  "Links",
  "Lists",
  "Loads",
  "Logs",
  "Maps",
  "Marks",
  "Masks",
  "Materialises",
  "Measures",
  "Merges",
  "Mints",
  "Moves",
  "Names",
  "Narrows",
  "Navigates",
  "Notifies",
  "Opens",
  "Orders",
  "Overlays",
  "Overwrites",
  "Owns",
  "Packages",
  "Pages",
  "Paints",
  "Pairs",
  "Parses",
  "Pays",
  "Persists",
  "Picks",
  "Pins",
  "Places",
  "Points",
  "Pops",
  "Positions",
  "Prepends",
  "Promotes",
  "Prunes",
  "Publishes",
  "Pushes",
  "Puts",
  "Raises",
  "Ranks",
  "Rasterizes",
  "Reacts",
  "Reads",
  "Rebuilds",
  "Recomputes",
  "Reconciles",
  "Reconstructs",
  "Records",
  "Redirects",
  "Redraws",
  "References",
  "Refreshes",
  "Registers",
  "Rejoins",
  "Releases",
  "Reloads",
  "Remembers",
  "Removes",
  "Renames",
  "Renders",
  "Renumbers",
  "Reorders",
  "Replaces",
  "Reports",
  "Represents",
  "Requests",
  "Resizes",
  "Resolves",
  "Restarts",
  "Restores",
  "Retains",
  "Returns",
  "Reveals",
  "Rewrites",
  "Rotates",
  "Routes",
  "Runs",
  "Saves",
  "Says",
  "Scans",
  "Schedules",
  "Scrolls",
  "Seeds",
  "Selects",
  "Sends",
  "Serialises",
  "Serializes",
  "Sets",
  "Settles",
  "Shows",
  "Snapshots",
  "Sorts",
  "Spawns",
  "Splices",
  "Splits",
  "Stamps",
  "Starts",
  "States",
  "Stats",
  "Stops",
  "Stores",
  "Streams",
  "Strips",
  "Styles",
  "Submits",
  "Subscribes",
  "Suggests",
  "Sums",
  "Switches",
  "Tags",
  "Takes",
  "Teaches",
  "Tears",
  "Tells",
  "Throws",
  "Ticks",
  "Toggles",
  "Tokenizes",
  "Tombstones",
  "Translates",
  "Tries",
  "Trims",
  "Turns",
  "Undoes",
  "Unlinks",
  "Unpacks",
  "Unpairs",
  "Updates",
  "Upgrades",
  "Upserts",
  "Validates",
  "Wakes",
  "Walks",
  "Wraps",
  "Writes",
  "Yields",
  "Zooms",
};

/// The articles and determiners a method, getter, setter, operator or function doc may not open
/// with: such a doc says what the member does, and starts with the verb that says it.
const _nounPhraseOpenings = <String>{"The", "A", "An", "This", "One"};

/// The members whose doc opens with a noun phrase on purpose. Each of these four functions sits
/// under a file-level comment that is not separated from it by a code token, so the parser reads
/// that header as the first lines of the function's own doc.
const _verbOpeningExceptions = <String>{
  "ocptBudgetReceivedByRevenueId",
  "ocptBudgetPricedElementIdsOf",
  "ocptBudgetReimbursedByPersonId",
  "ocptBudgetReceivedByResourceId",
};

/// The first word of the doc of [node], or null when it has no doc or opens with a `{@macro}`.
String? _firstWordOf(AnnotatedNode node) {
  final comment = node.documentationComment;
  if (comment == null) {
    return null;
  }
  for (final token in comment.tokens) {
    final text = token.lexeme.replaceFirst(RegExp(r"^///\s?"), "").trim();
    if (text.isEmpty || text.startsWith("{@template")) {
      continue;
    }
    if (text.startsWith("{@")) {
      return null;
    }
    return RegExp("^[A-Za-z]+").firstMatch(text)?.group(0);
  }
  return null;
}

/// Lists the methods, getters, setters, operators and functions of [file] whose doc does not open
/// with an imperative verb, as "path:line name".
List<String> _verbOffencesOf(File file) {
  final parsed = parseFile(
    path: file.absolute.path,
    featureSet: FeatureSet.latestLanguageVersion(),
  );
  final offences = <String>[];

  void check(AnnotatedNode node, String name) {
    final word = _firstWordOf(node);
    if (word == null || _verbOpeningExceptions.contains(name)) {
      return;
    }
    if (_nounPhraseOpenings.contains(word) || _thirdPersonVerbs.contains(word)) {
      final line = parsed.lineInfo.getLocation(node.firstTokenAfterCommentAndMetadata.offset);
      offences.add("${file.path}:${line.lineNumber} $name opens with `$word`");
    }
  }

  for (final declaration in parsed.unit.declarations) {
    if (declaration is FunctionDeclaration) {
      check(declaration, declaration.name.lexeme);
    }
    for (final member in _membersOf(declaration)) {
      if (member is MethodDeclaration) {
        check(member, member.name.lexeme);
      }
    }
  }

  return offences;
}

/// Every class, mixin, enum, extension, typedef, function, variable, field, constructor, method,
/// getter and setter carries a `///` doc comment, private ones and overrides included, in the
/// app, in the tests, in the tools and in each package. An enum's values are not counted.
///
/// This parses every Dart file, and fails on a declaration without one, naming it.
void main() {
  final roots = [
    Directory("lib"),
    Directory("test"),
    Directory("tool"),
    for (final package in Directory("packages").listSync().whereType<Directory>())
      for (final folder in ["lib", "test", "bin"]) Directory("${package.path}/$folder"),
  ].where((directory) => directory.existsSync());

  final files = [
    for (final root in roots)
      ...root
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith(".dart") && !file.path.endsWith(".g.dart"))
          .where((file) => !file.path.contains("/generated/")),
  ]..sort((a, b) => a.path.compareTo(b.path));

  // One test per folder: the first two segments of a path, as "lib/ui" or "packages/spell_kit".
  final folders = <String, List<File>>{};
  for (final file in files) {
    final segments = file.path.split("/");
    final key = segments.length > 2 ? segments.take(2).join("/") : segments.first;
    folders.putIfAbsent(key, () => []).add(file);
  }

  test("the sources were found", () {
    expect(files, isNotEmpty);
  });

  folders.forEach((folder, folderFiles) {
    test("$folder documents every declaration", () {
      final offences = [for (final file in folderFiles) ..._offencesOf(file)];

      expect(
        offences,
        isEmpty,
        reason:
            "Every declaration carries a doc comment that says what it is or does, private ones "
            "and overrides included.",
      );
    });
  });

  // The tests are not held to it: only the code they exercise is.
  for (final entry in folders.entries.where((entry) => !entry.key.startsWith("test"))) {
    test("${entry.key} opens the doc of every method and function with a verb", () {
      final offences = [
        for (final file in entry.value.where((file) => !file.path.contains("/test/")))
          ..._verbOffencesOf(file),
      ];

      expect(
        offences,
        isEmpty,
        reason:
            "A method, getter, setter, operator or function doc starts with an imperative "
            "verb: `Build the page`, not `Builds the page` nor `The page`.",
      );
    });
  }
}
