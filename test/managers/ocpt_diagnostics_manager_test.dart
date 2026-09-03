// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/ocpt_diagnostics_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_diagnostics_entry.dart';

void main() {
  late OcptDiagnosticsManager manager;

  setUp(() {
    manager = OcptDiagnosticsManager();
  });

  tearDown(() => manager.disposeLifeCycle());

  group('OcptDiagnosticsManager.record', () {
    test('starts empty', () {
      expect(manager.entries, isEmpty);
    });

    test('appends an entry, oldest first', () {
      manager.record(category: OcptDiagnosticsCategory.hosting, message: 'starting');
      manager.record(category: OcptDiagnosticsCategory.sync, message: 'in sync');

      expect(manager.entries, hasLength(2));
      expect(manager.entries[0].message, 'starting');
      expect(manager.entries[0].category, OcptDiagnosticsCategory.hosting);
      expect(manager.entries[1].message, 'in sync');
    });

    test('defaults to info level, and carries a level when given one', () {
      manager.record(category: OcptDiagnosticsCategory.hosting, message: 'online');
      manager.record(
        category: OcptDiagnosticsCategory.sync,
        level: OcptDiagnosticsLevel.error,
        message: 'offline',
      );

      expect(manager.entries[0].level, OcptDiagnosticsLevel.info);
      expect(manager.entries[1].level, OcptDiagnosticsLevel.error);
    });

    test('the returned entries list is unmodifiable', () {
      manager.record(category: OcptDiagnosticsCategory.hosting, message: 'online');

      expect(() => manager.entries.add(manager.entries.first), throwsUnsupportedError);
    });

    test('caps the buffer, dropping the oldest entry first', () {
      for (var i = 0; i < ocptDiagnosticsBufferCap + 10; i++) {
        manager.record(category: OcptDiagnosticsCategory.sync, message: 'entry-$i');
      }

      expect(manager.entries, hasLength(ocptDiagnosticsBufferCap));
      expect(manager.entries.first.message, 'entry-10');
      expect(manager.entries.last.message, 'entry-${ocptDiagnosticsBufferCap + 9}');
    });
  });

  group('OcptDiagnosticsManager.entriesStream', () {
    test('emits the full, updated entries list on every record', () async {
      final emissions = <List<OcptDiagnosticsEntry>>[];
      final subscription = manager.entriesStream.listen(emissions.add);

      manager.record(category: OcptDiagnosticsCategory.join, message: 'connecting');
      manager.record(category: OcptDiagnosticsCategory.join, message: 'downloading');
      await Future<void>.delayed(Duration.zero);

      expect(emissions, hasLength(2));
      expect(emissions[0].map((entry) => entry.message), ['connecting']);
      expect(emissions[1].map((entry) => entry.message), ['connecting', 'downloading']);

      await subscription.cancel();
    });

    test('does not replay the current value to a new listener', () async {
      manager.record(category: OcptDiagnosticsCategory.presence, message: 'peer joined');

      final emissions = <List<OcptDiagnosticsEntry>>[];
      final subscription = manager.entriesStream.listen(emissions.add);
      await Future<void>.delayed(Duration.zero);

      expect(emissions, isEmpty);

      await subscription.cancel();
    });
  });

  group('OcptDiagnosticsManager.clear', () {
    test('empties the buffer', () {
      manager.record(category: OcptDiagnosticsCategory.relayServer, message: 'project created');
      manager.clear();

      expect(manager.entries, isEmpty);
    });

    test('broadcasts the now-empty list on entriesStream', () async {
      manager.record(category: OcptDiagnosticsCategory.relayServer, message: 'project created');

      final emissions = <List<OcptDiagnosticsEntry>>[];
      final subscription = manager.entriesStream.listen(emissions.add);
      manager.clear();
      await Future<void>.delayed(Duration.zero);

      expect(emissions, [isEmpty]);

      await subscription.cancel();
    });
  });

  group('OcptDiagnosticsManager.log', () {
    test('no-ops rather than throwing when no global manager instance exists', () {
      // No `OcptGlobalManager.instance` touched anywhere in this file, and no manager registered
      // — this must not throw, per this class's own guarded-log doc comment.
      expect(
        () => OcptDiagnosticsManager.log(category: OcptDiagnosticsCategory.hosting, message: 'x'),
        returnsNormally,
      );
    });
  });
}
