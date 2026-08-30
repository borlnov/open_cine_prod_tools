// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:ocpt_sync_protocol/ocpt_sync_protocol.dart';
import 'package:test/test.dart';

void main() {
  group('OcptSyncError', () {
    test('round-trips through JSON', () {
      const error = OcptSyncError(code: OcptSyncErrorCode.badToken, message: 'token mismatch');

      final decoded = OcptSyncError.fromJson(error.toJson());

      expect(decoded, error);
    });

    test('round-trips every error code', () {
      for (final code in OcptSyncErrorCode.values) {
        final error = OcptSyncError(code: code, message: 'detail for $code');

        final decoded = OcptSyncError.fromJson(error.toJson());

        expect(decoded.code, code, reason: 'round-tripping $code should preserve the code');
        expect(error.toJson()['code'], code.name);
      }
    });

    test('two errors with the same fields are equal', () {
      const first = OcptSyncError(code: OcptSyncErrorCode.sequenceConflict, message: 'stale cursor');
      const second = OcptSyncError(code: OcptSyncErrorCode.sequenceConflict, message: 'stale cursor');

      expect(first, second);
    });

    test('rejects an unknown error code with a typed error', () {
      final json = {'code': 'notARealCode', 'message': 'oops'};

      expect(() => OcptSyncError.fromJson(json), throwsA(isA<OcptSyncMalformedDataError>()));
    });

    test('reports a missing message with a typed error', () {
      final json = {'code': OcptSyncErrorCode.malformed.name};

      expect(() => OcptSyncError.fromJson(json), throwsA(isA<OcptSyncMalformedDataError>()));
    });
  });
}
