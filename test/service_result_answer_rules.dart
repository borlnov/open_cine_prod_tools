// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The rules `service_result_answer_test.dart` holds the project to about the answers that sit
/// between a service and a handler: the members that carry a stop, and what the code does with a
/// variable that holds an answer.
///
/// Like the rules of `service_result_rules.dart`, every rule reads the syntax tree of one file and
/// resolves no type. A call is therefore known as a call of a member that answers a result by the
/// name of the member alone, whatever its receiver: a name another type also uses can raise a
/// false alarm, which the hits of the real code are read for.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import 'service_result_rules.dart';

/// The start of a declared type that is a result a caller must read.
const _resultTypeStarts = [
  "Future<OcptDatabaseResult<",
  "Future<OcptDatabaseOutcome>",
  "Future<ResultWithStatus<",
  "Future<StatusWithExtraInfo<",
  "OcptDatabaseResult<",
  "OcptDatabaseOutcome",
  "ResultWithStatus<",
  "StatusWithExtraInfo<",
];

/// The members of a result that tell whether the call failed.
const _checkMembers = {"isError", "isSuccess", "status"};

/// Tell whether [type] is declared as a result a caller must read.
bool namesAResult(TypeAnnotation? type) {
  final source = type?.toSource() ?? "";

  return _resultTypeStarts.any(source.startsWith);
}

/// Tell whether a declaration with [metadata] says `@useResult`.
bool _hasUseResult(NodeList<Annotation> metadata) =>
    metadata.any((annotation) => annotation.name.name == "useResult");

/// Collects the members and functions declared to answer a result, with the ones that do not say
/// `@useResult`.
class ResultMemberCollector extends RecursiveAstVisitor<void> {
  /// The name of every member or function declared to answer a result, private ones included.
  final names = <String>{};

  /// The name of those that answer a database result, whose value is null for a refusal as well
  /// as for nothing found, so that a failure is told apart by its status only.
  final databaseNames = <String>{};

  /// The `line: Class.member` of those that do not say `@useResult`.
  final unannotated = <String>[];

  /// Turns an offset into a line.
  final int Function(int offset) lineOf;

  /// The class being read, or null outside one.
  String? _className;

  /// Class constructor
  ResultMemberCollector({required this.lineOf});

  /// Read the members of a class under its name.
  @override
  void visitClassDeclaration(ClassDeclaration node) {
    _className = node.namePart.typeName.lexeme;
    super.visitClassDeclaration(node);
    _className = null;
  }

  /// Read the members of a mixin under its name.
  @override
  void visitMixinDeclaration(MixinDeclaration node) {
    _className = node.name.lexeme;
    super.visitMixinDeclaration(node);
    _className = null;
  }

  /// Read the members of an extension under its name.
  @override
  void visitExtensionDeclaration(ExtensionDeclaration node) {
    _className = node.name?.lexeme ?? "extension";
    super.visitExtensionDeclaration(node);
    _className = null;
  }

  /// Record a method that answers a result.
  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (!node.isGetter && !node.isSetter && namesAResult(node.returnType)) {
      _record(node.name.lexeme, node.metadata, node.offset, node.returnType);
    }
    super.visitMethodDeclaration(node);
  }

  /// Record a function that answers a result.
  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    if (_className == null && namesAResult(node.returnType)) {
      _record(node.name.lexeme, node.metadata, node.offset, node.returnType);
    }
    super.visitFunctionDeclaration(node);
  }

  /// Record [name], and its line when it lacks `@useResult`.
  void _record(String name, NodeList<Annotation> metadata, int offset, TypeAnnotation? type) {
    names.add(name);
    if (type!.toSource().contains("OcptDatabase")) {
      databaseNames.add(name);
    }
    if (!_hasUseResult(metadata)) {
      unannotated.add("${lineOf(offset)}: ${_className == null ? "" : "$_className."}$name");
    }
  }
}

