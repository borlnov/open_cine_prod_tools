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

  /// How many loops around the node being visited belong to the block.
  var _loopDepth = 0;

  /// How many loops or switches around the node being visited belong to the block.
  var _jumpTargetDepth = 0;

  /// The labels the block declares itself: a jump to one of them stays inside the block.
  final _ownLabels = <String>{};

  /// Class constructor
  _ExitFinder({required this.lineOf});

  /// Skip the function expression: its exits are not the enclosing function's.
  @override
  void visitFunctionExpression(FunctionExpression node) {}

  /// Skip the function declaration: its exits are not the enclosing function's.
  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {}

  /// Remember the labels this statement declares, then visit it.
  @override
  void visitLabeledStatement(LabeledStatement node) {
    for (final label in node.labels) {
      _ownLabels.add(label.label.name);
    }
    super.visitLabeledStatement(node);
  }

  /// Record the line of the return.
  @override
  void visitReturnStatement(ReturnStatement node) {
    exits.add(lineOf(node.offset));
  }

  /// Record the line of the break, unless it targets the statement or a label declared inside it.
  @override
  void visitBreakStatement(BreakStatement node) {
    final label = node.label?.name;
    if (label != null ? !_ownLabels.contains(label) : _jumpTargetDepth == 0) {
      exits.add(lineOf(node.offset));
    }
  }

  /// Record the line of the continue, unless it targets a loop or a label declared inside the
  /// statement.
  @override
  void visitContinueStatement(ContinueStatement node) {
    final label = node.label?.name;
    if (label != null ? !_ownLabels.contains(label) : _loopDepth == 0) {
      exits.add(lineOf(node.offset));
    }
  }

  /// Count the loop, then visit it: a `break` or a `continue` inside targets it.
  @override
  void visitForStatement(ForStatement node) {
    _loopDepth++;
    _jumpTargetDepth++;
    super.visitForStatement(node);
    _jumpTargetDepth--;
    _loopDepth--;
  }

  /// Count the loop, then visit it: a `break` or a `continue` inside targets it.
  @override
  void visitWhileStatement(WhileStatement node) {
    _loopDepth++;
    _jumpTargetDepth++;
    super.visitWhileStatement(node);
    _jumpTargetDepth--;
    _loopDepth--;
  }

  /// Count the loop, then visit it: a `break` or a `continue` inside targets it.
  @override
  void visitDoStatement(DoStatement node) {
    _loopDepth++;
    _jumpTargetDepth++;
    super.visitDoStatement(node);
    _jumpTargetDepth--;
    _loopDepth--;
  }

  /// Count the switch, then visit it: a `break` inside targets it.
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

  /// Look for the exits of the body of a `try` that has catch clauses, then visit it.
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
/// This parses every Dart file of `lib/`, `test/`, `tool/` and of each package's `lib/`, `test/` and
/// `bin/`, and fails on an exit of that kind, naming its line.
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
