// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <benoit.rolandeau@allcircuits.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/constants/app_constants.dart';
import 'package:open_cine_prod_tools/ui/pages/home/home_page.dart';

void main() {
  testWidgets('HomePage displays the application title', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomePage()));

    expect(find.text(appTitle), findsOneWidget);
  });
}
