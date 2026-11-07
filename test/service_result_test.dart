// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'service_result_inventory.dart';
import 'service_result_rules.dart';

/// The folder of the project services, and of the `Ops` and `Rows` classes that run inside their
/// boundary.
const _servicesFolder = "lib/managers/projects/services";

/// The services outside that folder that answer through the same boundary.
const _extraServiceFiles = [
  "lib/managers/sync/services/ocpt_merge_service.dart",
  "lib/managers/sync/services/ocpt_screenplay_merge_service.dart",
];

/// The files that may build an `OcptDatabaseAbort`, which are where the helpers that raise it
/// live.
const _abortFiles = [
  "lib/managers/abs_ocpt_service.dart",
  "lib/managers/ocpt_database_abort.dart",
  "lib/managers/ocpt_database_outcome_abort.dart",
  "lib/managers/ocpt_database_result_abort.dart",
];

/// The methods that answer a result of a status of their own and must still be read.
const _readOnlyResults = [
  ("lib/managers/sync/services/ocpt_merge_service.dart", "OcptMergeService", "applyChangeset"),
  (
    "lib/managers/sync/services/ocpt_changeset_service.dart",
    "OcptChangesetService",
    "pullAndApply",
  ),
  (
    "lib/managers/sync/services/ocpt_changeset_service.dart",
    "OcptChangesetService",
    "pushLocalEdits",
  ),
];

/// The first part of every line of a list of offences: its line number.
String _lineOfOffence(String offence) => offence.split(":").first;

