// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The file names of a bloc, or of a mixin that holds one's handlers.
final _blocFile = RegExp(r"^(.+_bloc|mixin_.*bloc.*)\.dart$");

/// A single-line instance field declaration in a class body, captured as its type and its name.
final _field = RegExp(
  r"^  (?!static |const |return |@|//)((?:late )?(?:final )?)([A-Za-z_](?:(?! get | set )[\w<>?,. ()])*?) (_?\w+)(?: = [^;]+)?;$",
);

/// The first line of a class or a mixin.
final _typeStart = RegExp("^(?:abstract |final |sealed |base )*(?:class|mixin) ");

/// The types of a resource a bloc owns and reassigns during its life: a field of one of them may be
/// reassigned.
final _resourceType = RegExp(r"^(Timer|StreamSubscription|CancelableOperation|Completer|Future)\b");

/// The collection types a `final` field is not allowed to hold, as their content would change
/// outside the state.
final _collectionType = RegExp(r"^(List|Map|Set|Queue|LinkedHashMap)\b");

/// Every field a bloc keeps outside its state although it is neither final nor a resource, with the
/// reason it cannot be in the state. The key is the file name and the field name.
///
/// Each of them is written or read where no event handler, and therefore no `emit`, is running
/// (a stream listener, `close`, an overridden `add`, a widget leaving the tree), or marks a write
/// or a closing that is in flight, which a state emitted later would report too late.
const _allowed = <String, String>{
  "editor_bloc.dart:_undeliveredText":
      "set from the overridden add, before the event reaches its handler",
  "editor_bloc.dart:_isDisposing": "set by disposeLifeCycle, outside any handler",
  "editor_spell_check_bloc.dart:_previousModeState": "set by the mode's state stream listener",
  "editor_statistics_bloc.dart:_previousModeState": "set by the mode's state stream listener",
  "breakdown_bloc.dart:_storedLastRightDockTab":
      "mirrors what was written to the preferences, ahead of the state that will carry it",
  "abs_ocpt_view_bloc.dart:_lastReloadEpoch": "set by the mode's state stream listener",
  "abs_ocpt_view_bloc.dart:_lastSelectionEpoch": "set by the mode's state stream listener",
  "abs_ocpt_view_bloc.dart:_isClosing": "set by close, which no handler runs in",
  "abs_ocpt_view_bloc.dart:_dispatchedReactions": "counted by the mode's state stream listener",
  "abs_ocpt_view_bloc.dart:_handledReactions":
      "counted around a handler that has no state of its own",
  "abs_ocpt_view_bloc.dart:_editsWrittenWithoutState":
      "written by the flush a widget leaving the tree runs, where nothing can emit",
  "mixin_ocpt_mode_bloc.dart:_isClosing": "set by close, which no handler runs in",
  "mixin_ocpt_mode_bloc.dart:_flushers": "a registry of callbacks, which a state cannot compare",
  "mixin_ocpt_mode_bloc.dart:_awaited": "a registry of completers, which a state cannot compare",
  "mixin_ocpt_project_package_bloc.dart:_isWritingProjectPackage":
      "marks the write in flight, and must hold before the first emit of the write",
  "mixin_ocpt_project_versions_bloc.dart:_lastWorkingCopyCaptureAt":
      "a throttle clock set by a capture that may emit nothing, which would make a clock tick a "
      "state change",
};

/// The field declarations of the classes and mixins of [file], as their line number and their text.
List<(int, String)> _fieldLinesOf(File file) {
  final fields = <(int, String)>[];
  final lines = file.readAsLinesSync();
  var isInType = false;
  for (var index = 0; index < lines.length; index++) {
    final line = lines[index];
    if (_typeStart.hasMatch(line)) {
      isInType = true;
    } else if (line.startsWith("}")) {
      isInType = false;
    } else if (isInType && _field.hasMatch(line)) {
      fields.add((index + 1, line));
    }
  }

  return fields;
}

/// A bloc keeps what changes during its life in its state: every instance field is `final`, or a
/// resource the bloc reassigns, and a `final` field does not hold a collection whose content
/// changes, since that is state as well. The few fields that cannot be in a state are listed above
/// with the reason.
///
/// This reads the source of every bloc under `lib/` (each `*_bloc.dart` and `mixin_*bloc*.dart`).
/// It is a source scan: a field declared over several lines is not seen.
void main() {
  final files = Directory("lib")
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => _blocFile.hasMatch(file.uri.pathSegments.last))
      .toList();

  test("the blocs were found", () {
    expect(files, isNotEmpty);
  });

  test("every field the list allows still exists", () {
    final found = <String>{};
    for (final file in files) {
      final name = file.uri.pathSegments.last;
      for (final line in _fieldLinesOf(file)) {
        found.add("$name:${_field.firstMatch(line.$2)!.group(3)}");
      }
    }
    expect(_allowed.keys.where((key) => !found.contains(key)), isEmpty);
  });

  for (final file in files) {
    final name = file.uri.pathSegments.last;
    test("$name keeps only final fields and resources", () {
      final offences = <String>[];
      for (final (number, line) in _fieldLinesOf(file)) {
        final match = _field.firstMatch(line)!;
        final modifiers = match.group(1)!;
        final type = match.group(2)!;
        final field = match.group(3)!;
        if (_allowed.containsKey("$name:$field")) {
          continue;
        }

        final isFinal = modifiers.contains("final");
        if (!isFinal && !_resourceType.hasMatch(type)) {
          offences.add("line $number: $field is neither final nor a resource");
        }
        if (isFinal && _collectionType.hasMatch(type)) {
          offences.add("line $number: $field is a final collection");
        }
      }
      expect(offences, isEmpty, reason: "Data that changes lives in the bloc's state.");
    });
  }
}
