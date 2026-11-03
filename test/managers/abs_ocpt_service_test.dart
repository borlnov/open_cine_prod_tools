// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_dart_result/act_dart_result.dart';
import 'package:act_foundation/act_foundation.dart';
import 'package:act_test_utility/act_test_utility.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/abs_ocpt_service.dart';
import 'package:open_cine_prod_tools/managers/ocpt_database_abort.dart';
import 'package:open_cine_prod_tools/managers/ocpt_database_outcome_abort.dart';
import 'package:open_cine_prod_tools/managers/ocpt_database_result_abort.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
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

/// A service that writes a row in its own transaction, or fails, the way a converted service does.
class _Writer extends AbsOcptService {
  /// Class constructor
  const _Writer({required super.logger});

  /// Insert [id] into the probe table, in a transaction of its own, and answer `ok`.
  Future<OcptDatabaseOutcome> insert(OcptProjectDatabase database, int id) => guardOutcome(
    "insert",
    () =>
        database.transaction(() => database.customStatement("INSERT INTO probe (id) VALUES ($id)")),
  );

  /// Answer a failure without writing anything.
  Future<OcptDatabaseOutcome> fail() async =>
      const OcptDatabaseOutcome(status: OcptDatabaseStatus.databaseError, extraInfo: "inner");

  /// Insert [id] then call [other], inside one transaction, through the cancelling helper.
  Future<OcptDatabaseOutcome> insertThen(
    OcptProjectDatabase database,
    int id,
    Future<OcptDatabaseOutcome> Function() other,
  ) => guardOutcome(
    "insertThen",
    () => database.transaction(() async {
      await database.customStatement("INSERT INTO probe (id) VALUES ($id)");
      await other().okOrAbort();
    }),
  );

  /// Insert [id] then read a value of [other], inside one transaction, through the cancelling
  /// helper.
  Future<OcptDatabaseOutcome> insertThenRead(
    OcptProjectDatabase database,
    int id,
    Future<OcptDatabaseResult<int>> Function() other,
  ) => guardOutcome(
    "insertThenRead",
    () => database.transaction(() async {
      await database.customStatement("INSERT INTO probe (id) VALUES ($id)");
      await other().valueOrAbort();
    }),
  );
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

  test('an assertion goes through instead of becoming a status', () async {
    await expectLater(
      service.write(() async => throw AssertionError("bad")),
      throwsA(isA<AssertionError>()),
    );
    expect(logger.records, isEmpty);
  });

  test('an invalid argument is a failure of the call, answered and logged once by type', () async {
    final result = await service.read(() async => throw ArgumentError("secret title"));
    expect(result.status, OcptDatabaseStatus.databaseError);
    expect(result.extraInfo, ArgumentError);
    expect(logger.recordsAtLevel(LogsLevel.error), hasLength(1));
    expect(logger.records.single.message.toString(), isNot(contains("secret title")));
  });

  test('a range error is a failure of the call too', () async {
    final result = await service.read(() async => throw RangeError.range(5, 0, 2));
    expect(result.status, OcptDatabaseStatus.databaseError);
    expect(result.extraInfo, RangeError);

    final outcome = await service.write(() async => throw IndexError.withLength(3, 2));
    expect(outcome.status, OcptDatabaseStatus.databaseError);
    expect(logger.recordsAtLevel(LogsLevel.error), hasLength(2));
  });

  group('the cancelling helpers', () {
    const failure = OcptDatabaseOutcome(
      status: OcptDatabaseStatus.databaseError,
      extraInfo: "inner",
    );

    test('okOrAbort lets a success through and raises the abort on a failure', () async {
      await Future.value(const OcptDatabaseOutcome(status: OcptDatabaseStatus.ok)).okOrAbort();

      await expectLater(
        Future.value(failure).okOrAbort(),
        throwsA(isA<OcptDatabaseAbort>().having((abort) => abort.failure, 'failure', failure)),
      );
    });

    test('valueOrAbort gives the value, null for a refusal, and raises on a failure', () async {
      expect(
        await Future.value(
          const OcptDatabaseResult<int>(status: OcptDatabaseStatus.ok, value: 4),
        ).valueOrAbort(),
        4,
      );
      expect(
        await Future.value(
          const OcptDatabaseResult<int>(status: OcptDatabaseStatus.ok),
        ).valueOrAbort(),
        isNull,
      );
      await expectLater(
        Future.value(
          const OcptDatabaseResult<int>(
            status: OcptDatabaseStatus.databaseError,
            extraInfo: "inner",
          ),
        ).valueOrAbort(),
        throwsA(isA<OcptDatabaseAbort>()),
      );
    });

    group('inside a real transaction', () {
      late OcptProjectDatabase database;
      late _Writer writer;

      Future<int> rowCount() async {
        final rows = await database.customSelect("SELECT COUNT(*) AS n FROM probe").get();
        return rows.single.read<int>("n");
      }

      setUp(() async {
        database = OcptProjectDatabase.memory();
        await database.customStatement("CREATE TABLE probe (id INTEGER)");
        writer = _Writer(logger: logger);
      });

      tearDown(() async {
        await database.close();
      });

      test('a failed call to another service rolls back what was written before it', () async {
        final outcome = await writer.insertThen(database, 1, writer.fail);

        expect(outcome.status, OcptDatabaseStatus.databaseError);
        expect(outcome.extraInfo, "inner");
        expect(await rowCount(), 0);
        expect(logger.records, isEmpty, reason: "the failure was logged by whoever answered it");
      });

      test('a call that succeeds lets the whole transaction commit', () async {
        final outcome = await writer.insertThen(database, 1, () => writer.insert(database, 2));

        expect(outcome.status, OcptDatabaseStatus.ok);
        expect(await rowCount(), 2);
      });

      test(
        'a success of another service is rolled back with the rest when a later call fails',
        () async {
          final outcome = await writer.insertThen(database, 1, () async {
            await writer.insert(database, 2).okOrFail;

            return writer.fail();
          });

          expect(outcome.status, OcptDatabaseStatus.databaseError);
          expect(await rowCount(), 0, reason: "the other service's own savepoint rolls back too");
        },
      );

      test('a failed read of another service rolls back through valueOrAbort', () async {
        final outcome = await writer.insertThenRead(
          database,
          1,
          () async => const OcptDatabaseResult<int>(
            status: OcptDatabaseStatus.databaseError,
            extraInfo: "inner",
          ),
        );

        expect(outcome.status, OcptDatabaseStatus.databaseError);
        expect(await rowCount(), 0);
      });
    });
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
