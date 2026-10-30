// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_log_subject.dart';

void main() {
  group('ocptLogFileName', () {
    test('keeps the file name and drops the folder holding the user name', () {
      expect(ocptLogFileName('/home/jane/Films/My Film.ocpt'), 'My Film.ocpt');
    });

    test('names a project that is not open', () {
      expect(ocptLogFileName(null), 'none');
    });
  });
}
