// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:open_cine_prod_tools/models/ocpt_scene_prop_summary.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_set_element_shape.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_pending_edit_key.dart';

/// The state of `OcptShotListFloorPlanSetsBloc`: what the floor plans' set tabs, tray and palette
/// hold of their own.
///
/// The sets, the symbols and the underlays themselves are the mode's data
/// (`OcptShotListState.floorPlanSnapshot`, `.locations`): this is the set names typed and still
/// waiting for their write, the view preferences of the session, the palette's armed placement
/// and the sequence's props the palette offers.
class OcptShotListFloorPlanSetsState extends BlocStateForMixin<OcptShotListFloorPlanSetsState> {
  /// Every set name currently sitting in the sets' autosave debounce, keyed by
  /// [OcptShotListPendingEditKey], holding the raw text last typed for it.
  ///
  /// What a set tab shows takes this map's entry over its own stored value whenever one is
  /// present, so typing is never overwritten by a reload triggered by an unrelated write. An entry
  /// is removed the moment its write lands, when the set is unlinked from the sequence, and when
  /// the mode's catalogue no longer holds the set.
  final Map<OcptShotListPendingEditKey, String> pendingFieldEdits;

  /// The floor plans canvas's own current zoom (1.0 = neutral/100%), last **settled** by
  /// `OcptFloorPlanViewportController` — see that class's own doc comment for why only the settled
  /// value, not every per-frame one, ever reaches this state.
  ///
  /// A **view preference** held here for the session alone, never persisted to the project or to
  /// `OcptPropertiesManager` (`docs/adr/0031-storyboard-panels-and-floor-plans-in-metres.md`: zoom
  /// is a view concern, kept out of the synchronised model). It exists in this state at all only so
  /// a fresh `OcptFloorPlanView` (built again after switching centre views, or after leaving and
  /// reopening the mode) resumes at the zoom the user last settled on rather than always resetting
  /// to 100%.
  final double floorPlanZoom;

  /// The layer a placed set element lands on, picked from the palette's own set/scene group; the
  /// shot layers group is picked separately.
  ///
  /// A **view/session state** value, like [floorPlanZoom]: never written to the project.
  final OcptFloorPlanLayer floorPlanActiveLayer;

  /// The décor primitive a `setElement` click-to-arm placement carries — which of the palette's
  /// own four typed set-element entries (wall/door/furniture/freeform) was armed last.
  ///
  /// A **view/session state** value, like [floorPlanZoom]: never written to the project.
  final OcptFloorPlanSetElementShape floorPlanActiveSetElementShape;

  /// The scope a `setElement` click-to-arm placement lands at — the palette's own `Set`
  /// group arms [OcptFloorPlanScope.set], its `Sequence` group's own furniture/freeform pair arms
  /// [OcptFloorPlanScope.scene].
  ///
  /// A **view/session state** value, like [floorPlanZoom]: never written to the project.
  final OcptFloorPlanScope floorPlanActiveSetElementScope;

  /// A `prop` click-to-arm placement's own armed label — which breakdown-prop chip, or the
  /// `Other…` chip's own typed-in text, was armed last.
  ///
  /// A **view/session state** value, like [floorPlanZoom]: never written to the project.
  final String floorPlanActiveLabel;

  /// The focused sequence's own breakdown props — the palette's own `Sequence` group chips.
  /// Read again whenever the mode loads or selects another sequence, and emptied meanwhile.
  final List<OcptScenePropSummary> propsOfSelectedSequence;

  /// The sequence layers currently hidden on the floor plans canvas, out of the tray's own three
  /// rows. Empty means every sequence layer is shown — the tray's own default.
  ///
  /// A **view/session state** value, like [floorPlanZoom]: never written to the project.
  final Set<OcptFloorPlanLayer> floorPlanHiddenLayers;

  /// Whether the selected set's underlay is currently hidden on the floor plans canvas, toggled
  /// by the tray's own underlay row.
  ///
  /// A **view/session state** value, like [floorPlanZoom]: never written to the project.
  final bool isFloorPlanUnderlayHidden;

