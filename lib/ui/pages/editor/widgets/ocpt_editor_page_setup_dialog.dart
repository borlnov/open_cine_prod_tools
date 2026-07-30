// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';

/// A dialog letting the user pick the screenplay's page size and margins.
///
/// Shows a page size dropdown and four always-visible margin fields (left/right/top/bottom, in
/// inches), validated so that they never leave a non-positive printable area for the selected page
/// size. Use [show] to display it and get back the new [OcptPageSetup], or null if the user
/// cancelled.
class OcptEditorPageSetupDialog extends StatefulWidget {
  /// The page setup currently applied, used to pre-fill every field.
  final OcptPageSetup current;

  /// Class constructor
  const OcptEditorPageSetupDialog({required this.current, super.key});

  /// Shows the dialog and returns the [OcptPageSetup] the user applied, or null if they cancelled
  /// it.
  static Future<OcptPageSetup?> show(BuildContext context, {required OcptPageSetup current}) =>
      showDialog<OcptPageSetup>(
        context: context,
        builder: (context) => OcptEditorPageSetupDialog(current: current),
      );

  @override
  State<OcptEditorPageSetupDialog> createState() => _OcptEditorPageSetupDialogState();
}

/// The state of [OcptEditorPageSetupDialog].
class _OcptEditorPageSetupDialogState extends State<OcptEditorPageSetupDialog> {
  /// The form used to validate the entered margins.
  final _formKey = GlobalKey<FormState>();

  /// The page format currently selected in the dropdown.
  late OcptPageFormat _selectedFormat;

  /// The controller of the left margin text field.
  final _leftController = TextEditingController();

  /// The controller of the right margin text field.
  final _rightController = TextEditingController();

  /// The controller of the top margin text field.
  final _topController = TextEditingController();

