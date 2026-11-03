// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'service_result_answer_rules.dart';
import 'service_result_rules.dart';

/// The members of `lib/ui` that answer a result and are not marked `@useResult` on purpose, each
/// with its reason.
const _unmarkedResultMembers = {
  "AbsOcptViewBloc.flushEditsWithoutStateUntilConverted":
      "the views that still use it write a call that answers nothing, and ignore what it answers; "
      "it goes with the last of them",
};

/// The helpers that carry a stop without declaring a result in their type: they answer whether the
/// caller may go on, and a caller that drops the answer goes on after a failure.
const _stopCarriers = {
  "lib/ui/pages/workspace/modes/schedule/schedule_bloc.dart": {
    "_load",
    "_applyScheduleSnapshot",
    "_flushAllPendingWrites",
  },
  "lib/ui/pages/workspace/modes/budget/budget_bloc.dart": {
    "_load",
    "_readBudgetSnapshot",
    "_flushAllPendingWrites",
  },
  "lib/ui/pages/workspace/modes/shot_list/shot_list_bloc.dart": {"_load"},
  "lib/ui/pages/workspace/modes/resources/resources_bloc.dart": {"_load"},
  "lib/ui/pages/workspace/modes/breakdown/breakdown_bloc.dart": {"_load"},
  "lib/ui/pages/editor/editor_bloc.dart": {"_load"},
  "lib/ui/pages/workspace/blocs/mixin_ocpt_project_versions_bloc.dart": {
    "_captureWorkingCopyState",
  },
  "lib/managers/projects/ocpt_projects_manager.dart": {
    "listProjectVersions",
    "createProjectVersion",
    "renameProjectVersion",
    "captureWorkingCopyState",
    "deleteProjectVersion",
    "restoreProjectVersion",
    "exitPreview",
    "closeCurrentProject",
    "recordCurrentProjectEpisodeCount",
  },
  "lib/managers/projects/ocpt_project_episode_ops.dart": {
    "closeProject",
    "recordOpenProjectEpisodeCount",
  },
};

/// List a file's lines of offences as `path:line: reason`.
List<String> _prefixed(String path, Iterable<String> offences) => [
  for (final offence in offences) "$path:$offence",
];

