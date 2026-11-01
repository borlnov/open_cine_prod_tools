// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A bloc `add` checks for a handler only inside an assert: release builds drop an event no
/// handler is registered for without a word, and a unit test that dispatches to the right bloc
/// cannot see a widget that dispatches to the wrong one. This reads the source of every split
/// mode and checks that each event it dispatches reaches a bloc registering it.
///
/// It is a source scan, so it only understands the shapes the code uses: a receiver is either
/// `context.read<T>()` or a name declared as `T name` / `name = context.read<T>()`, and a bare
/// `add` is the enclosing bloc's own. A dispatch it cannot place fails the test, so a new shape
/// has to be taught here rather than slip by.
const _modes = <String, String>{
  "shot_list": "OcptShotListBloc",
  "schedule": "OcptScheduleBloc",
  "resources": "OcptResourcesBloc",
  "breakdown": "OcptBreakdownBloc",
  "budget": "OcptBudgetBloc",
};

/// The names a dispatch goes through, as a method call.
final _dispatchCall = RegExp(
  r"(\.\.?|\b)(add|addToMode|addAndWait|addToModeAndWait|addUnlessClosing|dispatchIfShotSelected)\s*\(",
);

/// An event class named in a call's arguments.
final _eventName = RegExp(r"\b(Ocpt\w*Event)\b");

/// A class or mixin declaration.
final _classDeclaration = RegExp(
  r"^(?:abstract |sealed |final |base )*(?:class|mixin)\s+(\w+)([^{]*)\{",
  multiLine: true,
);

/// A handler registration.
final _registration = RegExp(r"\b(on|onAwaited)<\s*(\w+)");

/// The text of the parenthesised group opening at [start].
String _balanced(String text, int start) {
  var depth = 0;
  for (var index = start; index < text.length; index++) {
    if (text[index] == "(") {
      depth++;
    } else if (text[index] == ")") {
      depth--;
      if (depth == 0) {
        return text.substring(start, index + 1);
      }
    }
  }
  return text.substring(start);
}

/// The body of the brace group opened by [declaration].
String _bodyOf(String text, RegExpMatch declaration) {
  var depth = 1;
  var index = declaration.end;
  while (index < text.length && depth > 0) {
    if (text[index] == "{") {
      depth++;
    } else if (text[index] == "}") {
      depth--;
    }
    index++;
  }
  return text.substring(declaration.start, index);
}

void main() {
  final root = Directory("lib");
  final sources = <String, String>{
    for (final file in root.listSync(recursive: true).whereType<File>())
      if (file.path.endsWith(".dart") && !file.path.contains("/generated/"))
        file.path: file.readAsStringSync(),
  };

  // Class name to its supertypes' names, and to the events it registers itself.
  final heads = <String, String>{};
  final registered = <String, Map<String, String>>{};
  for (final entry in sources.entries) {
    for (final declaration in _classDeclaration.allMatches(entry.value)) {
      final name = declaration.group(1)!;
      heads[name] = declaration.group(2)!;
      final own = <String, String>{
        for (final registration in _registration.allMatches(_bodyOf(entry.value, declaration)))
          registration.group(2)!: registration.group(1)!,
      };
      if (own.isNotEmpty) {
        registered[name] = own;
      }
    }
  }

  // A sealed or abstract event class is a type name in a signature, never an event on its own.
  final abstractClasses = {
    for (final text in sources.values)
      for (final match in RegExp(r"\b(?:sealed|abstract)\s+class\s+(\w+)").allMatches(text))
        match.group(1)!,
  };

  Set<String> supersOf(String name, [Set<String>? seen]) {
    final visited = seen ?? <String>{};
    if (!heads.containsKey(name) || !visited.add(name)) {
      return {};
    }
    final result = {name};
    for (final word in RegExp(r"\w+").allMatches(heads[name]!)) {
      result.addAll(supersOf(word.group(0)!, visited));
    }
    return result;
  }

  Map<String, String> registrationsOf(String bloc) => {
    for (final type in supersOf(bloc)) ...?registered[type],
  };

  String? enclosingClass(String text, int position) {
    String? last;
    for (final declaration in _classDeclaration.allMatches(text.substring(0, position))) {
      last = declaration.group(1);
    }
    return last;
  }

  String? receiverType(String text, String receiver, String mode, String file) {
    final trimmed = receiver.trim();
    final read = RegExp(r"(?:read|watch)<\s*(\w+)").firstMatch(trimmed);
    if (read != null) {
      return read.group(1);
    }
    final name = RegExp(r"(\w+)$").firstMatch(trimmed)?.group(1);
    if (name == null) {
      return null;
    }
    if (name == "modeBloc") {
      return _modes[mode];
    }
    if (name == "workspaceBloc") {
      return "OcptWorkspaceBloc";
    }
    for (final pattern in [
      RegExp(r"\b(\w+Bloc)\s+" + name + r"\b"),
      RegExp(r"\b" + name + r"\s*=\s*[\w.]*(?:read|watch)<\s*(\w+)"),
    ]) {
      final matches = pattern.allMatches(text).toList();
      if (matches.isNotEmpty) {
        return matches.first.group(1);
      }
    }
    return null;
  }

  for (final mode in _modes.keys) {
    test("every event $mode dispatches reaches a bloc registering it", () {
      final problems = <String>[];
      var checked = 0;

      for (final entry in sources.entries) {
        if (!entry.key.contains("/modes/$mode/")) {
          continue;
        }
        final text = entry.value;
        for (final call in _dispatchCall.allMatches(text)) {
          final method = call.group(2)!;
          final arguments = _balanced(text, call.end - 1);
          final events = _eventName
              .allMatches(arguments)
              .map((m) => m.group(1)!)
              .toSet()
              .difference(abstractClasses);
          if (events.isEmpty) {
            continue;
          }
          final line = text.substring(0, call.start).split("\n").length;
          final where = "${entry.key}:$line";

          String? bloc;
          if (method == "dispatchIfShotSelected") {
            bloc = "OcptShotListInspectorBloc";
          } else if (method == "addToMode" ||
              method == "addAndWait" ||
              method == "addToModeAndWait") {
            bloc = _modes[mode];
          } else if (call.group(1)!.isEmpty) {
            bloc = enclosingClass(text, call.start);
          } else {
            final before = text.substring(0, call.start);
            var statement = before.substring(
              [before.lastIndexOf(";"), before.lastIndexOf("{")].reduce((a, b) => a > b ? a : b) +
                  1,
            );
            if (call.group(1) == "..") {
              statement = statement.split("..").first;
            } else {
              statement = before.substring(before.length > 120 ? before.length - 120 : 0);
            }
            bloc = receiverType(text, statement, mode, entry.key);
          }

          for (final event in events) {
            checked++;
            if (bloc == null) {
              problems.add("$where: cannot tell which bloc receives $event");
              continue;
            }
            final handler = registrationsOf(bloc)[event];
            if (handler == null) {
              problems.add("$where: $bloc registers no handler for $event");
            } else if ((method == "addAndWait" || method == "addToModeAndWait") &&
                handler != "onAwaited") {
              problems.add("$where: $event is waited on but $bloc registers it with a plain on");
            }
          }
        }
      }

      expect(checked, greaterThan(0));
      expect(problems, isEmpty);
    });
  }
}
