// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_life_cycle/act_life_cycle.dart';
import 'package:act_logger_manager/act_logger_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_changeset_service.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_folder_remote_storage.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_merge_service.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_remote_storage.dart';

/// Builds the [OcptSyncManager] instance registered by the global manager.
class OcptSyncManagerBuilder extends AbsLifeCycleFactory<OcptSyncManager> {
  /// Class constructor
  const OcptSyncManagerBuilder() : super(OcptSyncManager.new);

  /// {@macro act_life_cycle.AbsLifeCycleFactory.dependsOn}
  @override
  Iterable<Type> dependsOn() => [LoggerManager, OcptPropertiesManager, OcptProjectsManager];
}

/// Owns a project's own side of `docs/plans/collaboration-and-sync.md`'s changeset engine (M3):
/// turning local writes into changesets and applying incoming ones, per-column merge, the
/// screenplay's own three-way text merge, and the transport those changesets and snapshots travel
/// over.
///
/// This step of that plan lands [changesetService]'s **inbound** half on top of the outbound one
/// that shipped before it: [OcptMergeService], the per-column resolver
/// [changesetService].`pullAndApply` hands every incoming changeset to, is what actually makes two
/// replicas pointed at the same [OcptRemoteStorage] converge — plus the [OcptRemoteStorage] seam and
/// [OcptFolderRemoteStorage], the directory transport that exercises the whole engine with no
/// network at all and stays afterwards as the desktop fallback
/// (`docs/adr/0009-offline-first-sync-through-a-domain-blind-relay.md`). The screenplay's own
/// three-way text merge for `fountainText` follows in a later step — until then that column merges
/// like any other, last-writer-wins (see [OcptMergeService]'s own doc comment). This manager depends
/// on [OcptPropertiesManager] (the device id a changeset is stamped with) and [OcptProjectsManager]
/// (the open project a changeset is generated from and applied to) for exactly that reason, ahead of
/// the code that reads either one.
class OcptSyncManager extends AbsWithLifeCycle {
  /// The service turning a replica's own un-pushed local edits into a changeset, appending it to a
  /// relay, and applying every changeset a relay holds that this replica hasn't seen yet.
  final OcptChangesetService changesetService;

  /// Class constructor
  const OcptSyncManager({this.changesetService = const OcptChangesetService()});

  /// Opens the directory transport rooted at [directory].
  ///
  /// This is the one [OcptRemoteStorage] implementation the changeset engine has to exercise
  /// against today; a relay implementation talking HTTP and a WebSocket is handed back the same
  /// way once the relay itself exists.
  OcptRemoteStorage openFolderRemoteStorage(Directory directory) => OcptFolderRemoteStorage(directory);
}
