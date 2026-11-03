// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The rules `service_result_test.dart` holds the project to, written as readers of a parsed file.
///
/// Every rule reads the syntax tree of a file and nothing else: no type is resolved, which keeps
/// the guard as fast as the other source guards. What that costs is said on each rule, and the
/// receiver of a call is the weak spot: a call is known to be a call of a service only by the
/// shape of its receiver (see [isServiceReceiver]).
library;

import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import 'service_result_reference_finder.dart';

/// The names of the life cycle methods, which stay as they are.
const _lifeCycleMethods = {"initLifeCycle", "disposeLifeCycle"};

/// The names of the two helpers a converted method hands its whole body to.
const _guardHelpers = {"guardResult", "guardOutcome"};

/// The names of the types that make an answer a result a caller must read.
const _resultTypeNames = {
  "OcptDatabaseOutcome",
  "OcptDatabaseResult",
  "StatusWithExtraInfo",
  "ResultWithStatus",
};

/// The start of a return type that is a result a caller must read.
const _resultReturnTypes = [
  "Future<OcptDatabaseResult<",
  "Future<OcptDatabaseOutcome>",
  "Future<ResultWithStatus<",
  "Future<StatusWithExtraInfo<",
  "ResultWithStatus<",
  "StatusWithExtraInfo<",
];

/// The two extensions that cancel a transaction when the call they wrap failed.
const _abortHelpers = {"okOrAbort", "valueOrAbort"};

/// The methods whose `guardResult` or `guardOutcome` body may wrap a call in `valueOrAbort` or
/// `okOrAbort` without a transaction of their own, each with the reason: the guard catches the
/// abort and answers its failure, and that is only wanted where the caller turns the answer back
/// into a throw inside a transaction of its own.
const abortInGuardBodyMethods = <String, String>{
  "mergeIncomingFountainText":
      "its caller's transaction wraps it and throws on the failure it answers",
};

/// The helpers declared in another file that take a closure answering a result, and so may be
/// handed one that returns a converted call. None yet.
const helpersTakingAResult = <String>{};

/// The receivers that reach a participant of the same name as a converted method of another
/// service, so that a call on them is not a call of the converted one.
const homonymReceivers = <String, Set<String>>{
  "reconcile": {"roleIndexService", "_roleIndexService"},
};

/// The type a call has to be a member of for [isServiceReceiver] to take its receiver for a
/// service.
const _serviceSuffix = "Service";

/// A service method as the guard sees it.
class ServiceMethod {
  /// The class that declares it.
  final String className;

  /// The method's name.
  final String name;

  /// Whether it is converted: it answers a result, says `@useResult`, and its body is a single
  /// expression handed to the guard.
  final bool isConverted;

  /// Whether it takes the caller's `stamps`, so runs inside the caller's transaction and stays
  /// raising.
  final bool isParticipant;

  /// Whether it carries `@useResult`.
  final bool hasUseResult;

  /// What names the method in the inventory: `<Class>.<method>`.
  String get id => "$className.$name";

  /// Class constructor
  const ServiceMethod({
    required this.className,
    required this.name,
    required this.isConverted,
    required this.isParticipant,
    required this.hasUseResult,
  });
}

/// Collects the service methods of a parsed file.
class MethodCollector extends RecursiveAstVisitor<void> {
  /// The methods found.
  final methods = <ServiceMethod>[];

  /// Class constructor
  MethodCollector();