  /// The ids of every camera symbol currently hidden on the floor plans canvas, out of every live
  /// camera of the selected sequence — the tray's own per-camera eyes, under the `Sequence` focus's
  /// expanded cameras row. Empty means every camera is shown.
  ///
  /// A **view/session state** value, like [floorPlanZoom]: never written to the project.
  final Set<String> floorPlanHiddenCameraSymbolIds;

  /// Whether the onion skin's own previous-shot ghost is shown, under a shot focus.
  ///
  /// A **view/session state** value, like [floorPlanZoom]: never written to the project.
  final bool isFloorPlanOnionSkinPreviousShown;

  /// Whether the onion skin's own next-shot ghost is shown, under a shot focus.
  ///
  /// A **view/session state** value, like [floorPlanZoom]: never written to the project.
  final bool isFloorPlanOnionSkinNextShown;

  /// The onion skin's own ghost opacity, 0..1, the tray's own `Onion skin` block slider.
  ///
  /// A **view/session state** value, like [floorPlanZoom]: never written to the project.
  final double floorPlanOnionSkinOpacity;

  /// Whether the metrics overlay is shown, the tray's own metrics toggle: the distance from the
  /// selected symbol to every other visible symbol of the set, and camera-to-subject for a
  /// selected camera.
  ///
  /// A **view/session state** value, like [floorPlanZoom]: never written to the project.
  final bool isFloorPlanMetricsShown;

  /// Whether the last write the sets bloc made failed; shown as a transient SnackBar then
  /// dismissed.
  final bool hasWriteError;

  /// Class constructor
  const OcptShotListFloorPlanSetsState({
    required this.pendingFieldEdits,
    required this.floorPlanZoom,
    required this.floorPlanActiveLayer,
    required this.floorPlanActiveSetElementShape,
    required this.floorPlanActiveSetElementScope,
    required this.floorPlanActiveLabel,
    required this.propsOfSelectedSequence,
    required this.floorPlanHiddenLayers,
    required this.isFloorPlanUnderlayHidden,
    required this.floorPlanHiddenCameraSymbolIds,
    required this.isFloorPlanOnionSkinPreviousShown,
    required this.isFloorPlanOnionSkinNextShown,
    required this.floorPlanOnionSkinOpacity,
    required this.isFloorPlanMetricsShown,
    required this.hasWriteError,
  });

  /// Builds the state of floor plans nothing has been done on yet.
  const OcptShotListFloorPlanSetsState.init()
    : pendingFieldEdits = const {},
      floorPlanZoom = 1,
      floorPlanActiveLayer = OcptFloorPlanLayer.set,
      floorPlanActiveSetElementShape = OcptFloorPlanSetElementShape.wall,
      floorPlanActiveSetElementScope = OcptFloorPlanScope.set,
      floorPlanActiveLabel = "",
      propsOfSelectedSequence = const [],
      floorPlanHiddenLayers = const {},
      isFloorPlanUnderlayHidden = false,
      floorPlanHiddenCameraSymbolIds = const {},
      isFloorPlanOnionSkinPreviousShown = true,
      isFloorPlanOnionSkinNextShown = true,
      floorPlanOnionSkinOpacity = 0.4,
      isFloorPlanMetricsShown = false,
      hasWriteError = false;

