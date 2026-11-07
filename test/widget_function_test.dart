// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:flutter_test/flutter_test.dart';

/// The functions and methods of `lib/` allowed to return a widget without being a widget
/// themselves, as `<file path>:<name>`, each with the reason it stays.
///
/// An `@override` is allowed without being listed: the API it implements fixes its signature (a
/// component builder's `createComponent`, say).
const _allowed = <String>{
  // A method of the context menu handler, which is not a widget: it wraps the editing surface it is
  // handed with the menu this handler owns the controller, the focus node and the spelling state
  // of, and its one caller is the styled editor that owns the handler.
  "lib/ui/pages/editor/super_editor/ocpt_styled_context_menu.dart:wrap",
};

/// The return types that make a function a widget builder, by the name they are declared with.
bool _isWidgetType(String name) => name == "Widget" || name.endsWith("Widget");

/// Collects the functions, methods, getters and local functions declared to return a widget,
/// leaving out `build` and the `@override`s.
class _WidgetFunctionFinder extends RecursiveAstVisitor<void> {
  /// The name of every offending function found.
  final offences = <String>[];

  /// Check the method.
  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    _check(
      node.returnType,
      node.name.lexeme,
      isOverride: node.metadata.any((annotation) => annotation.name.name == "override"),
    );
    super.visitMethodDeclaration(node);
  }

  /// Check the top-level or local function.
  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    _check(node.returnType, node.name.lexeme, isOverride: false);
    super.visitFunctionDeclaration(node);
  }

  /// Record [name] when [returnType] names a widget.
  void _check(TypeAnnotation? returnType, String name, {required bool isOverride}) {
    if (returnType is! NamedType || name == "build" || isOverride) {
      return;
    }

    if (_isWidgetType(returnType.name.lexeme)) {
      offences.add(name);
    }
  }
}

/// Tell whether the file builds PDF documents: the `pdf` package's own `Widget` is a layout object
/// of a document typeset once, not a Flutter widget, and has no rebuild or inspector to gain from
/// being a class of its own.
bool _isPdfFile(String source) => source.contains("package:pdf/widgets.dart");

/// A function that returns a widget is re-executed and re-allocated on every rebuild of its
/// parent and gives the widget inspector nothing to show, so what it draws is a widget of its own
/// (`StatelessWidget`) and the caller keeps the decision to show it.
///
/// This parses every Dart file of `lib/` and fails on a function, method, getter or local function
/// whose declared return type is `Widget`, `Widget?` or a type whose name ends in `Widget`, naming
/// the file and the function. It stops at what a parse can see, with no type resolution:
///
/// - a function that declares no return type, or a subclass of a Flutter widget under a name that
///   does not end in `Widget` (`Padding`, `Row`), is not seen;
/// - a function returning `List<Widget>` or menu entries is outside the rule and is not looked at;
/// - a closure handed as a `builder` has no declared type, and is not looked at;
/// - the files that build PDF documents are skipped, since the `pdf` package's `Widget` is not a
///   Flutter one.
void main() {
  final files = [
    for (final file in Directory("lib").listSync(recursive: true).whereType<File>())
      if (file.path.endsWith(".dart") &&
          !file.path.endsWith(".g.dart") &&
          !file.path.contains("/generated/"))
        file,
  ]..sort((a, b) => a.path.compareTo(b.path));

  final foundAllowed = <String>{};

  test("the sources were found", () {
    expect(files, isNotEmpty);
  });

  for (final file in files) {
    test("${file.path} has no function returning a widget", () {
      final source = file.readAsStringSync();
      if (_isPdfFile(source)) {
        return;
      }

      final parsed = parseString(content: source, featureSet: FeatureSet.latestLanguageVersion());
      final finder = _WidgetFunctionFinder();
      parsed.unit.accept(finder);

      final offences = <String>[];
      for (final name in finder.offences) {
        if (_allowed.contains("${file.path}:$name")) {
          foundAllowed.add("${file.path}:$name");
        } else {
          offences.add(name);
        }
      }

      expect(
        offences,
        isEmpty,
        reason:
            "A function returning a widget must be a widget of its own (a private "
            "StatelessWidget in the same file, or a public one under ui/widgets/ when several "
            "files draw it): $offences.",
      );
    });
  }

  test("every allowed function still exists", () {
    expect(
      _allowed.difference(foundAllowed),
      isEmpty,
      reason: "These allowed functions no longer return a widget: remove them from the list.",
    );
  });
}
