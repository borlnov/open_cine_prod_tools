# Versions de projet

<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: CC-BY-4.0
-->

## Ce que c'est

Une **version de projet** est un instantané nommé, permanent et en lecture seule, de **tout le
projet** — votre propre point de repère. C'est l'équivalent d'un « enregistrer sous, daté et
étiqueté » : vous posez un jalon avant une décision importante, et vous pouvez toujours y
revenir.

Les versions se gèrent depuis l'onglet **Versions** des panneaux latéraux, présent dans tous
les modes puisqu'il concerne le projet et non le mode.

## Le panneau Versions

Le panneau se lit de haut en bas, du présent vers l'histoire scellée :

- en tête, la **carte du travail en cours** : des compteurs vivants, l'indication de savoir si
  l'état actuel correspond encore à sa version de base, et un bouton **Créer une version** ;
- en dessous, une **carte par version** enregistrée.

## Les gestes

Toutes ces actions sont confirmées **à l'intérieur même de la carte** concernée, une à la fois
— sans fenêtre séparée, parce qu'une liste de cartes a besoin de dire *laquelle*.

- **Créer** : cliquez sur **Créer une version** dans la carte du travail en cours, puis
  nommez-la.
- **Prévisualiser** : cliquez sur une carte de version pour entrer dans son aperçu en lecture
  seule ; cliquez à nouveau pour en sortir (voir [L'aperçu en lecture
  seule](read-only-preview.md)).
- **Restaurer** : dans le menu de la carte, choisissez **Restaurer cette version**. C'est une
  **modification, pas un effacement** : l'état remplacé est lui-même enregistré comme une
  nouvelle version (nommée « Avant restauration de … »), si bien qu'un retour en arrière n'est
  jamais définitif.
- **Renommer** : l'action **Renommer** de la carte.
- **Supprimer** : l'action **Supprimer** de la carte retire définitivement cet instantané. La
  version que vous êtes en train de prévisualiser peut être restaurée, mais pas supprimée.

:::tip

Ces versions que vous créez sont distinctes des sauvegardes automatiques du seul scénario, que
l'application garde en coulisse. Les versions de projet sont vos jalons volontaires, sur le
projet entier.

:::
