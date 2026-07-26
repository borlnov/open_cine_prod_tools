// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';

/// A dialog letting the user edit the screenplay's title-page metadata: Title, Credit, Author,
/// Draft date, Contact and Source.
///
/// Every field is prefilled from [current]'s raw joined value (`entry(key)?.joinedValue`), not
/// from `FountainTitlePage`'s semantic getters (`authors`, `contact`): the semantic getters
/// re-split and re-join their source text (for example turning "Jane Doe and John Smith" into a
/// comma-joined "Jane Doe, John Smith"), which would silently reformat the field's text every time
/// the dialog is reopened without an edit. Use [show] to display it and get back the six edited
/// field values, or null if the user cancelled.
class OcptEditorTitlePageDialog extends StatefulWidget {
  /// The title page currently parsed out of the screenplay, or null if it has none. Every field
  /// pre-fills blank when this is null.
  final FountainTitlePage? current;

  /// Class constructor
  const OcptEditorTitlePageDialog({required this.current, super.key});

  /// Shows the dialog and returns the six field values the user applied, or null if they
  /// cancelled it.
  static Future<
    ({String title, String credit, String author, String draftDate, String contact, String source})?
  >
  show(BuildContext context, {required FountainTitlePage? current}) => showDialog<
    ({String title, String credit, String author, String draftDate, String contact, String source})
  >(context: context, builder: (context) => OcptEditorTitlePageDialog(current: current));

  @override
  State<OcptEditorTitlePageDialog> createState() => _OcptEditorTitlePageDialogState();
}

/// The state of [OcptEditorTitlePageDialog].
class _OcptEditorTitlePageDialogState extends State<OcptEditorTitlePageDialog> {
  /// The controller of the Title field.
  final _titleController = TextEditingController();

  /// The controller of the Credit field.
  final _creditController = TextEditingController();

  /// The controller of the Author field.
  final _authorController = TextEditingController();

  /// The controller of the Draft date field.
  final _draftDateController = TextEditingController();

  /// The controller of the Contact field.
  final _contactController = TextEditingController();

  /// The controller of the Source field.
  final _sourceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final current = widget.current;
    _titleController.text = current?.entry('Title')?.joinedValue ?? '';
    _creditController.text = current?.entry('Credit')?.joinedValue ?? '';
    _authorController.text = (current?.entry('Author') ?? current?.entry('Authors'))?.joinedValue ?? '';
    _draftDateController.text = current?.entry('Draft date')?.joinedValue ?? '';
    _contactController.text = current?.entry('Contact')?.joinedValue ?? '';
    _sourceController.text = current?.entry('Source')?.joinedValue ?? '';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _creditController.dispose();
    _authorController.dispose();
    _draftDateController.dispose();
    _contactController.dispose();
    _sourceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return AlertDialog(
      title: Text(tr.editorTitlePageDialogTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(labelText: tr.editorTitlePageTitleLabel),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _creditController,
              decoration: InputDecoration(labelText: tr.editorTitlePageCreditLabel),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _authorController,
              decoration: InputDecoration(labelText: tr.editorTitlePageAuthorLabel),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _draftDateController,
              decoration: InputDecoration(labelText: tr.editorTitlePageDraftDateLabel),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _contactController,
              decoration: InputDecoration(labelText: tr.editorTitlePageContactLabel),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _sourceController,
              decoration: InputDecoration(labelText: tr.editorTitlePageSourceLabel),
            ),
          ],
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

  /// Pops the dialog through the router manager (RFL31), returning the six fields' current text,
  /// each trimmed.
  void _submit() {
    globalGetIt().get<OcptRouterManager>().pop((
      title: _titleController.text.trim(),
      credit: _creditController.text.trim(),
      author: _authorController.text.trim(),
      draftDate: _draftDateController.text.trim(),
      contact: _contactController.text.trim(),
      source: _sourceController.text.trim(),
    ));
  }
}
