// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <benoit.rolandeau@allcircuits.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';

/// The collapsible left panel listing the screenplay's scenes.
///
/// Each entry shows the scene's number (when the heading carries one) and its heading text; the
/// scene containing the editor caret is highlighted. Clicking an entry asks the editor to move
/// its caret to that scene's start (via [onSceneSelected]).
class OcptEditorScenePanel extends StatelessWidget {
  /// The panel's fixed width.
  static const double _width = 240;

  /// The scene headings to list, in source order.
  final List<FountainSceneHeading> scenes;

  /// The 0-based source line the editor caret is currently on, used to highlight the current
  /// scene.
  final int currentLine;

  /// Called when a scene is clicked, with the character offset its heading starts at.
  final ValueChanged<int> onSceneSelected;

  /// Class constructor
  const OcptEditorScenePanel({
    super.key,
    required this.scenes,
    required this.currentLine,
    required this.onSceneSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentSceneIndex = _currentSceneIndex;

    return SizedBox(
      width: _width,
      child: ColoredBox(
        color: theme.colorScheme.surfaceContainerLow,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      Tr.of(context).editorScenesPanelTitle,
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  Text(
                    "${scenes.length}",
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: scenes.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        Tr.of(context).editorScenesEmptyHint,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: scenes.length,
                      itemBuilder: (context, index) => _SceneEntry(
                        scene: scenes[index],
                        isCurrent: index == currentSceneIndex,
                        onTap: () => onSceneSelected(scenes[index].sourceRange.startOffset),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// The index, in [scenes], of the scene containing [currentLine] (the last scene starting at
  /// or before it), or null if the caret precedes every scene.
  int? get _currentSceneIndex {
    int? candidate;
    for (var index = 0; index < scenes.length; index++) {
      if (scenes[index].sourceRange.startLine <= currentLine) {
        candidate = index;
      } else {
        break;
      }
    }

    return candidate;
  }
}

/// One clickable scene row of the panel: the scene number (when present) followed by the heading
/// text, highlighted when the scene contains the editor caret.
class _SceneEntry extends StatelessWidget {
  /// The scene heading this row displays.
  final FountainSceneHeading scene;

  /// Whether this scene contains the editor caret.
  final bool isCurrent;

  /// Called when the row is clicked.
  final VoidCallback onTap;

  /// Class constructor
  const _SceneEntry({required this.scene, required this.isCurrent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sceneNumber = scene.sceneNumber;

    return InkWell(
      onTap: onTap,
      child: ColoredBox(
        color: isCurrent ? theme.colorScheme.primary.withValues(alpha: 0.14) : Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (sceneNumber != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    sceneNumber,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              Expanded(
                child: Text(
                  scene.headingText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isCurrent ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant,
                    fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