  /// Look at the methods of a class that extends `AbsOcptService`.
  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final body = node.body;
    if (node.extendsClause?.superclass.name.lexeme == "AbsOcptService" && body is BlockClassBody) {
      final className = node.namePart.typeName.lexeme;
      for (final member in body.members.whereType<MethodDeclaration>()) {
        final method = _describe(className, member);
        if (method != null) {
          methods.add(method);
        }
      }
    }
    super.visitClassDeclaration(node);
  }

  /// Describe [member] when it is a public instance method that returns a `Future`.
  ServiceMethod? _describe(String className, MethodDeclaration member) {
    final name = member.name.lexeme;
    final returnType = member.returnType?.toSource() ?? "";
    final isInScope =
        !member.isStatic &&
        !member.isGetter &&
        !member.isSetter &&
        !name.startsWith("_") &&
        !_lifeCycleMethods.contains(name) &&
        returnType.startsWith("Future<");
    if (!isInScope) {
      return null;
    }

    final parameters = member.parameters?.parameters ?? <FormalParameter>[];
    final hasUseResult = member.metadata.any((annotation) => annotation.name.name == "useResult");
    final body = member.body;
    final expression = body is ExpressionFunctionBody ? body.expression : null;
    final isGuarded =
        expression is MethodInvocation &&
        _guardHelpers.contains(expression.methodName.name) &&
        (expression.target == null || expression.target is ThisExpression);

    return ServiceMethod(
      className: className,
      name: name,
      isConverted: _resultReturnTypes.any(returnType.startsWith) && hasUseResult && isGuarded,
      isParticipant: parameters.any((parameter) => parameter.name?.lexeme == "stamps"),
      hasUseResult: hasUseResult,
    );
  }
}

/// Finds every `try` with a `catch` clause, named by the member that holds it.
class CatchSiteFinder extends RecursiveAstVisitor<void> {
  /// The `<Class>.<member>` (or the function's name) of every `try` with a `catch` clause found.
  final sites = <String>{};

  /// The class being read, or null outside one.
  String? _className;

  /// The member being read, or null outside one.
  String? _member;

  /// Class constructor
  CatchSiteFinder();

  /// Read the members of the class under its name.
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

  /// Name what a method holds by the method.
  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    _member = node.name.lexeme;
    super.visitMethodDeclaration(node);
    _member = null;
  }

  /// Name what a constructor holds by the constructor.
  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {
    _member = node.name?.lexeme ?? "new";
    super.visitConstructorDeclaration(node);
    _member = null;
  }

  /// Name what a top-level function holds by the function.
  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    if (_className == null) {
      _member = node.name.lexeme;
    }
    super.visitFunctionDeclaration(node);
    if (_className == null) {
      _member = null;
    }
  }

  /// Record a `try` that has a `catch` clause.
  @override
  void visitTryStatement(TryStatement node) {
    if (node.catchClauses.isNotEmpty) {
      final className = _className;
      final member = _member ?? "?";
      sites.add(className == null ? member : "$className.$member");
    }
    super.visitTryStatement(node);
  }
}

/// Finds the lines where a throw leaves a method: `throw`, `rethrow` and `Future.error`.
class ThrowFinder extends RecursiveAstVisitor<void> {
  /// The line of every throw found.
  final lines = <int>[];

  /// Turns an offset into a line.
  final int Function(int offset) lineOf;

  /// Class constructor
  ThrowFinder({required this.lineOf});

  /// Record the line of the `throw`.
  @override
  void visitThrowExpression(ThrowExpression node) {
    lines.add(lineOf(node.offset));
    super.visitThrowExpression(node);
  }

  /// Record the line of the `rethrow`.
  @override
  void visitRethrowExpression(RethrowExpression node) {
    lines.add(lineOf(node.offset));
    super.visitRethrowExpression(node);
  }

  /// Record the line of a `Future.error(...)`.
  @override
  void visitMethodInvocation(MethodInvocation node) {
    final target = node.target?.toSource() ?? "";
    if (node.methodName.name == "error" && target.startsWith("Future")) {
      lines.add(lineOf(node.offset));
    }
    super.visitMethodInvocation(node);
  }
}

/// Collects the names a file declares with the type of a service.
///
/// A name declared with a type that ends in `Service`, as a variable, a field or a parameter, or
/// initialised by `get<…Service>()` or by the construction of a service. The set is for the whole
/// file, not per scope, so a name reused for something else in another function is taken for a
/// service there too.
class ServiceNameCollector extends RecursiveAstVisitor<void> {
  /// The names found.
  final names = <String>{};

