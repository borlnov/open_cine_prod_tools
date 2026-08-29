<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: CC-BY-4.0
-->

# Premiers pas

Au lancement, l'application ouvre son **écran d'accueil** : la porte d'entrée vers vos projets.

![L'écran d'accueil et une carte de projet récent](/img/screenshots/home.png)

## L'écran d'accueil

L'accueil présente une **grille de cartes**, une par projet récent (jusqu'à dix). Chaque carte
porte une teinte « affiche » tirée d'une petite palette, calculée à partir du chemin du fichier :
un projet garde donc **la même couleur** d'un lancement à l'autre et d'une machine à l'autre.
Une pastille **⟨N épisodes⟩** apparaît sur les projets qui en comptent plusieurs.

En haut de l'accueil, deux actions :

- **Nouveau** — créer un projet. L'application écrit alors un fichier `.ocpt` à l'emplacement
  que vous choisissez.
- **Ouvrir…** — sélectionner un fichier `.ocpt` existant sur le disque.

Cliquer sur une carte rouvre le projet correspondant. Le menu **⋮** d'une carte permet aussi
d'**exporter** le projet en paquet portable sans même l'ouvrir.

## Créer votre premier projet

1. Cliquez sur **Nouveau**.
2. Choisissez où enregistrer le fichier `.ocpt` et donnez-lui un nom.
3. L'application ouvre l'**espace de travail** sur le mode Scénario.

Vous êtes prêt·e à écrire. Un nouveau projet commence avec un seul épisode ; vous pourrez le
transformer en série plus tard (voir [Projets et épisodes](../concepts/projects-and-episodes.md)).

## Importer plutôt que partir de zéro

Si vous avez déjà un scénario, l'accueil propose un bouton **Importer…** avec deux choix :

- **Un projet** — un paquet `.ocptz` qu'on vous a envoyé.
- **Un scénario** — un fichier `.fountain`, `.fdx` (Final Draft) ou `.celtx` (Celtx). Les deux
  derniers sont convertis en Fountain à l'import.

## Se repérer ensuite

L'espace de travail est le même cadre autour de tous les outils. La page
[L'espace de travail](workspace-tour.md) en fait le tour.