/// Guard the shape of the project services' answers.
///
/// Every public method of a service that returns a `Future` either answers a result, says
/// `@useResult` and hands its whole body to `guardResult` or `guardOutcome`, or takes the caller's
/// `stamps` and stays inside the caller's transaction. No call of such a method may lose its
/// result, and a test double does not throw from an override of one. Until every service is
/// converted, [pendingServiceMethods] lists what is not yet and [permanentServiceExceptions] what
/// never will be: a method that is converted but still listed fails, and so does one that is
/// neither converted nor listed.
///
/// The rules read the syntax of a file and resolve no type, so a call is known to be a call of a
/// service only by the shape of its receiver: see `isServiceReceiver`. What they cannot see is
/// said where each rule is tested, in the group of checks at the end.
void main() {
  final serviceFiles = [
    for (final file in dartFilesUnder(_servicesFolder))
      if (file.path.endsWith("_service.dart")) file,
    for (final path in _extraServiceFiles) File(path),
  ];
  final catchFiles = [
    ...dartFilesUnder(_servicesFolder),
    for (final path in _extraServiceFiles) File(path),
  ];
  final methods = [for (final file in serviceFiles) ...methodsOf(file.readAsStringSync())];
  final converted = methods.where((method) => method.isConverted).toList();
  final convertedNames = {for (final method in converted) method.name};
  final convertedByClass = <String, Set<String>>{};
  for (final method in converted) {
    convertedByClass.putIfAbsent(method.className, () => {}).add(method.name);
  }
  final participantNames = {
    for (final method in methods)
      if (method.isParticipant) method.name,
  };

  test("the service sources were found", () {
    expect(serviceFiles, isNotEmpty);
    expect(methods, isNotEmpty);
  });

  test("every service method is converted, a participant, listed as pending or as permanent", () {
    final catches = <String>{};
    for (final file in catchFiles) {
      catches.addAll(catchSitesOf(file.readAsStringSync()).map((site) => "catch:$site"));
    }
    final unconverted = {
      for (final method in methods)
        if (!method.isConverted && !method.isParticipant) method.id,
      ...catches,
    };
    final expected = {...pendingServiceMethods, ...permanentServiceExceptions.keys};

    final unlisted = (unconverted.toList()..sort()).where((id) => !expected.contains(id));
    final stale = (expected.toList()..sort()).where((id) => !unconverted.contains(id));
    expect(
      unlisted,
      isEmpty,
      reason:
          "These service methods are neither converted nor listed:\n"
          "${unlisted.map((id) => "  '$id',").join("\n")}",
    );
    expect(
      stale,
      isEmpty,
      reason:
          "These entries are listed but no longer hold, remove them:\n"
          "${stale.map((id) => "  '$id',").join("\n")}",
    );
  });

  test("a method is pending or permanent, never both, and a permanent one says why", () {
    expect(
      pendingServiceMethods.where(permanentServiceExceptions.containsKey),
      isEmpty,
      reason: "A method that stays as it is is not waiting to be converted.",
    );
    expect(permanentServiceExceptions.values.where((reason) => reason.trim().isEmpty), isEmpty);
  });

  test("the participants of a transaction are the frozen list, and none is marked", () {
    final found = {
      for (final method in methods)
        if (method.isParticipant) method.id,
    };

    expect(found.difference(serviceStampParticipants), isEmpty, reason: "A new participant.");
    expect(serviceStampParticipants.difference(found), isEmpty, reason: "A stale entry.");
    expect(
      [
        for (final method in methods)
          if (method.isParticipant && method.hasUseResult) method.id,
      ],
      isEmpty,
      reason: "A participant raises inside the caller's transaction: its answer is not a result.",
    );
  });

  test("no participant of a transaction is called from the UI", () {
    final offences = <String>[];
    for (final file in dartFilesUnder("lib/ui")) {
      for (final offence in participantCallOffencesOf(participantNames, file.readAsStringSync())) {
        offences.add("${file.path}:$offence");
      }
    }

    expect(offences, isEmpty);
  });

  test("no call of a converted method loses its result", () {
    final offences = <String>[];
    for (final file in dartFilesUnder("lib")) {
      final found = callOffencesOf(
        convertedNames,
        file.readAsStringSync(),
        namesByClass: convertedByClass,
      );
      for (final offence in found) {
        offences.add("${file.path}:$offence");
      }
    }

    expect(offences, isEmpty);
  });

  test("an abort is raised by the helpers and by nothing else", () {
    final offences = <String>[];
    for (final file in dartFilesUnder("lib")) {
      if (_abortFiles.contains(file.path)) {
        continue;
      }
      for (final line in referencesOf({"OcptDatabaseAbort"}, file.readAsStringSync())) {
        offences.add("${file.path}:$line");
      }
    }

    expect(offences, isEmpty);
  });

  test("no test double throws from an override of a converted method", () {
    final offences = <String>[];
    for (final file in dartFilesUnder("test")) {
      for (final line in doubleThrowsOf(convertedNames, file.readAsStringSync())) {
        offences.add("${file.path}:$line");
      }
    }

    expect(offences, isEmpty, reason: "A double answers a failure status instead of throwing.");
  });

  test("the Ops and Rows classes are named only inside the services folder", () {
    final names = <String>{};
    for (final file in dartFilesUnder(_servicesFolder)) {
      final isHelper = file.path.endsWith("_ops.dart") || file.path.endsWith("_rows.dart");
      if (isHelper) {
        names.addAll(classNamesOf(file.readAsStringSync()));
      }
    }

    final offences = <String>[];
    for (final file in dartFilesUnder("lib")) {
      if (file.path.startsWith("$_servicesFolder/")) {
        continue;
      }
      for (final line in referencesOf(names, file.readAsStringSync())) {
        offences.add("${file.path}:$line");
      }
    }
    expect(names, isNotEmpty);
    expect(offences, isEmpty);
  });

  test("a result a service answers with a status of its own is read", () {
    for (final (path, className, name) in _readOnlyResults) {
      expect(
        hasUseResult(File(path).readAsStringSync(), className, name),
        isTrue,
        reason: "$className.$name says @useResult.",
      );
    }
  });

  group("the checks themselves", () {
    const service = '''
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
      final found = {for (final method in methodsOf(service)) method.name: method};

      expect(found["write"]!.isConverted, isTrue);
      expect(found["read"]!.isConverted, isFalse, reason: "the body is not one guard expression");
      expect(found["noAnnotation"]!.isConverted, isFalse);
      expect(found["participant"]!.isParticipant, isTrue);
      expect(found["write"]!.id, "OcptThingService.write");
    });

    test("a call that loses its result is found, and a call that reads it is not", () {
      const source = '''
Future<void> f() async {
  await thingService.write();
  thingService.write();
  final pending = thingService.write();
  await Future.wait([thingService.write()]);
  final kept = await thingService.write();
  if ((await thingService.write()).isError) {}
  unawaited(thingService.write().then((r) {}));
  await other.write();
}
''';

      final offences = callOffencesOf({"write"}, source);

      expect(offences.map(_lineOfOffence), ["2", "3", "4", "5", "8"]);
    });

    test("a converted call returned by a closure is found unless its helper takes a result", () {
      const source = '''
Future<void> f() async {
  await voidHelper(action: (p) => thingService.write());
  await resultHelper(action: (p) => thingService.write());
  await positionalHelper((p) => thingService.write());
  await elsewhere((p) => thingService.write());
  await voidHelper(action: (p) async { return await thingService.write(); });
  await resultHelper(action: (p) async { return await thingService.write(); });
  final typed = () => thingService.write();
  final Future<OcptDatabaseOutcome> Function() annotated = () => thingService.write();
  await Holder(action: (p) => thingService.write());
  await ResultHolder(action: (p) => thingService.write());
}
Future<OcptDatabaseOutcome> relay() => thingService.write();
Future<void> badRelay() => thingService.write();
Future<OcptDatabaseResult<int>> blockRelay() async {
  return thingService.write();
}
Future<void> blockBadRelay() async {
  return await thingService.write();
}
Future<void> voidHelper({required Future<void> Function(int) action}) async {}
Future<void> resultHelper({required Future<OcptDatabaseOutcome> Function(int) action}) async {}
Future<void> positionalHelper(Future<OcptDatabaseOutcome> Function(int) action) async {}
class Holder {
  final Future<void> Function(int) action;
  Holder({required this.action});
}
class ResultHolder {
  final Future<OcptDatabaseOutcome> Function(int) action;
  ResultHolder({required this.action});
}
''';

      final offences = callOffencesOf({"write"}, source);

      expect(offences.map(_lineOfOffence), ["2", "5", "6", "8", "10", "14", "19"]);
    });

    test("a value read straight off an answer is found, and so is one read before its status", () {
      const source = '''
Future<void> f() async {
  final direct = (await thingService.write()).value;
  final ok = (await thingService.write()).isError;
  final before = await thingService.write();
  final id = before.value;
  if (before.isError) {}
  final after = await thingService.write();
  if (after.isError || after.value == null) {}
  final byStatus = await thingService.write();
  if (!byStatus.status.isSuccess) { return; }
  final kept = byStatus.value;
}
''';

      final offences = callOffencesOf({"write"}, source);

      expect(offences.map(_lineOfOffence), ["2", "5"]);
    });

    test("inside a transaction a converted call is wrapped by okOrAbort or valueOrAbort", () {
      const source = '''
Future<void> f() async {
  await db.transaction(() async {
    await thingService.write();
    await thingService.write().okOrAbort();
    final value = await thingService.read().valueOrAbort();
    thingService.write().okOrAbort();
    for (final x in xs) {
      await thingService.write();
    }
    await thingService.write().then((r) {});
  });
  await db.transaction(() => thingService.write());
  await db.transaction(() => thingService.write().okOrAbort());
  await thingService.write().okOrAbort();
  await thingService.read().valueOrAbort();
}
''';

      final offences = callOffencesOf({"write", "read"}, source);

      expect(offences.map(_lineOfOffence), ["3", "6", "8", "10", "12", "14", "15"]);
    });

    test("an abort wrapped in a guard body is accepted only in the listed methods", () {
      const source = '''
class OtherService {
  Future<Object> mergeIncomingFountainText() => guardResult("joined", () async {
    await thingService.read().valueOrAbort();
    await thingService.read();
  });

  Future<Object> another() => guardResult("another", () async {
    await thingService.read().valueOrAbort();
  });

  Future<void> alone() async {
    await thingService.read().valueOrAbort();
  }
}
''';

      final offences = callOffencesOf({"read"}, source);

      expect(offences.map(_lineOfOffence), ["4", "8", "12"]);
    });

    test("a method that takes the caller's stamps runs inside the caller's transaction", () {
      const source = '''
class OtherService {
  Future<void> joined({required Object stamps}) async {
    await thingService.write();
    await thingService.write().okOrAbort();
  }

  Future<void> alone() async {
    await thingService.write().okOrAbort();
  }
}
''';

      final offences = callOffencesOf({"write"}, source);

      expect(offences.map(_lineOfOffence), ["3", "8"]);
    });

    test("a doc comment naming a converted method is not a tear-off, and a homonym is not it", () {
      const source = '''
/// Calls [thingService.reconcile] and [other.thingService.reconcile].
Future<void> f() async {
  await roleIndexService.reconcile(stamps: s);
  await _roleIndexService.reconcile(stamps: s);
}
''';

      final offences = callOffencesOf({"reconcile"}, source);

      expect(offences, isEmpty);
    });

    test("then and a tear-off are found", () {
      const source = '''
Future<void> f() async {
  await thingService.write().then((r) => r);
  await run(thingService.write);
  final torn = thingService.write;
  final nested = widget.thingService.write;
  final harmless = thingService.logger;
}
''';

      final offences = callOffencesOf({"write"}, source);

      expect(offences.map(_lineOfOffence), ["2", "3", "4", "5"]);
    });

    test("the receiver of a call is known by its name, its declared type or its shape", () {
      const source = '''
class Screen {
  final OcptThingService? held;
  final OcptThingService other;
  Screen(this.held, this.other);
  Future<void> f() async {
    await held!.write();
    await other.write();
    final fetched = managers.get<OcptThingService>();
    await fetched.write();
    await managers.get<OcptThingService>().write();
    await (obj as OcptThingService).write();
    final plain = Plain();
    await plain.write();
    await compute().write();
    await items.first.write();
  }
}
''';

      final offences = callOffencesOf({"write"}, source);

      expect(offences.map(_lineOfOffence), ["6", "7", "9", "10", "11"]);
    });

    test("a call with no receiver inside a service reaches its own converted methods", () {
      const source = '''
class OcptThingService extends AbsOcptService {
  Future<void> a() async {
    write();
    this.write();
    await write();
  }
}
class Elsewhere {
  Future<void> b() async {
    write();
  }
}
''';

      final offences = callOffencesOf(
        {"write"},
        source,
        namesByClass: {
          "OcptThingService": {"write"},
        },
      );

      expect(offences.map(_lineOfOffence), ["3", "4", "5"]);
    });

    test("an abort built by hand is found by its name, with or without const", () {
      const source = '''
void f() {
  throw OcptDatabaseAbort(failure);
  throw const OcptDatabaseAbort(failure);
  throw StateError("other");
}
''';

      expect(referencesOf({"OcptDatabaseAbort"}, source), [2, 3]);
    });

    test("a participant called from the outside, and a stamps handed in, are found", () {
      const source = '''
Future<void> f() async {
  await thingService.tombstone(stamps: stamps);
  await other.tombstone();
  await thingService.write();
}
''';

      final offences = participantCallOffencesOf({"tombstone"}, source);

      expect(offences.map(_lineOfOffence), ["2", "2"]);
    });

    test("a catch is found wherever it is, private or static or in a function", () {
      const source = '''
class OcptThingService extends AbsOcptService {
  Future<void> publicOne() async {
    try {} catch (_) {}
  }
  Future<void> _privateOne() async {
    try {} on StateError catch (_) {}
  }
  static void staticOne() {
    try {} catch (_) {}
  }
  void closureOne() {
    items.forEach((i) { try {} catch (_) {} });
  }
  void finallyOnly() {
    try {} finally {}
  }
  void none() {}
}
class OcptThingOps {
  static Future<void> run() async {
    try {} catch (_) {}
  }
}
void topLevel() {
  try {} catch (_) {}
}
''';

      expect(catchSitesOf(source), {
        "OcptThingService.publicOne",
        "OcptThingService._privateOne",
        "OcptThingService.staticOne",
        "OcptThingService.closureOne",
        "OcptThingOps.run",
        "topLevel",
      });
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
class ErrorThingService implements OcptThingService {
  @override
  Future<OcptDatabaseOutcome> write() => Future.error(StateError("failed"));
}
class RethrowingThingService extends OcptThingService {
  @override
  Future<OcptDatabaseOutcome> write() async {
    try {
      return await super.write();
    } catch (_) {
      rethrow;
    }
  }
}
class MixedThingService with OcptThingService {
  @override
  Future<OcptDatabaseOutcome> write() async => throw StateError("failed");
}
class NotAServiceDouble extends Something {
  @override
  Future<void> write() async => throw StateError("a plain class");
}
class GoodThingService extends OcptThingService {
  @override
  Future<OcptDatabaseOutcome> write() async =>
      const OcptDatabaseOutcome(status: OcptDatabaseStatus.databaseError);
}
''';

      expect(doubleThrowsOf({"write"}, source), [4, 12, 20, 26]);
    });

    test("the rules see a call of a converted method only through the shape of its receiver", () {
      // What the syntax cannot tell: a receiver that is a function's result, an element of a list
      // or a name inferred from a call is not known to be a service, so its call is not checked.
      const source = '''
Future<void> f() async {
  await compute().write();
  await items.first.write();
  final inferred = pick();
  inferred.write();
}
''';

      expect(callOffencesOf({"write"}, source), isEmpty);
    });
  });
}
