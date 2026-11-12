# L'espace de travail

<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: CC-BY-4.0
-->

Dès qu'un projet est ouvert, vous êtes dans l'**espace de travail** : le même cadre autour de
chaque outil de production. Il se compose de quatre zones.

## Les quatre zones

- **La barre d'outils, en haut.** À gauche, le titre du projet et le **sélecteur d'épisode** ;
  au centre, les actions propres au mode actif ; à droite, les commandes fixes de l'espace :
  le nom du mode, **Exporter**, les deux boutons qui ouvrent ou ferment les panneaux latéraux,
  la commande d'**enregistrement** (un indicateur tourne pendant la sauvegarde), les
  **réglages du projet**, l'**aide** et le menu **⋮**. Une commande qu'un mode n'utilise pas
  n'apparaît tout simplement pas.
- **Les panneaux latéraux (docks).** À gauche et à droite, des panneaux que l'on ouvre, ferme
  et redimensionne en glissant leur bord. Leur contenu dépend du mode.
- **La zone centrale**, où se fait le travail du mode actif.
- **La barre d'état, en bas**, qui affiche des compteurs vivants (nombre de pages, de
  séquences, de plans…) selon le mode.

## Le sélecteur de mode

Une bande en bas de la fenêtre choisit le mode. Les six modes sont rangés dans l'ordre du
travail :

1. **Scénario** (écrire) ;
2. **Dépouillement** ;
3. **Découpage** ;
4. **Ressources** ;
5. **Plan de travail** ;
6. **Budget** (qui lit les chiffres de tous les autres, donc en dernier).

Cliquez sur une entrée pour changer de mode ; toutes sont toujours accessibles. L'application
**retient le dernier mode utilisé** et y revient à la réouverture du projet.

## Le sélecteur d'épisode

Quand un projet compte plusieurs épisodes, le sélecteur placé juste après le titre choisit
l'épisode que le mode courant affiche. Il n'apparaît que lorsqu'il est utile : il est masqué
pour un projet à épisode unique, ainsi qu'en **Plan de travail** (qui lit tous les épisodes à
la fois) et en **Budget** (qui n'est pas découpé par épisode).

Changer d'épisode **recharge le mode à neuf** : la sélection en cours (un plan mis en évidence,
la position de défilement…) est perdue à chaque changement. À l'ouverture, un projet commence
toujours sur le premier épisode.

## Enregistrement et versions

L'application enregistre au fil de l'eau ; l'indicateur d'enregistrement de la barre d'outils
tourne pendant la sauvegarde. Pour poser des jalons volontaires — des instantanés que vous
pourrez restaurer — utilisez les **versions de projet**, décrites dans
[Versions de projet](../concepts/project-versions.md).