  /// {@macro act_flutter_utility.BlocStateForMixin.copyWith}
  @override
  OcptShotListFloorPlanSetsState copyWith({
    Map<OcptShotListPendingEditKey, String>? pendingFieldEdits,
    double? floorPlanZoom,
    OcptFloorPlanLayer? floorPlanActiveLayer,
    OcptFloorPlanSetElementShape? floorPlanActiveSetElementShape,
    OcptFloorPlanScope? floorPlanActiveSetElementScope,
    String? floorPlanActiveLabel,
    List<OcptScenePropSummary>? propsOfSelectedSequence,
    Set<OcptFloorPlanLayer>? floorPlanHiddenLayers,
    bool? isFloorPlanUnderlayHidden,
    Set<String>? floorPlanHiddenCameraSymbolIds,
    bool? isFloorPlanOnionSkinPreviousShown,
    bool? isFloorPlanOnionSkinNextShown,
    double? floorPlanOnionSkinOpacity,
    bool? isFloorPlanMetricsShown,
    bool? hasWriteError,
  }) => OcptShotListFloorPlanSetsState(
    pendingFieldEdits: pendingFieldEdits ?? this.pendingFieldEdits,
    floorPlanZoom: floorPlanZoom ?? this.floorPlanZoom,
    floorPlanActiveLayer: floorPlanActiveLayer ?? this.floorPlanActiveLayer,
    floorPlanActiveSetElementShape:
        floorPlanActiveSetElementShape ?? this.floorPlanActiveSetElementShape,
    floorPlanActiveSetElementScope:
        floorPlanActiveSetElementScope ?? this.floorPlanActiveSetElementScope,
    floorPlanActiveLabel: floorPlanActiveLabel ?? this.floorPlanActiveLabel,
    propsOfSelectedSequence: propsOfSelectedSequence ?? this.propsOfSelectedSequence,
    floorPlanHiddenLayers: floorPlanHiddenLayers ?? this.floorPlanHiddenLayers,
    isFloorPlanUnderlayHidden: isFloorPlanUnderlayHidden ?? this.isFloorPlanUnderlayHidden,
    floorPlanHiddenCameraSymbolIds:
        floorPlanHiddenCameraSymbolIds ?? this.floorPlanHiddenCameraSymbolIds,
    isFloorPlanOnionSkinPreviousShown:
        isFloorPlanOnionSkinPreviousShown ?? this.isFloorPlanOnionSkinPreviousShown,
    isFloorPlanOnionSkinNextShown:
        isFloorPlanOnionSkinNextShown ?? this.isFloorPlanOnionSkinNextShown,
    floorPlanOnionSkinOpacity: floorPlanOnionSkinOpacity ?? this.floorPlanOnionSkinOpacity,
    isFloorPlanMetricsShown: isFloorPlanMetricsShown ?? this.isFloorPlanMetricsShown,
    hasWriteError: hasWriteError ?? this.hasWriteError,
  );

  /// Copies this state with [props] as the props of the selected sequence.
  OcptShotListFloorPlanSetsState copyWithSequenceProps({
    required List<OcptScenePropSummary> props,
  }) => copyWith(propsOfSelectedSequence: props);

  /// Copies this state with no prop for the selected sequence.
  OcptShotListFloorPlanSetsState copyWithSequencePropsCleared() =>
      copyWith(propsOfSelectedSequence: const []);

  /// Copies this state with [pendingFieldEdits] as the set names waiting in the debounce, a
  /// keystroke later.
  OcptShotListFloorPlanSetsState copyWithTypedFieldEdits({
    required Map<OcptShotListPendingEditKey, String> pendingFieldEdits,
  }) => copyWith(pendingFieldEdits: pendingFieldEdits);

  /// Copies this state with [pendingFieldEdits] as what is still pending once an unlinked set's
  /// own edits are gone.
  OcptShotListFloorPlanSetsState copyWithUnlinkedSetEdits({
    required Map<OcptShotListPendingEditKey, String> pendingFieldEdits,
  }) => copyWith(pendingFieldEdits: pendingFieldEdits);

  /// Copies this state with no field edit left pending.
  OcptShotListFloorPlanSetsState copyWithFieldEditsCleared() =>
      copyWith(pendingFieldEdits: const {});

  /// Copies this state with [pendingFieldEdits] as what the write that just landed left pending.
  OcptShotListFloorPlanSetsState copyWithFlushedFieldEdits({
    required Map<OcptShotListPendingEditKey, String> pendingFieldEdits,
  }) => copyWith(pendingFieldEdits: pendingFieldEdits);

  /// Copies this state with the write error raised, [pendingFieldEdits] being what the failed
  /// flush left pending.
  OcptShotListFloorPlanSetsState copyToFlushFailed({
    required Map<OcptShotListPendingEditKey, String> pendingFieldEdits,
  }) => copyWith(hasWriteError: true, pendingFieldEdits: pendingFieldEdits);