  /// Class constructor
  ServiceNameCollector();

  /// Record a variable or field declared with a service type.
  @override
  void visitVariableDeclarationList(VariableDeclarationList node) {
    if (_isServiceType(node.type)) {
      names.addAll(node.variables.map((variable) => variable.name.lexeme));
    }
    super.visitVariableDeclarationList(node);
  }

  /// Record a variable initialised by a service.
  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    final initializer = node.initializer;
    if (initializer is MethodInvocation) {
      final isConstruction =
          initializer.target == null && initializer.methodName.name.endsWith(_serviceSuffix);
      if (isConstruction || _isGetOfService(initializer)) {
        names.add(node.name.lexeme);
      }
    }
    super.visitVariableDeclaration(node);
  }

  /// Record a parameter declared with a service type.
  @override
  void visitSimpleFormalParameter(SimpleFormalParameter node) {
    final name = node.name?.lexeme;
    if (name != null && _isServiceType(node.type)) {
      names.add(name);
    }
    super.visitSimpleFormalParameter(node);
  }

  /// Record a parameter that sets a field, declared with a service type.
  @override
  void visitFieldFormalParameter(FieldFormalParameter node) {
    if (_isServiceType(node.type)) {
      names.add(node.name.lexeme);
    }
    super.visitFieldFormalParameter(node);
  }
}

/// Tell whether [type] names a service, with or without a `?`.
bool _isServiceType(TypeAnnotation? type) =>
    type is NamedType && type.name.lexeme.endsWith(_serviceSuffix);

/// Tell whether [call] is `get<…Service>()` on whatever resolves a manager or a service.
bool _isGetOfService(MethodInvocation call) =>
    call.methodName.name == "get" && (call.typeArguments?.arguments.any(_isServiceType) ?? false);

/// Tell whether [target] is, by its shape, a service.
///
/// It is when it is a name that ends in `Service` or `service`, a name this file declares with a
/// service type ([declared]), `get<…Service>()`, a cast to a service, or one of those followed by
/// `!` or between parentheses. A receiver that is anything else (a function's result, an element
/// of a list, a name inferred from a call to a function of another file) is not seen, and a call
/// on it is not checked.
bool isServiceReceiver(Expression? target, Set<String> declared) {
  var isService = false;
  if (target is ParenthesizedExpression) {
    isService = isServiceReceiver(target.expression, declared);
  } else if (target is PostfixExpression && target.operator.type == TokenType.BANG) {
    isService = isServiceReceiver(target.operand, declared);
  } else if (target is AsExpression) {
    isService = _isServiceType(target.type);
  } else if (target is MethodInvocation) {
    isService = _isGetOfService(target);
  } else {
    final last = switch (target) {
      SimpleIdentifier() => target.name,
      PrefixedIdentifier() => target.identifier.name,
      PropertyAccess() => target.propertyName.name,
      _ => null,
    };
    isService =
        last != null &&
        (last.endsWith(_serviceSuffix) ||
            last.endsWith(_serviceSuffix.toLowerCase()) ||
            declared.contains(last));
  }

  return isService;
}

/// Finds the ways a call of a converted method can lose its answer.
class CallFinder extends RecursiveAstVisitor<void> {
  /// The names of the converted methods.
  final Set<String> names;

  /// The names of the converted methods of each service class, which a call with no receiver, or
  /// on `this`, inside that class reaches.
  final Map<String, Set<String>> namesByClass;

  /// The names the file declares with the type of a service.
  final Set<String> serviceNames;

  /// The parsed file, which the parameters of a helper are looked up in.
  final CompilationUnit unit;

  /// The offending calls, as `line: reason`.
  final offences = <String>[];

  /// Turns an offset into a line.
  final int Function(int offset) lineOf;

  /// The class being read, or null outside one.
  String? _className;

