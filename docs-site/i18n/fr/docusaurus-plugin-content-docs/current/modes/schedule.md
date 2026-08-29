<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: CC-BY-4.0
-->

# Plan de travail

## À quoi sert ce mode

Le Plan de travail est là où vous décidez **quand** le film se tourne. Il vient après le
découpage, car ce que l'on place sur une journée, c'est un plan. Il répond à la question du
bureau de production : quelles séquences, quelle équipe, quel casting et quels décors se
retrouvent à quelles dates, et à quelles heures.

![Le mode Plan de travail et une journée](/img/screenshots/schedule.png)

C'est le seul mode qui regarde **tout le projet à la fois** — tous les épisodes ensemble — d'où
l'absence de sélecteur d'épisode. Une même journée couvre couramment des séquences de deux
épisodes dans un décor.

## Les objets que vous manipulez

- **Journées de tournage.** Chaque journée est datée. Son numéro — le `J3` qu'imprime une feuille
  de service — n'est pas une étiquette figée mais un **rang dans l'ordre des dates** : redatez
  une journée et tout le plan se renumérote.
- **Créneaux.** Une journée contient un ou plusieurs créneaux. Un créneau est une unité de
  travail avec son décor, son équipe et ses horaires propres — souvent deux dans une journée
  réelle (une unité du matin, une du soir).
- **Blocs.** L'emploi du temps d'un créneau est fait de blocs : plans, réserves, répétitions,
  auditions, et le temps autour (préparation, HMC, repas, pauses, trajets, fin de journée). On
  les glisse en place ou on les décale par pas de cinq minutes.
- **Le modèle horaire, en clair.** Vous ne remplissez jamais une colonne d'heures. Vous épinglez
  **un seul** bord d'un créneau — « on a le lieu jusqu'à 22:00 » ou « départ au lever du jour » —
  et tout le reste se calcule en enchaînant les durées des blocs. Les nuits qui passent minuit
  sont gérées. Chaque bloc porte une note privée (jamais imprimée) et une **note équipe** (qui,
  elle, s'imprime).
- **Événements.** Ce que la journée ne contrôle pas — le feu d'artifice du village à 17:00 —
  se pose à une heure absolue et ne pousse rien.

## Les quatre vues

- **Vue Journée** — la surface de travail. Une carte par créneau, chacune avec une section
  « Affecter des personnes » (équipe, casting, invités) et son emploi du temps. C'est là qu'on
  place des plans, qu'on glisse des blocs, qu'on fixe l'état d'un plan.
- **Agenda** — trois présentations : une **bande** (ce que porte chaque journée), une **semaine**
  en grille horaire teintée par les heures de soleil, et un **mois**. Un contrôle « Colorer par »
  teinte les journées par décor ou par effet INT/EXT jour/nuit.
- **Matrice des postes** — postes × créneaux : quel poste est couvert sur quelle unité, chaque
  colonne coiffée des heures résolues du créneau.
- **Grille de présence** — personnes × journées, avec le décompte des jours travaillés de
  chacun. Les cases sont calculées (au travail, indisponible, ou vide) et rien n'y est éditable.

## Convocations

Une convocation **est le créneau** auquel vous reliez la personne. Vous ne tapez jamais d'heure
de convocation. Reliez une personne, un rôle ou un invité à un créneau, et ses horaires en sont
lus : l'**arrivée** est le début de créneau le plus tôt, la bande **PAT** (*prêt à tourner*) va
du premier au dernier bloc de tournage, le **départ** est la dernière fin de créneau. Pour faire
venir un acteur tôt au maquillage, on crée un créneau à 06:00 (nommé `HMC`) et on l'y relie — le
fichier dit alors exactement ce qui se passe. Les invités reçoivent une arrivée et un départ,
mais jamais de bande.

## Les alertes

Le mode lève dix sortes d'alertes. **Dures** : une personne convoquée alors qu'elle est
indisponible ; une personne en double sur deux créneaux qui se chevauchent ; un créneau hors de
toute fenêtre déclarée par son décor. **Douces** : un rôle placé mais convoqué sur aucun créneau ;
un rôle sans acteur ; un dépassement d'horaire contre un bord épinglé ; une journée au-delà du
maximum d'une personne ; un repos sous le minimum du projet ; une autorisation de décor qui ne
couvre pas la date. Les alertes vivent dans un onglet dédié, la barre d'état en porte le compte,
et chaque journée en défaut porte un badge.

## Les documents

Le Plan de travail produit les documents dont une production a besoin :

- **Feuilles de service** (générale et nominatives) — un PDF par personne ; la nominative
  ajoute sa bande arrivée / PAT / départ et un tableau « À apporter ».
- **Plan de travail détaillé (PDF)** — tout le tournage : grilles de synthèse (décors,
  séquences, équipe/casting, éléments) et agenda par journée.
- **Plan de travail (XLSX)** — le même plan en tableur modifiable, avec une feuille chronologie.
- **Day Out of Days** — le plan du casting, une ligne par rôle, avec les codes SW/W/WF/H.
- **Plan de travail synthétique** — une bande compacte, une ligne par séquence dans l'ordre de
  tournage, lue comme un ordre sans colonne d'heures.
- **Pages du jour** — les vraies pages du scénario des séquences d'une journée.

Chaque export liste toutes les journées, chaque heure est celle qui a été résolue, et les
numéros de séquence s'impriment déjà sous la forme `2.12`.
