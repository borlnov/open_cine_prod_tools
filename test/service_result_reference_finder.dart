// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

/// Finds the references to some class names.
class ReferenceFinder extends RecursiveAstVisitor<void> {
  /// The names looked for.
  final Set<String> names;

  /// The lines where one was named.
  final lines = <int>[];

  /// Turns an offset into a line.
  final int Function(int offset) lineOf;

  /// Class constructor
  ReferenceFinder({required this.names, required this.lineOf});

  /// Record a use of one of the names.
  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (names.contains(node.name)) {
      lines.add(lineOf(node.offset));
    }
  }

  /// Record a use of one of the names as a type, which includes building one with `const`.
  @override
  void visitNamedType(NamedType node) {
    if (names.contains(node.name.lexeme)) {
      lines.add(lineOf(node.offset));
    }
    super.visitNamedType(node);
  }
}
