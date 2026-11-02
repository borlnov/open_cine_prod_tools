// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:flutter_test/flutter_test.dart';

import 'service_result_inventory.dart';

/// The folder of the project services, and of the `Ops` and `Rows` classes that run inside their
/// boundary.
const _servicesFolder = "lib/managers/projects/services";

/// The services outside that folder that answer through the same boundary.
const _extraServiceFiles = ["lib/managers/sync/services/ocpt_merge_service.dart"];

/// The names of the life cycle methods, which stay as they are.
const _lifeCycleMethods = {"initLifeCycle", "disposeLifeCycle"};

/// The names of the two helpers a converted method hands its whole body to.
const _guardHelpers = {"guardResult", "guardOutcome"};

/// The start of a return type that is a result a caller must read.
const _resultTypes = [
  "Future<OcptDatabaseResult<",
  "Future<OcptDatabaseOutcome>",
  "Future<ResultWithStatus<",
  "Future<StatusWithExtraInfo<",
];

/// A service method as the guard sees it.
class _ServiceMethod {
  /// What names the method in the inventory: `<Class>.<method>`.
  final String id;

  /// The method's name.
  final String name;

  /// Whether it is converted: it answers a result, says `@useResult`, and its body is a single
  /// expression handed to the guard.
  final bool isConverted;

  /// Whether it has a `try` with a `catch` clause.
  final bool hasCatch;

  /// Whether it takes the caller's `stamps`, so runs inside the caller's transaction and stays
  /// raising.
  final bool isParticipant;

  /// Whether it carries `@useResult`.
  final bool hasUseResult;

  /// Class constructor
  const _ServiceMethod({
    required this.id,
    required this.name,
    required this.isConverted,
    required this.hasCatch,
    required this.isParticipant,
    required this.hasUseResult,
  });
}

/// Finds whether a body holds a `try` statement with a `catch` clause.
class _CatchFinder extends RecursiveAstVisitor<void> {
  /// Whether one was found.
  bool hasCatch = false;

  /// Remember a `try` that has a `catch` clause.
  @override
  void visitTryStatement(TryStatement node) {
    if (node.catchClauses.isNotEmpty) {
      hasCatch = true;
    }
    super.visitTryStatement(node);
  }
}

/// Finds the `throw` expressions of a body.
class _ThrowFinder extends RecursiveAstVisitor<void> {
  /// The line of every `throw` found.
  final lines = <int>[];

  /// Turns an offset into a line.
  final int Function(int offset) lineOf;

  /// Class constructor
  _ThrowFinder({required this.lineOf});

  /// Record the line of the `throw`.
  @override
  void visitThrowExpression(ThrowExpression node) {
    lines.add(lineOf(node.offset));
    super.visitThrowExpression(node);
  }
}

/// Collects the service methods of a parsed file.
class _MethodCollector extends RecursiveAstVisitor<void> {
  /// The methods found.
  final methods = <_ServiceMethod>[];

  /// Class constructor
  _MethodCollector();

  /// Look at the methods of a class that extends `AbsOcptService`.
  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final body = node.body;
    if (node.extendsClause?.superclass.name.lexeme == "AbsOcptService" && body is BlockClassBody) {
      for (final member in body.members.whereType<MethodDeclaration>()) {
        final method = _describe(node.namePart.typeName.lexeme, member);
        if (method != null) {
          methods.add(method);
        }
      }
    }
    super.visitClassDeclaration(node);
  }

  /// Describe [member] when it is a public instance method that returns a `Future`.
  _ServiceMethod? _describe(String className, MethodDeclaration member) {
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
    final isParticipant = parameters.any((parameter) => parameter.name?.lexeme == "stamps");
    final hasUseResult = member.metadata.any((annotation) => annotation.name.name == "useResult");
    final body = member.body;
    final expression = body is ExpressionFunctionBody ? body.expression : null;
    final isGuarded =
        expression is MethodInvocation &&
        _guardHelpers.contains(expression.methodName.name) &&
        (expression.target == null || expression.target is ThisExpression);
    final finder = _CatchFinder();
    body.accept(finder);

    return _ServiceMethod(
      id: "$className.$name",
      name: name,
      isConverted: _resultTypes.any(returnType.startsWith) && hasUseResult && isGuarded,
      hasCatch: finder.hasCatch,
      isParticipant: isParticipant,
      hasUseResult: hasUseResult,
    );
  }
}

/// Finds the calls of converted methods that can lose their result.
class _CallFinder extends RecursiveAstVisitor<void> {
  /// The names of the converted methods.
  final Set<String> names;

  /// The offending calls, as `line: reason`.
  final offences = <String>[];

  /// Turns an offset into a line.
  final int Function(int offset) lineOf;

  /// Class constructor
  _CallFinder({required this.names, required this.lineOf});