/// Finds the members of a list that do not say `@useResult`, whatever their return type.
class NamedMemberFinder extends RecursiveAstVisitor<void> {
  /// The names looked for.
  final Set<String> wanted;

  /// The names found without `@useResult`.
  final unannotated = <String>[];

  /// The names found, annotated or not.
  final found = <String>{};

  /// Class constructor
  NamedMemberFinder({required this.wanted});

  /// Check a method of that name.
  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    final name = node.name.lexeme;
    if (wanted.contains(name)) {
      found.add(name);
      if (!_hasUseResult(node.metadata)) {
        unannotated.add(name);
      }
    }
    super.visitMethodDeclaration(node);
  }
}

/// Finds what is wrong with a variable that holds the answer of a call of a member that answers a
/// result, and with the `if` that tests an answer for a failure.
class AnswerUseFinder extends RecursiveAstVisitor<void> {
  /// The names of the members that answer a result.
  final Set<String> names;

  /// The names of those that answer a database result: for them the value must not be read before
  /// a check, since a null value does not say whether the call failed.
  final Set<String> databaseNames;

  /// The offending places, as `line: reason`.
  final offences = <String>[];

  /// Turns an offset into a line.
  final int Function(int offset) lineOf;

  /// Class constructor
  AnswerUseFinder({required this.names, required this.databaseNames, required this.lineOf});

  /// Check a variable that holds an answer.
  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    var initializer = node.initializer;
    while (initializer is ParenthesizedExpression) {
      initializer = initializer.expression;
    }
    final call = initializer is AwaitExpression ? _strip(initializer.expression) : null;
    final block = node.parent?.parent?.parent;
    if (call is MethodInvocation &&
        names.contains(call.methodName.name) &&
        node.name.lexeme != "_" &&
        block is Block) {
      final use = _AnswerUse(variable: node.name.lexeme);
      block.accept(use);
      final isDatabase = databaseNames.contains(call.methodName.name);
      final reads = isDatabase ? use.valueReadsBeforeAnyCheck : <AstNode>[];
      for (final read in reads) {
        offences.add(
          "${lineOf(read.offset)}: answer '${node.name.lexeme}' has its value read before "
          "isError or status",
        );
      }
      if (reads.isEmpty && !use.isChecked && !use.isHandedOn) {
        offences.add(
          "${lineOf(node.offset)}: answer '${node.name.lexeme}' is never checked: read isError "
          "or status",
        );
      }
    }
    super.visitVariableDeclaration(node);
  }

  /// Check that an `if` on a failure ends in a way out.
  @override
  void visitIfStatement(IfStatement node) {
    if (node.elseStatement == null && _testsForFailure(node.expression)) {
      final then = node.thenStatement;
      final last = then is Block ? then.statements.lastOrNull : then;
      if (!_leaves(last)) {
        offences.add(
          "${lineOf(node.offset)}: an if on a failure ends with neither a way out nor the "
          "assignment of a flag",
        );
      }
    }
    super.visitIfStatement(node);
  }

  /// Tell whether [condition] holds the branch when an answer is a failure: an `isError` read
  /// alone, or as an operand of `||`.
  bool _testsForFailure(Expression condition) {
    final stripped = _strip(condition);
    var tests = false;
    if (stripped is BinaryExpression && stripped.operator.type == TokenType.BAR_BAR) {
      tests = _testsForFailure(stripped.leftOperand) || _testsForFailure(stripped.rightOperand);
    } else if (stripped is PrefixedIdentifier) {
      tests = stripped.identifier.name == "isError";
    } else if (stripped is PropertyAccess) {
      tests = stripped.propertyName.name == "isError";
    }

    return tests;
  }

  /// Tell whether [statement] leaves the function or the loop, or sets a flag the code goes on
  /// from.
  bool _leaves(Statement? statement) {
    var leaves = false;
    if (statement is ReturnStatement ||
        statement is BreakStatement ||
        statement is ContinueStatement) {
      leaves = true;
    } else if (statement is ExpressionStatement) {
      final expression = statement.expression;
      leaves =
          expression is ThrowExpression ||
          expression is RethrowExpression ||
          expression is AssignmentExpression;
    }

    return leaves;
  }

  /// Remove the parentheses around [expression].
  Expression _strip(Expression expression) {
    var stripped = expression;
    while (stripped is ParenthesizedExpression) {
      stripped = stripped.expression;
    }

    return stripped;
  }
}