  /// Class constructor
  CallFinder({
    required this.names,
    required this.namesByClass,
    required this.serviceNames,
    required this.unit,
    required this.lineOf,
  });

  /// Read the calls of a class knowing its name.
  @override
  void visitClassDeclaration(ClassDeclaration node) {
    _className = node.namePart.typeName.lexeme;
    super.visitClassDeclaration(node);
    _className = null;
  }

  /// Check how a call of a converted method is used.
  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (_isConvertedCall(node)) {
      final reason = _misuseOf(node);
      if (reason != null) {
        _report(node, "${node.methodName.name} $reason");
      }
    }
    super.visitMethodInvocation(node);
  }

  /// Refuse the tear-off of a converted method written `service.method`.
  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    if (node.parent is! CommentReference &&
        names.contains(node.identifier.name) &&
        isServiceReceiver(node.prefix, serviceNames)) {
      _report(node, "${node.identifier.name} is torn off: call it, so its answer is read");
    }
    super.visitPrefixedIdentifier(node);
  }

  /// Refuse the tear-off of a converted method written `a.service.method`.
  @override
  void visitPropertyAccess(PropertyAccess node) {
    final target = node.target;
    if (node.parent is! CommentReference &&
        names.contains(node.propertyName.name) &&
        isServiceReceiver(target, serviceNames)) {
      _report(node, "${node.propertyName.name} is torn off: call it, so its answer is read");
    }
    super.visitPropertyAccess(node);
  }

  /// Check that the answer kept in a variable is checked before its value is read.
  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    var initializer = node.initializer;
    while (initializer is ParenthesizedExpression) {
      initializer = initializer.expression;
    }
    final call = initializer is AwaitExpression ? _stripParentheses(initializer.expression) : null;
    final block = node.parent?.parent?.parent;
    if (call is MethodInvocation && _isConvertedCall(call) && block is Block) {
      final reader = _AnswerReader(variable: node.name.lexeme);
      block.accept(reader);
      for (final read in reader.valueReadsBeforeAnyCheck) {
        _report(read, "answer '${node.name.lexeme}' has its value read before isError or status");
      }
    }
    super.visitVariableDeclaration(node);
  }

  /// Add the offence for [node].
  void _report(AstNode node, String reason) {
    offences.add("${lineOf(node.offset)}: $reason");
  }

  /// Tell whether [call] is a call of a converted method on a service.
  bool _isConvertedCall(MethodInvocation call) {
    final name = call.methodName.name;
    final target = call.target;
    var isConverted = false;
    if (names.contains(name)) {
      isConverted = target == null || target is ThisExpression
          ? (namesByClass[_className]?.contains(name) ?? false)
          : isServiceReceiver(target, serviceNames) && !_isHomonymReceiver(name, target);
    }

    return isConverted;
  }

  /// Tell whether [target] is a receiver that reaches a participant called [name].
  bool _isHomonymReceiver(String name, Expression target) {
    final last = switch (target) {
      SimpleIdentifier() => target.name,
      PrefixedIdentifier() => target.identifier.name,
      PropertyAccess() => target.propertyName.name,
      _ => null,
    };

    return last != null && (homonymReceivers[name]?.contains(last) ?? false);
  }

  /// Say why [call] loses its answer, or null when it is used.
  String? _misuseOf(MethodInvocation call) {
    final inTransaction = _isInTransaction(call);
    AstNode child = call;
    var parent = call.parent;
    while (parent is ParenthesizedExpression) {
      child = parent;
      parent = parent.parent;
    }

    String? reason;
    if (parent is MethodInvocation && identical(parent.target, child)) {
      reason = _chainedProblem(parent, inTransaction: inTransaction);
    } else if (inTransaction) {
      reason = "is called inside a transaction without okOrAbort or valueOrAbort";
    } else if (parent is AwaitExpression) {
      reason = _awaitedProblem(parent);
    } else if (parent is ReturnStatement || parent is ExpressionFunctionBody) {
      reason = _returnedProblem(parent!);
    } else {
      reason = "is not awaited: the future is stored, passed on or dropped";
    }

    return reason;
  }

  /// Say why a call followed by [chain] loses its answer, or null.
  String? _chainedProblem(MethodInvocation chain, {required bool inTransaction}) {
    final name = chain.methodName.name;
    String? reason;
    if (!_abortHelpers.contains(name)) {
      reason = "is chained with $name: await it and read its answer";
    } else if (!inTransaction && !_isInAllowedGuardBody(chain)) {
      reason = "is wrapped by $name outside a transaction, where nothing catches the abort";
    } else {
      var consumer = chain.parent;
      while (consumer is ParenthesizedExpression) {
        consumer = consumer.parent;
      }
      final isHandedOn = consumer is ExpressionFunctionBody || consumer is ReturnStatement;
      if (consumer is! AwaitExpression && !isHandedOn) {
        reason = "is wrapped by $name but not awaited";
      }
    }

    return reason;
  }

  /// Say why a call [awaited] loses its answer, or null.
  String? _awaitedProblem(AwaitExpression awaited) {
    AstNode child = awaited;
    var consumer = awaited.parent;
    while (consumer is ParenthesizedExpression) {
      child = consumer;
      consumer = consumer.parent;
    }

    String? reason;
    if (consumer is ExpressionStatement) {
      reason = "is awaited and its result dropped";
    } else if (consumer is PropertyAccess &&
        identical(consumer.target, child) &&
        consumer.propertyName.name == "value") {
      reason = "has its value read straight off the answer: read isError or status first";
    } else if (consumer is ReturnStatement || consumer is ExpressionFunctionBody) {
      reason = _returnedProblem(consumer!);
    }

    return reason;
  }

  /// Say why a call returned by [returned] loses its answer, or null when whoever receives the
  /// future is declared to take a result.
  String? _returnedProblem(AstNode returned) {
    var function = returned.parent;
    while (function != null && function is! FunctionExpression && function is! MethodDeclaration) {
      function = function.parent;
    }

    String? reason;
    if (function is MethodDeclaration) {
      reason = _namesResultReturn(function.returnType) ? null : _notAResultMethod;
    } else if (function is FunctionExpression) {
      final declaration = function.parent;
      reason = declaration is FunctionDeclaration
          ? (_namesResultReturn(declaration.returnType) ? null : _notAResultMethod)
          : _closureProblem(function);
    } else {
      reason = _notAResultMethod;
    }

    return reason;
  }

  /// Say why a call returned by a closure loses its answer, or null.
  String? _closureProblem(FunctionExpression closure) {
    var parent = closure.parent;
    String? label;
    if (parent is NamedExpression) {
      label = parent.name.label.name;
      parent = parent.parent;
    }

    String? reason =
        "is returned by a closure that is not handed to a helper declared to take a result";
    if (parent is ArgumentList) {
      final invocation = parent.parent;
      final helper = invocation is MethodInvocation ? invocation.methodName.name : null;
      if (helper != null) {
        final position = parent.arguments.indexWhere(
          (argument) =>
              identical(argument is NamedExpression ? argument.expression : argument, closure),
        );
        if (helpersTakingAResult.contains(helper) ||
            _parameterNamesResult(helper, label: label, position: position)) {
          reason = null;
        }
      }
    } else if (parent is VariableDeclaration) {
      final list = parent.parent;
      if (list is VariableDeclarationList && _namesResultType(list.type?.toSource())) {
        reason = null;
      }
    }

    return reason;
  }

  /// Tell whether every function, method or constructor of this file called [helper] declares
  /// the parameter that [label] or [position] designates with a type naming a result.
  bool _parameterNamesResult(String helper, {String? label, required int position}) {
    final finder = _ParameterTypeFinder(helper: helper, label: label, position: position);
    unit.accept(finder);

    return finder.types.isNotEmpty && finder.types.every(_namesResultType);
  }

  /// Tell whether [node] sits in the closure handed to `guardResult` or `guardOutcome`, which
  /// catch an abort and answer its failure, inside one of the [abortInGuardBodyMethods].
  bool _isInAllowedGuardBody(AstNode node) {
    var isIn = false;
    var current = node.parent;
    while (current != null && !isIn) {
      if (current is FunctionExpression) {
        var holder = current.parent;
        if (holder is NamedExpression) {
          holder = holder.parent;
        }
        final invocation = holder is ArgumentList ? holder.parent : null;
        isIn =
            invocation is MethodInvocation &&
            const {"guardResult", "guardOutcome"}.contains(invocation.methodName.name) &&
            abortInGuardBodyMethods.containsKey(
              invocation.thisOrAncestorOfType<MethodDeclaration>()?.name.lexeme,
            );
      }
      current = current.parent;
    }

    return isIn;
  }

  /// Tell whether [node] is inside a closure handed to a call named `transaction`, or inside a
  /// method that takes the caller's `stamps`, which runs inside its caller's transaction.
  bool _isInTransaction(AstNode node) {
    var isIn = false;
    var current = node.parent;
    while (current != null && !isIn) {
      if (current is FunctionExpression) {
        var holder = current.parent;
        if (holder is NamedExpression) {
          holder = holder.parent;
        }
        final invocation = holder is ArgumentList ? holder.parent : null;
        isIn = invocation is MethodInvocation && invocation.methodName.name == "transaction";
      } else if (current is MethodDeclaration) {
        isIn =
            current.parameters?.parameters.any((parameter) => parameter.name?.lexeme == "stamps") ??
            false;
      }
      current = current.parent;
    }

    return isIn;
  }
}

