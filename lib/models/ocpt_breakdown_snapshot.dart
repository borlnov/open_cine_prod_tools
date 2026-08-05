// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_scene.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_tag.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_target.dart';
import 'package:open_cine_prod_tools/models/ocpt_element.dart';
import 'package:open_cine_prod_tools/models/ocpt_location.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_set.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_scene_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_status.dart';

/// The whole breakdown mode's read, in one object: [scenes] with their own tags, the [targets] every
/// tag resolves to, and the four counts the mode's header and status bar show.
///
/// Built the same way `OcptResourcesSnapshot.build` is: a pure function of already-loaded lists,
/// with no database access of its own. [scenes] comes from `OcptBreakdownService.loadScenes` (tags
/// left empty), `tags` from `OcptBreakdownService.loadTags`, and `elements`/`roles`/`sets` from
/// `OcptElementsService.loadElements`, `OcptRoleIndexService.loadRoles` and
/// `OcptLocationsService.loadLocations`'s own sets — combining the calls into this one object is the
/// job of the mode that reads them.
class OcptBreakdownSnapshot extends Equatable {
  /// The screenplay this breakdown belongs to.
  final String screenplayId;

  /// Every scene of [screenplayId], in source order, each already carrying its own live tags.
  final List<OcptBreakdownScene> scenes;

  /// One [OcptBreakdownTarget] per **tagged** thing, ordered by kind then by name so the recap's
  /// grouping is deterministic.
  ///
  /// A catalogue row nobody tagged is not a target of this snapshot at all — it is unreachable from
  /// the script view and has nothing to recap — even though it may well sit among the `elements`/
  /// `roles`/`sets` passed to [OcptBreakdownSnapshot.build].
  final List<OcptBreakdownTarget> targets;

  /// The whole `elements` catalogue, verbatim, as passed to [OcptBreakdownSnapshot.build].
  ///
  /// [OcptBreakdownTarget] deliberately carries only the two fields the script view's highlighting
  /// and the recap need (`category`/`status`, see that class's own doc comment); the target
  /// inspector's Details section reads the raw row for the rest — sub-category, quantity, notes, the
  /// owner and who brings it — rather than the model growing fields only one caller wants.
  final List<OcptElement> elements;

  /// The whole address book, verbatim, as passed to [OcptBreakdownSnapshot.build] — what the target
  /// inspector's owner and who-brings-it pickers offer, and what resolves an element's
  /// `ownerPersonId`/`broughtByPersonId` into a name.
  final List<OcptPerson> people;

  /// The whole cast, verbatim, as passed to [OcptBreakdownSnapshot.build] — kept for the same
  /// reason [elements] is: the tag popover's search (`ocptBreakdownSearchCandidatesOf`) has to
  /// offer a role that has never been tagged before, which [targets] alone cannot answer, since a
  /// catalogue row nobody tagged yet is not a target of this snapshot at all.
  final List<OcptRole> roles;

  /// The whole set catalogue, verbatim, as passed to [OcptBreakdownSnapshot.build] — the sibling of
  /// [roles], for the same reason. Flattened across the locations: a set carries the id of the one
  /// holding it ([OcptSet.locationId]), and [locationNameById] is what turns that into a name.
  final List<OcptSet> sets;

  /// The whole location catalogue, verbatim, as passed to [OcptBreakdownSnapshot.build] — each
  /// location still carrying its own sets, which [sets] is the flattening of.
  ///
  /// Carried whole rather than as a name lookup because two callers need more than the names: the
  /// tag popover offers these as the places a set it creates may go into, and
  /// `ocptSceneSetSuggestionOf` reads a location's name *and* its sets to answer what a heading
  /// suggests. [locationNameById] is the lookup itself, derived here so no caller builds its own.
  final List<OcptLocation> locations;

  /// `targets.length`: the status bar's "N targets tagged".
  final int taggedTargetCount;

  /// The number of distinct palette entries across [targets] — an element category, or the role/set
  /// kinds, each counting once no matter how many targets share it.
  final int usedCategoryCount;

  /// The number of [targets] whose [OcptBreakdownTarget.status] is [OcptElementStatus.toFind]. A
  /// role or a set has no status ([OcptBreakdownTarget.status] is null for either) and never counts
  /// here.
  final int toFindCount;

  /// The number of [scenes] whose [OcptBreakdownScene.status] is [OcptBreakdownSceneStatus.done] —
  /// the mode header's progress bar.
  final int doneSceneCount;

  /// The number of live tags, across the whole screenplay, whose [OcptBreakdownTag.needsCheck] is
  /// set — the status bar's own "N to check" counter. Counted off the raw tags passed to
  /// [OcptBreakdownSnapshot.build] rather than off [targets]: a tag whose catalogue row has been
  /// tombstoned is dropped from [targets] (its own doc comment) but is still a live tag a save
  /// could have flagged, and the scene inspector's own "to check" alert must still list it.
  final int needsCheckTagCount;

  /// Class constructor
  const OcptBreakdownSnapshot({
    required this.screenplayId,
    required this.scenes,
    required this.targets,
    required this.elements,
    required this.people,
    required this.roles,
    required this.sets,
    required this.locations,
    required this.taggedTargetCount,
    required this.usedCategoryCount,
    required this.toFindCount,
    required this.doneSceneCount,
    required this.needsCheckTagCount,
  });