  /// Check how the call of a converted method on a service is used.
  @override
  void visitMethodInvocation(MethodInvocation node) {
    final target = node.target?.toSource() ?? "";
    final isServiceCall =
        names.contains(node.methodName.name) &&
        (target.endsWith("Service") || target.endsWith("service"));
    if (isServiceCall) {
      final reason = _misuseOf(node);
      if (reason != null) {
        offences.add("${lineOf(node.offset)}: ${node.methodName.name} $reason");
      }
    }
    super.visitMethodInvocation(node);
  }

  /// Say why the call loses its result, or null when it is used.
  String? _misuseOf(MethodInvocation call) {
    var parent = call.parent;
    while (parent is ParenthesizedExpression) {
      parent = parent.parent;
    }

    String? reason;
    if (parent is AwaitExpression) {
      var consumer = parent.parent;
      while (consumer is ParenthesizedExpression) {
        consumer = consumer.parent;
      }
      if (consumer is ExpressionStatement) {
        reason = "is awaited and its result dropped";
      }
    } else if (parent is MethodInvocation && parent.target == call) {
      reason = parent.methodName.name == "then" ? null : "is chained other than with then";
    } else if (parent is! ExpressionFunctionBody && parent is! ReturnStatement) {
      reason = "is not awaited: the future is stored, passed on or dropped";
    }

    return reason;
  }
}

/// Finds the references to some class names.
class _ReferenceFinder extends RecursiveAstVisitor<void> {
  /// The names looked for.
  final Set<String> names;

  /// The lines where one was named.
  final lines = <int>[];

  /// Turns an offset into a line.
  final int Function(int offset) lineOf;

  /// Class constructor
  _ReferenceFinder({required this.names, required this.lineOf});

  /// Record a use of one of the names.
  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (names.contains(node.name)) {
      lines.add(lineOf(node.offset));
    }
  }
}

/// Parse [source] the way the guard reads every file.
CompilationUnit _parse(String source) =>
    parseString(content: source, featureSet: FeatureSet.latestLanguageVersion()).unit;

/// List the Dart files under [folder], sorted.
List<File> _dartFilesUnder(String folder) =>
    Directory(folder)
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith(".dart") && !file.path.contains("/generated/"))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

/// Collect the service methods of [source].
List<_ServiceMethod> _methodsOf(String source) {
  final collector = _MethodCollector();
  _parse(source).accept(collector);
  return collector.methods;
}

/// List what is wrong with the calls of the [names] methods in [source].
List<String> _callOffencesOf(Set<String> names, String source) {
  final unit = _parse(source);
  final finder = _CallFinder(
    names: names,
    lineOf: (offset) => unit.lineInfo.getLocation(offset).lineNumber,
  );
  unit.accept(finder);
  return finder.offences;
}

/// List the lines of [source] where a method of a class extending a service named in [names]
/// overrides a converted method and throws.
List<int> _doubleThrowsOf(Set<String> names, String source) {
  final unit = _parse(source);
  final lines = <int>[];
  for (final declaration in unit.declarations.whereType<ClassDeclaration>()) {
    final superName = declaration.extendsClause?.superclass.name.lexeme ?? "";
    if (!superName.startsWith("Ocpt") || !superName.endsWith("Service")) {
      continue;
    }
    final classBody = declaration.body;
    final members = classBody is BlockClassBody ? classBody.members : <ClassMember>[];
    for (final method in members.whereType<MethodDeclaration>()) {
      if (names.contains(method.name.lexeme)) {
        final finder = _ThrowFinder(
          lineOf: (offset) => unit.lineInfo.getLocation(offset).lineNumber,
        );
        method.body.accept(finder);
        lines.addAll(finder.lines);
      }
    }
  }
  return lines;
}