/// Why a returned call loses its answer when the method does not declare a result.
const _notAResultMethod = "is returned by a method whose declared type is not a result";

/// Tell whether [type]'s source starts like a result a caller must read.
bool _namesResultReturn(TypeAnnotation? type) {
  final source = type?.toSource() ?? "";

  return _resultReturnTypes.any(source.startsWith);
}

/// Tell whether [source], a type, names one of the result types.
bool _namesResultType(String? source) =>
    source != null && _resultTypeNames.any((name) => source.contains(name));

/// Remove the parentheses around [expression].
Expression _stripParentheses(Expression expression) {
  var stripped = expression;
  while (stripped is ParenthesizedExpression) {
    stripped = stripped.expression;
  }

  return stripped;
}

/// Finds the declared type of the parameter of the functions called [helper] that a closure is
/// handed to.
class _ParameterTypeFinder extends RecursiveAstVisitor<void> {
  /// The name of the function, method or class looked for.
  final String helper;

  /// The name of the named parameter, or null for a positional one.
  final String? label;

  /// The index of the argument, for a positional one.
  final int position;

  /// The source of the type of every matching parameter found.
  final types = <String?>[];

  /// The class being read, for a field-formal parameter.
  ClassDeclaration? _class;

  /// Class constructor
  _ParameterTypeFinder({required this.helper, required this.label, required this.position});