  /// Copies this state with the canvas zoom settled at [zoom].
  OcptShotListFloorPlanSetsState copyWithZoom({required double zoom}) =>
      copyWith(floorPlanZoom: zoom);

  /// Copies this state with [layer] as the layer a placed set element lands on.
  OcptShotListFloorPlanSetsState copyWithActiveLayer({required OcptFloorPlanLayer layer}) =>
      copyWith(floorPlanActiveLayer: layer);

  /// Copies this state with [shape] as the décor primitive a placement carries.
  OcptShotListFloorPlanSetsState copyWithActiveSetElementShape({
    required OcptFloorPlanSetElementShape shape,
  }) => copyWith(floorPlanActiveSetElementShape: shape);

  /// Copies this state with [scope] as the scope a set element placement lands at.
  OcptShotListFloorPlanSetsState copyWithActiveSetElementScope({
    required OcptFloorPlanScope scope,
  }) => copyWith(floorPlanActiveSetElementScope: scope);

  /// Copies this state with [label] as the label a prop placement carries.
  OcptShotListFloorPlanSetsState copyWithActiveLabel({required String label}) =>
      copyWith(floorPlanActiveLabel: label);

  /// Copies this state with [hiddenLayers] as the layers hidden on the canvas.
  OcptShotListFloorPlanSetsState copyWithHiddenLayers({
    required Set<OcptFloorPlanLayer> hiddenLayers,
  }) => copyWith(floorPlanHiddenLayers: hiddenLayers);

  /// Copies this state with the selected set's underlay visibility flipped.
  OcptShotListFloorPlanSetsState copyWithUnderlayVisibilityToggled() =>
      copyWith(isFloorPlanUnderlayHidden: !isFloorPlanUnderlayHidden);

  /// Copies this state with [symbolIds] as the camera symbols hidden on the canvas.
  OcptShotListFloorPlanSetsState copyWithHiddenCameraSymbols({required Set<String> symbolIds}) =>
      copyWith(floorPlanHiddenCameraSymbolIds: symbolIds);

  /// Copies this state with the onion skin's previous ghost flipped when [isPrevious], its next
  /// ghost otherwise.
  OcptShotListFloorPlanSetsState copyWithOnionSkinToggled({required bool isPrevious}) => isPrevious
      ? copyWith(isFloorPlanOnionSkinPreviousShown: !isFloorPlanOnionSkinPreviousShown)
      : copyWith(isFloorPlanOnionSkinNextShown: !isFloorPlanOnionSkinNextShown);

  /// Copies this state with [opacity] as the onion skin's ghost opacity.
  OcptShotListFloorPlanSetsState copyWithOnionSkinOpacity({required double opacity}) =>
      copyWith(floorPlanOnionSkinOpacity: opacity);

  /// Copies this state with the metrics overlay flipped.
  OcptShotListFloorPlanSetsState copyWithMetricsToggled() =>
      copyWith(isFloorPlanMetricsShown: !isFloorPlanMetricsShown);

  /// Copies this state with the write error raised.
  OcptShotListFloorPlanSetsState copyToWriteFailed() => copyWith(hasWriteError: true);

  /// Copies this state with the write error dismissed.
  OcptShotListFloorPlanSetsState copyWithWriteErrorDismissed() => copyWith(hasWriteError: false);

  /// {@macro act_flutter_utility.BlocStateForMixin.props}
  @override
  List<Object?> get props => [
    ...super.props,
    pendingFieldEdits,
    floorPlanZoom,
    floorPlanActiveLayer,
    floorPlanActiveSetElementShape,
    floorPlanActiveSetElementScope,
    floorPlanActiveLabel,
    propsOfSelectedSequence,
    floorPlanHiddenLayers,
    isFloorPlanUnderlayHidden,
    floorPlanHiddenCameraSymbolIds,
    isFloorPlanOnionSkinPreviousShown,
    isFloorPlanOnionSkinNextShown,
    floorPlanOnionSkinOpacity,
    isFloorPlanMetricsShown,
    hasWriteError,
  ];
}