  /// The controller of the bottom margin text field.
  final _bottomController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedFormat = widget.current.format;
    final margins = widget.current.margins;
    _leftController.text = margins.leftInches.toString();
    _rightController.text = margins.rightInches.toString();
    _topController.text = margins.topInches.toString();
    _bottomController.text = margins.bottomInches.toString();
  }

  @override
  void dispose() {
    _leftController.dispose();
    _rightController.dispose();
    _topController.dispose();
    _bottomController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return AlertDialog(
      title: Text(tr.editorPageSetupDialogTitle),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<OcptPageFormat>(
                initialValue: _selectedFormat,
                decoration: InputDecoration(labelText: tr.editorPageSetupPageSizeLabel),
                mouseCursor: ocptClickableCursor,
                items: [
                  for (final format in OcptPageFormat.values)
                    DropdownMenuItem(value: format, child: Text(_formatLabel(tr, format))),
                ],
                onChanged: (format) {
                  if (format == null) {
                    return;
                  }
                  setState(() => _selectedFormat = format);
                  _formKey.currentState?.validate();
                },
              ),
              const SizedBox(height: 16),
              Text(tr.editorPageSetupMarginsSectionLabel, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _leftController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: tr.editorPageSetupMarginLeftLabel),
                      validator: (value) => _validateMargin(
                        tr,
                        value: value,
                        otherLeft: null,
                        otherRight: _rightController.text,
                        otherTop: _topController.text,
                        otherBottom: _bottomController.text,
                        isHorizontal: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _rightController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: tr.editorPageSetupMarginRightLabel),
                      validator: (value) => _validateMargin(
                        tr,
                        value: value,
                        otherLeft: _leftController.text,
                        otherRight: null,
                        otherTop: _topController.text,
                        otherBottom: _bottomController.text,
                        isHorizontal: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _topController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: tr.editorPageSetupMarginTopLabel),
                      validator: (value) => _validateMargin(
                        tr,
                        value: value,
                        otherLeft: _leftController.text,
                        otherRight: _rightController.text,
                        otherTop: null,
                        otherBottom: _bottomController.text,
                        isHorizontal: false,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _bottomController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: tr.editorPageSetupMarginBottomLabel),
                      validator: (value) => _validateMargin(
                        tr,
                        value: value,
                        otherLeft: _leftController.text,
                        otherRight: _rightController.text,
                        otherTop: _topController.text,
                        otherBottom: null,
                        isHorizontal: false,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _resetToStandardMargins,
                  child: Text(tr.editorPageSetupResetAction),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => globalGetIt().get<OcptRouterManager>().pop(),
          child: Text(tr.editorPageSetupCancelAction),
        ),
        FilledButton(onPressed: _submit, child: Text(tr.editorPageSetupApplyAction)),
      ],
    );
  }

  /// The localized label of [format].
  String _formatLabel(Tr tr, OcptPageFormat format) => switch (format) {
    OcptPageFormat.usLetter => tr.editorPageSetupUsLetterOption,
    OcptPageFormat.a4 => tr.editorPageSetupA4Option,
  };

  /// Validates one margin field: rejects a non-numeric or negative value, then, once every field
  /// parses, rejects a combination that leaves a non-positive printable width or height for
  /// [_selectedFormat].
  ///
  /// [value] is this field's own current text; [otherLeft]/[otherRight]/[otherTop]/[otherBottom]
  /// are the other three fields' current text (null for whichever one [value] itself is), read
  /// directly from their controllers rather than requiring the form to already be consistent.
  /// [isHorizontal] tells whether this field is left/right (checked against the page width) or
  /// top/bottom (checked against the page height).
  String? _validateMargin(
    Tr tr, {
    required String? value,
    required String? otherLeft,
    required String? otherRight,
    required String? otherTop,
    required String? otherBottom,
    required bool isHorizontal,
  }) {
    final parsed = double.tryParse(value ?? "");
    if (parsed == null) {
      return tr.editorPageSetupMarginNotANumberError;
    }
    if (parsed < 0) {
      return tr.editorPageSetupMarginNegativeError;
    }

    final left = otherLeft == null ? parsed : double.tryParse(otherLeft);
    final right = otherRight == null ? parsed : double.tryParse(otherRight);
    final top = otherTop == null ? parsed : double.tryParse(otherTop);
    final bottom = otherBottom == null ? parsed : double.tryParse(otherBottom);
    if (left == null || right == null || top == null || bottom == null) {
      // One of the other fields isn't currently a valid number: that field's own validator
      // already reports it, nothing more to add here.
      return null;
    }

    final isOverflowing = isHorizontal
        ? left + right >= _pageWidthInches(_selectedFormat)
        : top + bottom >= _pageHeightInches(_selectedFormat);
    if (isOverflowing) {
      return tr.editorPageSetupMarginsTooLargeError;
    }

    return null;
  }

  /// The physical page width, in inches, of [format], read from the format's own layout metrics
  /// (built with their default standard margins, which is always safe/non-asserting) rather than
  /// hardcoding it a second time here.
  double _pageWidthInches(OcptPageFormat format) => switch (format) {
    OcptPageFormat.usLetter => FountainLayoutMetrics.usLetter().pageWidthInches,
    OcptPageFormat.a4 => FountainLayoutMetrics.a4().pageWidthInches,
  };

  /// The physical page height, in inches, of [format]; see [_pageWidthInches].
  double _pageHeightInches(OcptPageFormat format) => switch (format) {
    OcptPageFormat.usLetter => FountainLayoutMetrics.usLetter().pageHeightInches,
    OcptPageFormat.a4 => FountainLayoutMetrics.a4().pageHeightInches,
  };

  /// Overwrites every margin field with the standard margins, then re-validates the form.
  void _resetToStandardMargins() {
    const standard = FountainPageMargins.standard();
    setState(() {
      _leftController.text = standard.leftInches.toString();
      _rightController.text = standard.rightInches.toString();
      _topController.text = standard.topInches.toString();
      _bottomController.text = standard.bottomInches.toString();
    });
    _formKey.currentState?.validate();
  }

  /// Validates the entered margins and, if they're valid, pops the dialog returning the resulting
  /// [OcptPageSetup].
  ///
  /// The dialog is dismissed through the router manager (RFL31: navigation only via the router
  /// manager), whose pop delivers the new page setup back to the [OcptEditorPageSetupDialog.show]
  /// caller.
  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final setup = OcptPageSetup(
      format: _selectedFormat,
      margins: FountainPageMargins(
        leftInches: double.parse(_leftController.text),
        rightInches: double.parse(_rightController.text),
        topInches: double.parse(_topController.text),
        bottomInches: double.parse(_bottomController.text),
      ),
    );
    globalGetIt().get<OcptRouterManager>().pop<OcptPageSetup>(setup);
  }
}