  /// Remember the class so a parameter that sets a field finds the field's type.
  @override
  void visitClassDeclaration(ClassDeclaration node) {
    _class = node;
    super.visitClassDeclaration(node);
    _class = null;
  }

  /// Read the parameters of a method of that name.
  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (node.name.lexeme == helper) {
      _read(node.parameters);
    }
    super.visitMethodDeclaration(node);
  }

  /// Read the parameters of a function of that name.
  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    if (node.name.lexeme == helper) {
      _read(node.functionExpression.parameters);
    }
    super.visitFunctionDeclaration(node);
  }

  /// Read the parameters of the unnamed constructor of a class of that name.
  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {
    if (node.name == null && _class?.namePart.typeName.lexeme == helper) {
      _read(node.parameters);
    }
    super.visitConstructorDeclaration(node);
  }

  /// Record the type of the parameter [list] designates.
  void _read(FormalParameterList? list) {
    final parameters = list?.parameters ?? <FormalParameter>[];
    FormalParameter? found;
    if (label != null) {
      found = parameters.where((parameter) => parameter.name?.lexeme == label).firstOrNull;
    } else {
      final positional = parameters.where((parameter) => parameter.isPositional).toList();
      found = position >= 0 && position < positional.length ? positional[position] : null;
    }
    if (found != null) {
      types.add(_typeOf(found));
    }
  }

  /// Get the source of the type [parameter] is declared with.
  String? _typeOf(FormalParameter parameter) {
    final inner = parameter is DefaultFormalParameter ? parameter.parameter : parameter;
    String? source;
    if (inner is SimpleFormalParameter) {
      source = inner.type?.toSource();
    } else if (inner is FunctionTypedFormalParameter) {
      source = inner.returnType?.toSource();
    } else if (inner is FieldFormalParameter) {
      source = inner.type?.toSource() ?? _fieldTypeOf(inner.name.lexeme);
    }

    return source;
  }

  /// Get the source of the type of the field [name] of the class being read.
  String? _fieldTypeOf(String name) {
    final body = _class?.body;
    String? source;
    if (body is BlockClassBody) {
      for (final field in body.members.whereType<FieldDeclaration>()) {
        if (field.fields.variables.any((variable) => variable.name.lexeme == name)) {
          source = field.fields.type?.toSource();
        }
      }
    }

    return source;
  }
}