/// Guard the shape of the project services' answers.
///
/// Every public method of a service that returns a `Future` either answers a result, says
/// `@useResult` and hands its whole body to `guardResult` or `guardOutcome`, or takes the caller's
/// `stamps` and stays inside the caller's transaction. No call of such a method may lose its
/// result, and a test double does not throw from an override of one. Until every service is
/// converted, [pendingServiceMethods] lists what is not yet: a method that is converted but still
/// listed fails, and so does one that is neither converted nor listed.
void main() {
  final serviceFiles = [
    for (final file in _dartFilesUnder(_servicesFolder))
      if (file.path.endsWith("_service.dart")) file,
    for (final path in _extraServiceFiles) File(path),
  ];
  final methods = [for (final file in serviceFiles) ..._methodsOf(file.readAsStringSync())];
  final converted = methods.where((method) => method.isConverted).toList();
  final convertedNames = {for (final method in converted) method.name};

  test("the service sources were found", () {
    expect(serviceFiles, isNotEmpty);
    expect(methods, isNotEmpty);
  });

  test("every service method is converted, a participant, or listed as pending", () {
    final unconverted = {
      for (final method in methods)
        if (!method.isConverted && !method.isParticipant) method.id,
      for (final method in methods)
        if (method.hasCatch) "catch:${method.id}",
    };
    final pending = pendingServiceMethods;

    final unlisted = (unconverted.toList()..sort()).where((id) => !pending.contains(id));
    final stale = (pending.toList()..sort()).where((id) => !unconverted.contains(id));
    expect(
      unlisted,
      isEmpty,
      reason:
          "These service methods are neither converted nor listed as pending:\n"
          "${unlisted.map((id) => "  '$id',").join("\n")}",
    );
    expect(
      stale,
      isEmpty,
      reason:
          "These entries are listed as pending but no longer are, remove them:\n"
          "${stale.map((id) => "  '$id',").join("\n")}",
    );
  });

  test("a participant, which raises inside the caller's transaction, is not marked", () {
    final marked = [
      for (final method in methods)
        if (method.isParticipant && method.hasUseResult) method.id,
    ];
    expect(marked, isEmpty);
  });

  test("no call of a converted method loses its result", () {
    final offences = <String>[];
    for (final file in _dartFilesUnder("lib")) {
      if (file.path.startsWith("$_servicesFolder/")) {
        continue;
      }
      for (final offence in _callOffencesOf(convertedNames, file.readAsStringSync())) {
        offences.add("${file.path}:$offence");
      }
    }
    expect(offences, isEmpty);
  });

  test("no test double throws from an override of a converted method", () {
    final offences = <String>[];
    for (final file in _dartFilesUnder("test")) {
      for (final line in _doubleThrowsOf(convertedNames, file.readAsStringSync())) {
        offences.add("${file.path}:$line");
      }
    }
    expect(offences, isEmpty, reason: "A double answers a failure status instead of throwing.");
  });

  test("the Ops and Rows classes are named only inside the services folder", () {
    final names = <String>{};
    for (final file in _dartFilesUnder(_servicesFolder)) {
      final isHelper = file.path.endsWith("_ops.dart") || file.path.endsWith("_rows.dart");
      if (isHelper) {
        for (final declaration in _parse(file.readAsStringSync()).declarations) {
          if (declaration is ClassDeclaration) {
            names.add(declaration.namePart.typeName.lexeme);
          }
        }
      }
    }

    final offences = <String>[];
    for (final file in _dartFilesUnder("lib")) {
      if (file.path.startsWith("$_servicesFolder/")) {
        continue;
      }
      final unit = _parse(file.readAsStringSync());
      final finder = _ReferenceFinder(
        names: names,
        lineOf: (offset) => unit.lineInfo.getLocation(offset).lineNumber,
      );
      unit.accept(finder);
      offences.addAll(finder.lines.map((line) => "${file.path}:$line"));
    }
    expect(names, isNotEmpty);
    expect(offences, isEmpty);
  });

  group("the checks themselves", () {
    const converted = '''
class OcptThingService extends AbsOcptService {
  @useResult
  Future<OcptDatabaseOutcome> write() => guardOutcome("write", () async {});

  @useResult
  Future<OcptDatabaseResult<String>> read() async {
    return guardResult("read", () async => "a");
  }

  Future<OcptDatabaseOutcome> noAnnotation() => guardOutcome("n", () async {});

  Future<void> raises() async {
    try {
      await x();
    } catch (_) {}
  }

  Future<void> participant({required Object stamps}) async {}
}
''';

    test("a method is converted only with the result, the annotation and the guard", () {
      final found = {for (final method in _methodsOf(converted)) method.name: method};

      expect(found["write"]!.isConverted, isTrue);
      expect(found["read"]!.isConverted, isFalse, reason: "the body is not one guard expression");
      expect(found["noAnnotation"]!.isConverted, isFalse);
      expect(found["raises"]!.hasCatch, isTrue);
      expect(found["participant"]!.isParticipant, isTrue);
    });

    test("a call that loses its result is found", () {
      const source = '''
Future<void> f() async {
  await thingService.write();
  thingService.write();
  final pending = thingService.write();
  await Future.wait([thingService.write()]);
  final kept = await thingService.write();
  if ((await thingService.write()).isError) {}
  unawaited(thingService.write().then((r) {}));
}
Future<Object> relay() => thingService.write();
''';

      final offences = _callOffencesOf({"write"}, source);

      expect(offences.map((offence) => offence.split(":").first), ["2", "3", "4", "5"]);
    });

    test("a double that throws from an override of a converted method is found", () {
      const source = '''
class FailingThingService extends OcptThingService {
  @override
  Future<OcptDatabaseOutcome> write() async {
    throw StateError("failed");
  }

  @override
  Future<OcptDatabaseOutcome> other() async => throw StateError("not converted");
}
''';

      expect(_doubleThrowsOf({"write"}, source), [4]);
    });
  });
}
