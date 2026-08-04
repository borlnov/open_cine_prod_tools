// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_resources_xlsx_labels.dart';
import 'package:open_cine_prod_tools/types/ocpt_elements_xlsx_column.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_resources_labels.dart';

void main() {
  group("ocptResourcesXlsxLabelsOf", () {
    testWidgets("the cost column header names the project's currency", (tester) async {
      final eurLabels = await _buildXlsxLabels(tester, currencyCode: "EUR");
      expect(eurLabels.elementsHeaderOf(OcptElementsXlsxColumn.cost), "Cost (EUR)");

      final usdLabels = await _buildXlsxLabels(tester, currencyCode: "USD");
      expect(usdLabels.elementsHeaderOf(OcptElementsXlsxColumn.cost), "Cost (USD)");
    });

    testWidgets("every other elements column header is unaffected by the currency", (
      tester,
    ) async {
      final labels = await _buildXlsxLabels(tester, currencyCode: "EUR");

      expect(labels.elementsHeaderOf(OcptElementsXlsxColumn.name), "Name");
      expect(labels.elementsHeaderOf(OcptElementsXlsxColumn.quantity), "Quantity");
    });
  });
}

/// Pumps a throwaway widget to get hold of a real [BuildContext], and builds the workbook labels
/// with [currencyCode] from it — mirroring `ocptShotListXlsxLabelsOf`'s own test helper, since
/// `Tr.of` needs a mounted widget tree to resolve.
Future<OcptResourcesXlsxLabels> _buildXlsxLabels(
  WidgetTester tester, {
  required String currencyCode,
}) async {
  late OcptResourcesXlsxLabels labels;

  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [
        Tr.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: Tr.delegate.supportedLocales,
      home: Builder(
        builder: (context) {
          labels = ocptResourcesXlsxLabelsOf(context, const [], currencyCode: currencyCode);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  await tester.pumpAndSettle();

  return labels;
}