/// Reads how a variable holding an answer is used: whether its value is read before its status.
class _AnswerReader extends RecursiveAstVisitor<void> {
  /// The name of the variable.
  final String variable;

  /// The value reads that come before any read of `isError`, `isSuccess` or `status`.
  final valueReadsBeforeAnyCheck = <AstNode>[];

  /// Whether `isError`, `isSuccess` or `status` was read yet, in the order of the source.
  bool _isChecked = false;

  /// Class constructor
  _AnswerReader({required this.variable});

  /// Read `variable.isError`, `variable.status` and `variable.value`.
  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    if (node.prefix.name == variable) {
      final member = node.identifier.name;
      if (member == "isError" || member == "isSuccess" || member == "status") {
        _isChecked = true;
      } else if (member == "value" && !_isChecked) {
        valueReadsBeforeAnyCheck.add(node);
      }
    }
    super.visitPrefixedIdentifier(node);
  }
}

/// Finds the calls of a participant of a transaction, which only a service may make.
class ParticipantCallFinder extends RecursiveAstVisitor<void> {
  /// The names of the methods that take the caller's `stamps`.
  final Set<String> names;

  /// The names the file declares with the type of a service.
  final Set<String> serviceNames;

  /// The offending lines, as `line: reason`.
  final offences = <String>[];

  /// Turns an offset into a line.
  final int Function(int offset) lineOf;

  /// Class constructor
  ParticipantCallFinder({required this.names, required this.serviceNames, required this.lineOf});

  /// Refuse the call of a participant on a service, and the passing of `stamps`.
  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (names.contains(node.methodName.name) && isServiceReceiver(node.target, serviceNames)) {
      offences.add("${lineOf(node.offset)}: ${node.methodName.name} runs in a transaction");
    }
    super.visitMethodInvocation(node);
  }

  /// Refuse the passing of `stamps` to anything.
  @override
  void visitNamedExpression(NamedExpression node) {
    if (node.name.label.name == "stamps") {
      offences.add("${lineOf(node.offset)}: stamps is handed in");
    }
    super.visitNamedExpression(node);
  }
}

/// Parse [source] the way the guard reads every file.
CompilationUnit parseSource(String source) =>
    parseString(content: source, featureSet: FeatureSet.latestLanguageVersion()).unit;

/// List the Dart files under [folder], sorted.
List<File> dartFilesUnder(String folder) =>
    Directory(folder)
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith(".dart") && !file.path.contains("/generated/"))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

