// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_line_form_fields.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_line_form_body.dart';

/// A minimal host exercising [OcptBudgetLineFormBody] the way the capture wizard eventually will:
/// it owns the [GlobalKey<FormState>], keeps the last draft the body reported, and its own `Save`
/// validates the form before handing the draft to [onSaved] — mirroring every one of the five
/// dialog shells this milestone split `OcptBudgetLineFormBody` alongside.
class _TestHost extends StatefulWidget {
  /// Called with the draft [_TestHostState._submit] popped, once validation passed and a draft was
  /// available.
  final ValueChanged<OcptBudgetLineFormFields> onSaved;

  /// Class constructor
  const _TestHost({required this.onSaved});

  @override
  State<_TestHost> createState() => _TestHostState();
}

/// The state of [_TestHost].
class _TestHostState extends State<_TestHost> {
  /// The form [OcptBudgetLineFormBody] validates against.
  final _formKey = GlobalKey<FormState>();

  /// The fields [OcptBudgetLineFormBody] would submit right now, or null while it cannot be read
  /// at all.
  OcptBudgetLineFormFields? _draft;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        OcptBudgetLineFormBody(
          currencyCode: "EUR",
          formKey: _formKey,
          onDraftChanged: (draft) => setState(() => _draft = draft),
        ),
        ElevatedButton(onPressed: _submit, child: const Text("Save")),
      ],
    ),
  );

  /// Validates the form and, if it passes, reports the last draft the body reported — exactly what
  /// every one of the five dialog shells this milestone split does on their own `Save`.
  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final draft = _draft;
    if (draft == null) {
      return;
    }

    widget.onSaved(draft);
  }
}

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve in tests.
Widget _wrapWithLocalization(Widget child) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: child,
);

void main() {
  /// Pumps [OcptBudgetLineFormBody] inside [_TestHost], [onSaved] recording every reported save.
  Future<Tr> pumpBody(WidgetTester tester, {required ValueChanged<OcptBudgetLineFormFields> onSaved}) async {
    tester.view.physicalSize = const Size(900, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrapWithLocalization(_TestHost(onSaved: onSaved)));
    await tester.pumpAndSettle();

    return Tr.of(tester.element(find.byType(OcptBudgetLineFormBody)));
  }

  testWidgets("Save is refused until the label, quantity and unit price are filled", (tester) async {
    OcptBudgetLineFormFields? saved;
    final tr = await pumpBody(tester, onSaved: (fields) => saved = fields);

    await tester.tap(find.text("Save"));
    await tester.pumpAndSettle();

    expect(find.text(tr.budgetEntryDialogLabelRequiredError), findsOneWidget);
    expect(find.text(tr.budgetEntryDialogAmountInvalidError), findsNWidgets(2));
    expect(saved, isNull);
  });

  testWidgets("a filled form reports the fields typed", (tester) async {
    OcptBudgetLineFormFields? saved;
    final tr = await pumpBody(tester, onSaved: (fields) => saved = fields);

    await tester.enterText(
      find.widgetWithText(TextFormField, tr.budgetLineLabelFieldLabel),
      "Camera hire",
    );
    await tester.enterText(find.widgetWithText(TextFormField, tr.budgetLineQuantityFieldLabel), "5");
    await tester.enterText(find.widgetWithText(TextFormField, tr.budgetLineUnitFieldLabel), "day");
    await tester.enterText(
      find.widgetWithText(TextFormField, tr.budgetLineUnitPriceFieldLabel),
      "120",
    );

    await tester.tap(find.text("Save"));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.label, "Camera hire");
    expect(saved!.quantityMilli, 5000);
    expect(saved!.unit, "day");
    expect(saved!.unitAmountCents, 12000);
  });

  testWidgets("an invalid quantity is refused, and nothing is saved", (tester) async {
    OcptBudgetLineFormFields? saved;
    final tr = await pumpBody(tester, onSaved: (fields) => saved = fields);

    await tester.enterText(
      find.widgetWithText(TextFormField, tr.budgetLineLabelFieldLabel),
      "Camera hire",
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, tr.budgetLineQuantityFieldLabel),
      "not a number",
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, tr.budgetLineUnitPriceFieldLabel),
      "120",
    );

    await tester.tap(find.text("Save"));
    await tester.pumpAndSettle();

    expect(find.text(tr.budgetEntryDialogAmountInvalidError), findsOneWidget);
    expect(saved, isNull);
  });

  testWidgets("the unit field is not required", (tester) async {
    OcptBudgetLineFormFields? saved;
    final tr = await pumpBody(tester, onSaved: (fields) => saved = fields);

    await tester.enterText(
      find.widgetWithText(TextFormField, tr.budgetLineLabelFieldLabel),
      "Camera hire",
    );
    await tester.enterText(find.widgetWithText(TextFormField, tr.budgetLineQuantityFieldLabel), "1");
    await tester.enterText(
      find.widgetWithText(TextFormField, tr.budgetLineUnitPriceFieldLabel),
      "120",
    );

    await tester.tap(find.text("Save"));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.unit, "");
  });
}
