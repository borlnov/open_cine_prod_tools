// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_dart_result/act_dart_result.dart';
import 'package:act_foundation/act_foundation.dart';
import 'package:act_test_utility/act_test_utility.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/abs_ocpt_service.dart';
import 'package:open_cine_prod_tools/types/ocpt_database_status.dart';

import '../ocpt_result_expectations.dart';

/// A service that hands its protected boundary to the tests.
class _Service extends AbsOcptService {
  /// Class constructor
  const _Service({required super.logger});

  /// Run [body] through the boundary that answers a value.
  Future<OcptDatabaseResult<int>> read(Future<int?> Function() body) => guardResult("read", body);

  /// Run [body] through the boundary that answers nothing.
  Future<OcptDatabaseOutcome> write(Future<void> Function() body) => guardOutcome("write", body);
}

/// Guard the boundary a service answers through.
void main() {
  late FakeLogger logger;
  late _Service service;

  setUp(() {
    logger = FakeLogger();
    service = _Service(logger: logger);
  });

  test('a body that answers gives ok and its value, and logs nothing', () async {
    final result = await service.read(() async => 7);

    expect(result.status, OcptDatabaseStatus.ok);
    expect(result.value, 7);
    expect(logger.records, isEmpty);
  });

  test('a body that answers nothing, as a preview refusal does, still gives ok', () async {
    final result = await service.read(() async => null);

    expect(result.status, OcptDatabaseStatus.ok);
    expect(result.value, isNull);
    expect((await service.write(() async {})).status, OcptDatabaseStatus.ok);
  });

  test('a failure becomes databaseError carrying its type, and is logged once by type', () async {
    final result = await service.read(() async => throw StateError("secret title"));

    expect(result.status, OcptDatabaseStatus.databaseError);
    expect(result.extraInfo, StateError);
    expect(result.value, isNull);
    expect(logger.recordsAtLevel(LogsLevel.error), hasLength(1));
    expect(logger.records.single.message.toString(), isNot(contains("secret title")));

    final outcome = await service.write(() async => throw Exception("secret title"));
    expect(outcome.status, OcptDatabaseStatus.databaseError);
    expect(logger.recordsAtLevel(LogsLevel.error), hasLength(2));
  });

  test('an abort from another service answers its extra info without a second log line', () async {
    final result = await service.write(
      () async => throw const OcptDatabaseAbort(
        StatusWithExtraInfo(status: OcptDatabaseStatus.databaseError, extraInfo: "inner"),
      ),
    );

    expect(result.status, OcptDatabaseStatus.databaseError);
    expect(result.extraInfo, "inner");
    expect(logger.records, isEmpty);
  });

  test('a mistake of the programmer goes through instead of becoming a status', () async {
    await expectLater(service.read(() async => throw ArgumentError("bad")), throwsArgumentError);
    await expectLater(
      service.write(() async => throw AssertionError("bad")),
      throwsA(isA<AssertionError>()),
    );
    expect(logger.records, isEmpty);
  });

  test('the test expectations unwrap a value and fail on an error', () async {
    expect(await service.read(() async => 3).valueOrFail, 3);
    expect(await service.read(() async => null).maybeValueOrFail, isNull);
    await service.write(() async {}).okOrFail;
    await expectLater(
      service.write(() async => throw StateError("x")).okOrFail,
      throwsA(isA<TestFailure>()),
    );
  });
}
