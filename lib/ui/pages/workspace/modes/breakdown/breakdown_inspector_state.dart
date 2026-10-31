// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_editable_field.dart';

/// The state of `OcptBreakdownInspectorBloc`: what is typed into the inspector's text fields and
/// not yet written.
///
/// A field is shown from here while an edit is pending, and from the stored row otherwise
/// (`elementFieldValueOf`, `sceneNotesValueOf`, `setNameValueOf`), so what the user sees never falls
/// back to an older stored value between the keystroke and the write.
class OcptBreakdownInspectorState extends BlocStateForMixin<OcptBreakdownInspectorState> {
  /// A typed field of the selected target's own sheet still sitting in the field-edit debounce,
  /// keyed by the element's id and which `OcptElementField` it is: `name`, `subCategory`, `quantity`
  /// or `notes`, the only four the target inspector ever edits.
  final Map<(String, OcptElementField), String> pendingElementFieldEdits;

  /// A scene's own breakdown notes still sitting in the field-edit debounce, keyed by the scene's
  /// id, over the same debounce as [pendingElementFieldEdits].
  final Map<String, String> pendingSceneNotesEdits;

  /// A set's own name still sitting in the field-edit debounce, keyed by the set's id: the title of
  /// a set's sheet is its name field, renamed over the same debounce as [pendingElementFieldEdits].
  final Map<String, String> pendingSetNameEdits;

  /// Class constructor
  const OcptBreakdownInspectorState({
    required this.pendingElementFieldEdits,
    required this.pendingSceneNotesEdits,
    required this.pendingSetNameEdits,
  });

  /// Builds the state of a bloc that has nothing typed yet.
  const OcptBreakdownInspectorState.init()
    : pendingElementFieldEdits = const {},
      pendingSceneNotesEdits = const {},
      pendingSetNameEdits = const {};

  /// [elementId]'s current value for `field` — a pending edit still sitting in
  /// [pendingElementFieldEdits], or [storedValue] (the element's own value, read off the mode's
  /// selected element at the call site) otherwise.
  String elementFieldValueOf(String elementId, OcptElementField field, String storedValue) =>
      pendingElementFieldEdits[(elementId, field)] ?? storedValue;

  /// [sceneId]'s current value for its own breakdown notes — a pending edit still sitting in
  /// [pendingSceneNotesEdits], or [storedValue] (the scene's own value, read off the mode's selected
  /// scene at the call site) otherwise.
  String sceneNotesValueOf(String sceneId, String storedValue) =>
      pendingSceneNotesEdits[sceneId] ?? storedValue;

  /// [setId]'s current name — a rename still sitting in [pendingSetNameEdits], or [storedValue]
  /// (the set's own name, read off the selected target at the call site) otherwise.
  String setNameValueOf(String setId, String storedValue) =>
      pendingSetNameEdits[setId] ?? storedValue;

  /// Copies this state, replacing what is given.
  @override
  OcptBreakdownInspectorState copyWith({
    Map<(String, OcptElementField), String>? pendingElementFieldEdits,
    Map<String, String>? pendingSceneNotesEdits,
    Map<String, String>? pendingSetNameEdits,
  }) => OcptBreakdownInspectorState(
    pendingElementFieldEdits: pendingElementFieldEdits ?? this.pendingElementFieldEdits,
    pendingSceneNotesEdits: pendingSceneNotesEdits ?? this.pendingSceneNotesEdits,
    pendingSetNameEdits: pendingSetNameEdits ?? this.pendingSetNameEdits,
  );

  /// Object properties
  @override
  List<Object?> get props => [
    ...super.props,
    pendingElementFieldEdits,
    pendingSceneNotesEdits,
    pendingSetNameEdits,
  ];
}
