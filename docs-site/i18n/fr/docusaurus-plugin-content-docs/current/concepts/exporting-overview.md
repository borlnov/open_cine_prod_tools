<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: CC-BY-4.0
-->

# Exporter, en bref

## Un seul geste, partout

Chaque export se fait depuis **un seul endroit : la commande `Exporter` de la barre d'outils**.
Elle est présente dans tous les modes qui savent produire un document, si bien qu'exporter est
toujours la même action, au même endroit.

Un clic sur **Exporter** ouvre le **panneau d'export** : une grille de cartes, **une par
document**. Chaque carte montre le nom du document, une courte description et son format
(`PDF`, `XLSX` ou `.fountain`).

- Un document qui ne peut pas être produit pour l'instant reste **affiché mais grisé**, et sa
  description est remplacée par la **raison** (par exemple : aucune journée encore planifiée).
  Le panneau vous dit ainsi toujours tout ce que le mode sait produire.
- Choisir une carte ouvre la **fenêtre d'options** du document (quand il y en a), puis un
  **dialogue « Enregistrer sous » natif**. **Rien n'est jamais écrit en silence** à un
  emplacement par défaut : vous choisissez toujours où va chaque fichier.

## Portée d'un export

Quand un export dépend d'un épisode, il produit **l'épisode sélectionné**. Le nom de fichier
proposé inclut alors une étiquette d'épisode (par exemple `ep. 2`), **uniquement** si le projet
compte plusieurs épisodes — de sorte qu'exporter deux épisodes dans le même dossier n'écrase
rien.

## Envoyer le projet entier

Sous la grille des documents, une carte à part exporte **le projet lui-même** en un unique
fichier `.ocptz` que vous pouvez transmettre. La même action est disponible sans ouvrir le
projet, depuis le menu **⋮** d'une carte de l'accueil — c'est d'ailleurs la seule façon
d'envoyer un projet dont le fichier est dans un ancien format sans le migrer.

## Voir aussi

La liste complète des documents, mode par mode, est rassemblée dans
[Exporter votre travail](../exports/exporting-your-work.md).