/// Reads how a variable holding an answer is used.
class _AnswerUse extends RecursiveAstVisitor<void> {
  /// The name of the variable.
  final String variable;

  /// The value reads that come before any read of `isError`, `isSuccess` or `status`.
  final valueReadsBeforeAnyCheck = <AstNode>[];

  /// Whether `isError`, `isSuccess` or `status` is read at all.
  bool isChecked = false;

  /// Whether the variable is handed on whole: returned, passed, compared or stored.
  bool isHandedOn = false;

  /// Class constructor
  _AnswerUse({required this.variable});

  /// Read the variable wherever it is named.
  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (node.name == variable && !node.inDeclarationContext()) {
      final member = _memberReadOff(node);
      if (member == null) {
        isHandedOn = true;
      } else if (_checkMembers.contains(member.name)) {
        isChecked = true;
      } else if (member.name == "value" && !isChecked) {
        valueReadsBeforeAnyCheck.add(member);
      }
    }
    super.visitSimpleIdentifier(node);
  }

  /// Get the member read off [node], as `variable.member`, `variable?.member` or
  /// `variable!.member`, or null when [node] is not the target of a member read.
  SimpleIdentifier? _memberReadOff(SimpleIdentifier node) {
    AstNode child = node;
    var parent = node.parent;
    while (parent is PostfixExpression && parent.operator.type == TokenType.BANG) {
      child = parent;
      parent = parent.parent;
    }
    SimpleIdentifier? member;
    if (parent is PrefixedIdentifier && identical(parent.prefix, child)) {
      member = parent.identifier;
    } else if (parent is PropertyAccess && identical(parent.target, child)) {
      member = parent.propertyName;
    }

    return member;
  }
}

/// List the names of the members and functions of [source] declared to answer a result.
Set<String> resultMembersOf(String source) => _collect(source).names;

/// List the names of those that answer a database result.
Set<String> databaseResultMembersOf(String source) => _collect(source).databaseNames;

/// List the `line: Class.member` of the members of [source] declared to answer a result that do
/// not say `@useResult`.
List<String> unannotatedResultMembersOf(String source) => _collect(source).unannotated;

/// Collect the members of [source] that answer a result.
ResultMemberCollector _collect(String source) {
  final unit = parseSource(source);
  final collector = ResultMemberCollector(
    lineOf: (offset) => unit.lineInfo.getLocation(offset).lineNumber,
  );
  unit.accept(collector);

  return collector;
}

/// List the members of [source] named in [wanted], and which of them lack `@useResult`, as
/// `(found, unannotated)`.
(Set<String>, List<String>) namedMembersOf(Set<String> wanted, String source) {
  final finder = NamedMemberFinder(wanted: wanted);
  parseSource(source).accept(finder);

  return (finder.found, finder.unannotated);
}

/// List what is wrong in [source] with the variables that hold the answer of one of the [names]
/// members and with the `if` that tests an answer for a failure, one `line: reason` each. The value
/// of an answer is read before a check only for the [databaseNames] members.
List<String> answerUseOffencesOf(
  Set<String> names,
  String source, {
  Set<String> databaseNames = const {},
}) {
  final unit = parseSource(source);
  final finder = AnswerUseFinder(
    names: names,
    databaseNames: databaseNames,
    lineOf: (offset) => unit.lineInfo.getLocation(offset).lineNumber,
  );
  unit.accept(finder);

  return finder.offences;
}
