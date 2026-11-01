// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:flutter_test/flutter_test.dart';

/// Collects the `return`, `break` and `continue` statements a block exits through, leaving out
/// the ones that belong to a closure or to a loop or `switch` the block itself holds.
class _ExitFinder extends RecursiveAstVisitor<void> {
  /// The line of every exit found.
  final exits = <int>[];

  /// Turns an offset into a line.
  final int Function(int offset) lineOf;

  /// How many loops or switches around the node being visited belong to the block.
  var _jumpTargetDepth = 0;

  /// Class constructor
  _ExitFinder({required this.lineOf});

  @override
  void visitFunctionExpression(FunctionExpression node) {}

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {}

  @override
  void visitReturnStatement(ReturnStatement node) {
    exits.add(lineOf(node.offset));
  }

  @override
  void visitBreakStatement(BreakStatement node) {
    if (_jumpTargetDepth == 0) {
      exits.add(lineOf(node.offset));
    }
  }

  @override
  void visitContinueStatement(ContinueStatement node) {
    if (_jumpTargetDepth == 0) {
      exits.add(lineOf(node.offset));
    }
  }

  @override
  void visitForStatement(ForStatement node) {
    _jumpTargetDepth++;
    super.visitForStatement(node);
    _jumpTargetDepth--;
  }

  @override
  void visitWhileStatement(WhileStatement node) {
    _jumpTargetDepth++;
    super.visitWhileStatement(node);
    _jumpTargetDepth--;
  }

  @override
  void visitDoStatement(DoStatement node) {
    _jumpTargetDepth++;
    super.visitDoStatement(node);
    _jumpTargetDepth--;
  }

  @override
  void visitSwitchStatement(SwitchStatement node) {
    _jumpTargetDepth++;
    super.visitSwitchStatement(node);
    _jumpTargetDepth--;
  }
}

/// Finds the `try` statements that have a `catch` clause and exit from their `try` block or from a
/// `catch` block.
class _TryFinder extends RecursiveAstVisitor<void> {
  /// The line of every offending exit found.
  final offences = <int>[];

  /// Turns an offset into a line.
  final int Function(int offset) lineOf;

  /// Class constructor
  _TryFinder({required this.lineOf});

  @override
  void visitTryStatement(TryStatement node) {
    if (node.catchClauses.isNotEmpty) {
      final finder = _ExitFinder(lineOf: lineOf);
      node.body.accept(finder);
      for (final clause in node.catchClauses) {
        clause.body.accept(finder);
      }
      offences.addAll(finder.exits);
    }
    super.visitTryStatement(node);
  }
}

/// A `try` statement with a `catch` clause reads from top to bottom when the outcome of each of its
/// blocks is stored in a variable and returned once the statement is over: a `return`, `break` or
/// `continue` inside the `try` or a `catch` block makes the reader follow the exit and the
/// `finally` (and whatever follows the statement) at once. `throw` and `rethrow` stay allowed, and
/// so does a `try`/`finally` with no `catch`, which returns from its `try` freely. A closure inside
/// the block has exits of its own and does not count.
///
/// This parses every Dart file of `lib/` and of each package's `lib/` and fails on an exit of that
/// kind, naming its line.
void main() {
  final roots = [
    Directory("lib"),
    ...Directory(
      "packages",
    ).listSync().whereType<Directory>().map((package) => Directory("${package.path}/lib")),
  ].where((directory) => directory.existsSync());

  final files = [
    for (final root in roots)
      ...root
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith(".dart") && !file.path.endsWith(".g.dart"))
          .where((file) => !file.path.contains("/generated/")),
  ]..sort((a, b) => a.path.compareTo(b.path));

  test("the sources were found", () {
    expect(files, isNotEmpty);
  });

  for (final file in files) {
    test("${file.path} exits from no try or catch block", () {
      final parsed = parseFile(
        path: file.absolute.path,
        featureSet: FeatureSet.latestLanguageVersion(),
      );
      final finder = _TryFinder(lineOf: (offset) => parsed.lineInfo.getLocation(offset).lineNumber);
      parsed.unit.accept(finder);

      expect(
        finder.offences,
        isEmpty,
        reason:
            "A try statement with a catch clause stores its outcome in a variable and returns it "
            "after the statement, instead of exiting from inside (lines ${finder.offences}).",
      );
    });
  }
}
