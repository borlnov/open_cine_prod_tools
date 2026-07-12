// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <benoit.rolandeau@allcircuits.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/main.dart';

void main() {
  testWidgets('MainApp displays the application name', (WidgetTester tester) async {
    await tester.pumpWidget(const MainApp());

    expect(find.text(appName), findsOneWidget);
  });
}
