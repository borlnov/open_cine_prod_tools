// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/types/ocpt_resources_tab.dart';

/// What a mode being switched to should land on, handed over by the mode asking for the switch.
///
/// A mode switch normally lands wherever the target mode's own default is. This is the exception:
/// a mode that sends the user somewhere *for a reason* — the breakdown's `Open in Resources`, which
/// means "this very element, over there" — says so with one of these, carried by
/// `OcptWorkspaceModeSelectedEvent` and held in `OcptWorkspaceState` until the mode that was opened
/// consumes it.
///
/// `OcptWorkspaceBloc` never reads inside one: it transports the request and clears it, which keeps
/// it about *which mode is active* and nothing about a mode's own content (ADR 0006). Only the mode
/// that recognizes its own subtype acts on it, and a mode handed a subtype it doesn't know simply
/// ignores it.
///
/// It is deliberately **one-shot**: consumed on the first load of the mode it opened, so returning
/// to that mode later — or the reload a project version preview triggers — lands on the mode's own
/// default again rather than re-revealing something the user has since navigated away from.
sealed class OcptWorkspaceRevealRequest extends Equatable {
  /// Class constructor
  const OcptWorkspaceRevealRequest();

  /// Object properties
  @override
  List<Object?> get props => [];
}

/// Asks the resources mode to open [tab] with the record [recordId] names already selected, so its
/// sheet is what the centre shows.
///
/// [recordId] is read against [tab]'s own catalogue: a person id on [OcptResourcesTab.people], a
/// role id on [OcptResourcesTab.roles], a **location** id on [OcptResourcesTab.locations] and an
/// element id on [OcptResourcesTab.elements]. A set has no sheet of its own — it lives in the sets
/// card of the location that holds it — so revealing a set means revealing that location, and it is
/// the asking mode's job to resolve `OcptSet.locationId` before building this.
final class OcptResourcesRevealRequest extends OcptWorkspaceRevealRequest {
  /// The tab to open.
  final OcptResourcesTab tab;

  /// The id of the record to select in [tab]'s own catalogue, or null to open [tab] with nothing
  /// selected on it — the asking mode having a tab to name and no record to name on it.
  ///
  /// An id that names nothing in the catalogue (a row tombstoned since the request was built) is
  /// read exactly like null: the mode never shows a sheet for a record it cannot find.
  final String? recordId;

  /// Class constructor
  const OcptResourcesRevealRequest({required this.tab, this.recordId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, tab, recordId];
}
