# Fountain, la source de vérité

<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: CC-BY-4.0
-->

## Qu'est-ce que le Fountain

Le **Fountain** est un format de scénario en texte simple : on écrit le scénario dans un texte
ordinaire, et quelques conventions (une ligne en majuscules devient un nom de personnage, une
ligne `INT.`/`EXT.` devient un en-tête de séquence…) suffisent à le mettre en forme. C'est un
format ouvert, lisible tel quel, qui ne vous enferme dans aucun logiciel.

Vous n'avez pas à connaître ces conventions pour écrire : le mode Scénario propose un éditeur
qui met tout en forme pour vous. Mais il est utile de savoir que, **sous le capot, votre
scénario est du Fountain**.

## Pourquoi c'est important

Dans Open Cine Prod Tools, le texte du scénario est le **cœur du projet**. Les autres modes ne
recopient pas ce texte : ils s'y **accrochent**.

- Le **découpage** relie chaque plan aux passages exacts du scénario qu'il couvre.
- Le **dépouillement** étiquette des passages du scénario pour remplir les catalogues des
  ressources.
- Le **plan de travail** place des plans, qui renvoient à des séquences.

Résultat : quand le scénario change, l'application sait ce qui est touché et vous prévient (par
exemple, un plan dont le texte couvert a bougé est signalé « à vérifier »). C'est aussi pourquoi
tout part de bonnes fondations : un scénario propre rend le reste du travail fiable.

## Un vocabulaire à connaître

Dans l'interface française, une **séquence** désigne ce que le métier appelle une séquence de
scénario (le terme « scène » y nomme autre chose). Le seul endroit qui garde le mot « scène »
est l'expression consacrée « mise en scène », dans les notes de réalisation du découpage.

Pour la mise en forme concrète, reportez-vous à l'[aide-mémoire de la syntaxe
Fountain](../reference/fountain-cheatsheet.md).