/// Turn an offset of [unit] into a line.
int Function(int) _lineOf(CompilationUnit unit) =>
    (offset) => unit.lineInfo.getLocation(offset).lineNumber;

/// Collect the service methods of [source].
List<ServiceMethod> methodsOf(String source) {
  final collector = MethodCollector();
  parseSource(source).accept(collector);

  return collector.methods;
}

/// List the `<Class>.<member>` that hold a `try` with a `catch` clause in [source].
Set<String> catchSitesOf(String source) {
  final finder = CatchSiteFinder();
  parseSource(source).accept(finder);

  return finder.sites;
}

/// List what is wrong with the calls of the [names] methods in [source], one `line: reason` each.
///
/// [namesByClass] gives, for a call with no receiver inside a service, the methods of that
/// service that are converted.
List<String> callOffencesOf(
  Set<String> names,
  String source, {
  Map<String, Set<String>> namesByClass = const {},
}) {
  final unit = parseSource(source);
  final collector = ServiceNameCollector();
  unit.accept(collector);
  final finder = CallFinder(
    names: names,
    namesByClass: namesByClass,
    serviceNames: collector.names,
    unit: unit,
    lineOf: _lineOf(unit),
  );
  unit.accept(finder);

  return finder.offences;
}

/// List what is wrong in [source] with the calls of the [names] participants, one `line: reason`
/// each: every call of one, and every `stamps:` argument.
List<String> participantCallOffencesOf(Set<String> names, String source) {
  final unit = parseSource(source);
  final collector = ServiceNameCollector();
  unit.accept(collector);
  final finder = ParticipantCallFinder(
    names: names,
    serviceNames: collector.names,
    lineOf: _lineOf(unit),
  );
  unit.accept(finder);

  return finder.offences;
}

/// List the lines of [source] where a method of a class that extends, implements or mixes in a
/// service overrides a method named in [names] and throws.
List<int> doubleThrowsOf(Set<String> names, String source) {
  final unit = parseSource(source);
  final lines = <int>[];
  for (final declaration in unit.declarations.whereType<ClassDeclaration>()) {
    final supers = [
      declaration.extendsClause?.superclass.name.lexeme,
      ...?declaration.implementsClause?.interfaces.map((type) => type.name.lexeme),
      ...?declaration.withClause?.mixinTypes.map((type) => type.name.lexeme),
    ];
    final isDouble = supers.any(
      (name) => name != null && name.startsWith("Ocpt") && name.endsWith(_serviceSuffix),
    );
    final classBody = declaration.body;
    final members = classBody is BlockClassBody ? classBody.members : <ClassMember>[];
    for (final method in members.whereType<MethodDeclaration>()) {
      if (isDouble && names.contains(method.name.lexeme)) {
        final finder = ThrowFinder(lineOf: _lineOf(unit));
        method.body.accept(finder);
        lines.addAll(finder.lines);
      }
    }
  }

  return lines;
}

/// List the lines of [source] that name one of [names].
List<int> referencesOf(Set<String> names, String source) {
  final unit = parseSource(source);
  final finder = ReferenceFinder(names: names, lineOf: _lineOf(unit));
  unit.accept(finder);

  return finder.lines;
}

/// List the top-level class names declared in [source].
List<String> classNamesOf(String source) => [
  for (final declaration in parseSource(source).declarations.whereType<ClassDeclaration>())
    declaration.namePart.typeName.lexeme,
];

/// Tell whether the method [name] of the service class [className] in [source] says
/// `@useResult`, or null when there is no such method.
bool? hasUseResult(String source, String className, String name) {
  bool? found;
  for (final declaration in parseSource(source).declarations.whereType<ClassDeclaration>()) {
    final body = declaration.body;
    if (declaration.namePart.typeName.lexeme == className && body is BlockClassBody) {
      for (final method in body.members.whereType<MethodDeclaration>()) {
        if (method.name.lexeme == name) {
          found = method.metadata.any((annotation) => annotation.name.name == "useResult");
        }
      }
    }
  }

  return found;
}