  /// Builds an [OcptBreakdownSnapshot] for [screenplayId] by joining [scenes] (with empty tags),
  /// [tags] and the three catalogues [elements]/[roles]/[sets], deriving [targets] and the four
  /// counts from them. [people], [elements], [roles] and [sets] are all carried through verbatim —
  /// see their own doc comments for why the inspector and the tag popover need the raw rows rather
  /// than the derived [targets] alone.
  ///
  /// A tag pointing at a catalogue row that is gone — tombstoned underneath, so it no longer appears
  /// in [elements]/[roles]/[sets] — is **dropped from [targets] but kept on its scene**: the tag row
  /// is still live and the script must keep showing something at that passage, but there is no sheet
  /// left behind it to list in the recap or the inspector.
  factory OcptBreakdownSnapshot.build({
    required String screenplayId,
    required List<OcptBreakdownScene> scenes,
    required List<OcptBreakdownTag> tags,
    required List<OcptElement> elements,
    required List<OcptRole> roles,
    required List<OcptSet> sets,
    required List<OcptLocation> locations,
    required List<OcptPerson> people,
  }) {
    final tagsBySceneId = <String, List<OcptBreakdownTag>>{};
    for (final tag in tags) {
      tagsBySceneId.putIfAbsent(tag.sceneId, () => []).add(tag);
    }
    for (final sceneTags in tagsBySceneId.values) {
      sceneTags.sort((a, b) => a.startOffset.compareTo(b.startOffset));
    }

    final scenesWithTags = [
      for (final scene in scenes)
        scene.copyWith(tags: tagsBySceneId[scene.id] ?? const <OcptBreakdownTag>[]),
    ];

    final positionBySceneId = {for (final scene in scenes) scene.id: scene.position};
    final elementById = {for (final element in elements) element.id: element};
    final roleById = {for (final role in roles) role.id: role};
    final setById = {for (final set in sets) set.id: set};

    final tagsByTarget = <(OcptBreakdownTargetKind, String), List<OcptBreakdownTag>>{};
    for (final tag in tags) {
      tagsByTarget.putIfAbsent((tag.targetKind, tag.targetId), () => []).add(tag);
    }

    final targets = <OcptBreakdownTarget>[];
    for (final MapEntry(key: (kind, targetId), value: targetTags) in tagsByTarget.entries) {
      final String name;
      OcptElementCategory? category;
      OcptElementStatus? status;
      switch (kind) {
        case OcptBreakdownTargetKind.element:
          final element = elementById[targetId];
          if (element == null) {
            continue;
          }
          name = element.name;
          category = element.category;
          status = element.status;
        case OcptBreakdownTargetKind.role:
          final role = roleById[targetId];
          if (role == null) {
            continue;
          }
          name = role.name;
        case OcptBreakdownTargetKind.set:
          final set = setById[targetId];
          if (set == null) {
            continue;
          }
          name = set.name;
      }

      final sceneIds = <String>{for (final tag in targetTags) tag.sceneId}.toList()
        ..sort((a, b) => (positionBySceneId[a] ?? 0).compareTo(positionBySceneId[b] ?? 0));

      targets.add(
        OcptBreakdownTarget(
          kind: kind,
          id: targetId,
          name: name,
          category: category,
          status: status,
          sceneIds: sceneIds,
          occurrenceCount: targetTags.length,
        ),
      );
    }

    targets.sort((a, b) {
      final kindCompare = a.kind.index.compareTo(b.kind.index);
      return kindCompare != 0 ? kindCompare : a.name.compareTo(b.name);
    });

    return OcptBreakdownSnapshot(
      screenplayId: screenplayId,
      scenes: scenesWithTags,
      targets: targets,
      elements: elements,
      people: people,
      roles: roles,
      sets: sets,
      locations: locations,
      taggedTargetCount: targets.length,
      usedCategoryCount: targets.map((target) => target.color).toSet().length,
      toFindCount: targets.where((target) => target.status == OcptElementStatus.toFind).length,
      doneSceneCount: scenes
          .where((scene) => scene.status == OcptBreakdownSceneStatus.done)
          .length,
      needsCheckTagCount: tags.where((tag) => tag.needsCheck).length,
    );
  }

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptBreakdownSnapshot(screenplayId: $screenplayId, sceneCount: ${scenes.length}, "
      "taggedTargetCount: $taggedTargetCount, usedCategoryCount: $usedCategoryCount, "
      "toFindCount: $toFindCount, doneSceneCount: $doneSceneCount, "
      "needsCheckTagCount: $needsCheckTagCount)";

  /// The name of every location of [locations], keyed by id — what names the place a set belongs
  /// to.
  ///
  /// A set has no sheet of its own, so it is only ever shown *somewhere*: the scene inspector's own
  /// sets row and the tag popover's set group both read a set as `<set> · <location>`
  /// (`ocptBreakdownSetLabel`), two sets called `Cuisine` in two houses being the very case the
  /// catalogue exists to tell apart.
  Map<String, String> get locationNameById => {
    for (final location in locations) location.id: location.name,
  };

  /// Object properties
  @override
  List<Object?> get props => [
    screenplayId,
    scenes,
    targets,
    elements,
    people,
    roles,
    sets,
    locations,
    taggedTargetCount,
    usedCategoryCount,
    toFindCount,
    doneSceneCount,
    needsCheckTagCount,
  ];
}
