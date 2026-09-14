# Projets et épisodes

<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: CC-BY-4.0
-->

## Un projet, un fichier

Un projet Open Cine Prod Tools tient dans un **seul fichier `.ocpt`** sur votre disque. Il
contient tout : le scénario, le dépouillement, le découpage, les ressources, le plan de travail
et le budget. Pour sauvegarder ou partager un projet, il suffit de copier ce fichier — ou de
l'exporter en paquet portable (voir [Exporter, en bref](exporting-overview.md)).

## Un projet, plusieurs épisodes

Une série, une mini-série ou un film tourné en parties vivent dans un **même fichier**. Un
projet contient un **scénario par épisode**, mais **une seule** équipe, un seul carnet
d'adresses, un seul jeu de décors et un seul plan de travail. C'est ce qui permet de tourner
une série dans le désordre : une même journée de tournage couvre couramment des séquences de
deux épisodes dans un même décor.

Chaque mode qui dépend d'un épisode affiche celui que le **sélecteur d'épisode** de la barre
d'outils désigne. Deux modes lisent au contraire l'ensemble des épisodes : le **Plan de
travail** et le **Budget** — ils n'ont donc pas de sélecteur.

## Numérotation des séquences

Dès qu'un projet compte plus d'un épisode, les numéros de séquence se lisent
`épisode.séquence` — par exemple `2.12` pour la douzième séquence du deuxième épisode. Un projet
à épisode unique affiche des numéros simples. Le texte du scénario n'est jamais renuméroté :
c'est l'épisode qui est nommé à côté de la page.

## Gérer les épisodes

- **Ajouter un premier épisode supplémentaire** : dans un projet à épisode unique, la barre
  d'outils du mode Scénario propose un bouton **Ajouter un épisode…**. C'est le geste qui
  transforme un projet en série.
- **Ensuite** : tout se gère depuis les **réglages du projet → carte Épisodes** — ajouter,
  renommer sur place, réordonner avec `▲` / `▼`, supprimer. La suppression est confirmée et
  liste exactement ce qu'elle retire. L'entrée **Gérer les épisodes…** du sélecteur y conduit
  directement.