/// Guard what is done with the answers that sit between a service and a handler.
///
/// The rules read the syntax of a file and resolve no type. What they cannot see is said in the
/// last test of the group of checks at the end.
void main() {
  final libFiles = dartFilesUnder("lib");
  final resultMembers = <String>{};
  final databaseMembers = <String>{};
  for (final file in libFiles) {
    final source = file.readAsStringSync();
    resultMembers.addAll(resultMembersOf(source));
    databaseMembers.addAll(databaseResultMembersOf(source));
  }

  test("the members answering a result were found", () {
    expect(resultMembers, containsAll(["guardResult", "load", "loadSnapshot", "pullAndApply"]));
  });

  test("every member of the UI that answers a result says @useResult", () {
    final offences = <String>[];
    for (final file in dartFilesUnder("lib/ui")) {
      for (final offence in unannotatedResultMembersOf(file.readAsStringSync())) {
        if (!_unmarkedResultMembers.keys.any(offence.endsWith)) {
          offences.add("${file.path}:$offence");
        }
      }
    }

    expect(offences, isEmpty);
  });

  test("an unmarked member that is listed is still one", () {
    final unannotated = [
      for (final file in dartFilesUnder("lib/ui"))
        ...unannotatedResultMembersOf(file.readAsStringSync()),
    ];

    for (final listed in _unmarkedResultMembers.keys) {
      expect(unannotated.where((offence) => offence.endsWith(listed)), isNotEmpty, reason: listed);
    }
  });

  test("every helper that carries a stop says @useResult", () {
    _stopCarriers.forEach((path, wanted) {
      final (found, unannotated) = namedMembersOf(wanted, File(path).readAsStringSync());

      expect(found, wanted, reason: "$path declares them all.");
      expect(unannotated, isEmpty, reason: path);
    });
  });

  test("an answer is checked before its value is read, and an if on a failure leaves", () {
    final offences = <String>[];
    for (final file in libFiles) {
      offences.addAll(
        _prefixed(
          file.path,
          answerUseOffencesOf(
            resultMembers,
            file.readAsStringSync(),
            databaseNames: databaseMembers,
          ),
        ),
      );
    }

    expect(offences, isEmpty);
  });

  group("the checks themselves", () {
    test("a member answering a result without @useResult is found, and one with it is not", () {
      const source = '''
class Bloc {
  Future<OcptDatabaseOutcome> bare() async {}
  @useResult
  Future<OcptDatabaseOutcome> marked() async {}
  Future<OcptDatabaseResult<int>> bareRead() async {}
  ResultWithStatus<Foo, int> bareSync() {}
  Future<bool> notAResult() async {}
}
Future<OcptDatabaseOutcome> bareFunction() async {}
@useResult
Future<OcptDatabaseOutcome> markedFunction() async {}
''';

      expect(unannotatedResultMembersOf(source), [
        "2: Bloc.bare",
        "5: Bloc.bareRead",
        "6: Bloc.bareSync",
        "9: bareFunction",
      ]);
      expect(resultMembersOf(source), {
        "bare",
        "marked",
        "bareRead",
        "bareSync",
        "bareFunction",
        "markedFunction",
      });
    });

    test("a named member without @useResult is found, and one with it is not", () {
      const source = '''
class Bloc {
  Future<bool> _load() async => true;
  @useResult
  Future<bool> _apply() async => true;
}
''';

      final (found, unannotated) = namedMembersOf({"_load", "_apply", "_missing"}, source);

      expect(found, {"_load", "_apply"});
      expect(unannotated, ["_load"]);
    });

    test("a database value read before any check, and an answer never checked, are found", () {
      const source = '''
Future<void> f() async {
  final early = await loader.load(project);
  final id = early.value;
  final never = await loader.load(project);
  final status = await loader.load(project);
  if (status.status.isSuccess) { final v = status.value; }
  final checked = await loader.load(project);
  if (checked.isError) { return; }
  final v2 = checked.value;
  final passed = await loader.load(project);
  return passed;
  final forwarded = await loader.load(project);
  consume(forwarded);
  final other = await elsewhere.fetch(project);
  final nullAware = await loader.load(project);
  final w = nullAware?.value;
  final _ = await loader.load(project);
}
''';

      final offences = answerUseOffencesOf({"load"}, source, databaseNames: {"load"});

      expect(offences.map((offence) => offence.split(":").first), ["3", "4", "16"]);
    });

    test("the idiom of a value tested for null, then a status read, passes for a plain result", () {
      const source = '''
Future<void> f() async {
  final payloadResult = await versions.loadPayload(id);
  final payload = payloadResult.value;
  if (payload == null) {
    return payloadResult.status;
  }
}
''';

      expect(answerUseOffencesOf({"loadPayload"}, source), isEmpty);
      expect(
        answerUseOffencesOf({"loadPayload"}, source, databaseNames: {"loadPayload"}),
        hasLength(1),
      );
    });

    test("an if on a failure must end with a way out or the assignment of a flag", () {
      const source = '''
Future<void> f() async {
  for (;;) {
    if (a.isError) { log(); }
    if (b.isError) { return; }
    if (c.isError || c.value == null) { throw StateError("x"); }
    if (d.isError) { failed = true; }
    if (e.isError) { break; }
    if (g.isError) { emit(failed); }
    if (h.isError) {}
    if (i.isError) log();
    if (j.isError) return;
    if (k.isError) { emit(failed); } else { go(); }
    if (!l.isError) { go(); }
    if (m.isSuccess) { go(); }
    if (n.isError && o) { go(); }
    if (p.isError) { continue; }
  }
}
''';

      final offences = answerUseOffencesOf({"nothing"}, source);

      expect(offences.map((offence) => offence.split(":").first), ["3", "8", "9", "10"]);
    });

    test("the rules see a call only through the name of the member", () {
      // What the syntax cannot tell: a result obtained through a function the file does not name,
      // a member of the same name on another type, a result held in a field and a check made in
      // another function are not seen, and an answer read inside a closure counts as checked.
      const source = '''
Future<void> f() async {
  final viaAlias = await alias();
  final id = viaAlias.value;
  final field = await this.other.fetch();
  final lazy = await loader.load(project);
  items.forEach((item) { if (lazy.isError) { return; } });
  final read = lazy.value;
}
''';

      expect(answerUseOffencesOf({"load"}, source), isEmpty);
    });
  });
}
