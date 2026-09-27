# Ressources

<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: CC-BY-4.0
-->

Le mode Ressources répond à la question : « qui tourne le film, où, et avec quoi ? » Il
s'organise en quatre onglets dans le panneau de gauche — **Personnes**, **Rôles** (le casting),
**Décors** et **Éléments**. Sélectionner une fiche ouvre au centre sa feuille éditable (qui est
elle-même l'inspecteur), avec un onglet **Versions** partagé à droite.

![Le mode Ressources et une fiche de personne](/img/screenshots/resources.png)

## Le carnet d'adresses (Personnes)

Personnes est votre liste de contacts maîtresse. Une personne n'apparaît qu'**une fois**, quel
que soit le nombre de casquettes qu'elle porte : la même personne peut être un rôle du casting,
un poste de l'équipe et le propriétaire d'un décor, sans que son nom soit jamais recopié.

- **Photo** : l'avatar de l'en-tête est un emplacement, pas un champ. Un menu permet de
  référencer une photo, puis de choisir une couleur de repli. Une photo référencée apparaît
  d'elle-même dans la liste et sur l'avatar du casting.
- **Édition** : les champs libres s'enregistrent seuls, avec un court délai. Un champ mal rempli
  (une adresse e-mail invalide, par exemple) est **signalé** sans refuser ce que vous avez tapé.
- **Suppression** : la feuille se termine par **Supprimer cette personne**, qui **demande
  d'abord** confirmation.

## Le casting (Rôles)

Rôles est la liste du casting. Les rôles sont **réconciliés depuis le scénario** plutôt que
saisis : chaque personnage du script — qu'il soit signalé dans un dialogue ou seulement nommé en
majuscules dans une action — reçoit un rôle. On peut aussi en ajouter à la main.

**Distribuer un rôle**, c'est le relier à une personne (jamais recopier un nom). Vous pouvez le
faire directement depuis le sélecteur de l'en-tête du rôle, ou passer par des **candidatures** :

- La feuille du rôle liste qui a été vu pour le personnage. Chaque candidature porte un statut,
  une date d'audition, des notes privées, et le classement de la direction de casting.
- Huit statuts : *repéré, à rencontrer, vu, présélectionné, retenu, non retenu, s'est désisté,
  indisponible*. L'ordre est une commodité de lecture, pas un parcours imposé.
- **Retenir** une candidature distribue le rôle et bascule automatiquement les autres
  candidatures encore en lice sur « non retenu ». La candidature retenue est épinglée en tête.

**La garde-robe d'un rôle** (ce qu'un rôle porte, transporte, avec quoi il est maquillé) s'ajoute
depuis la feuille du rôle, puisée dans le même catalogue d'**Éléments**. Supprimer un rôle ne
supprime jamais l'élément : un manteau survit au personnage qui l'a porté.

## Décors et sous-décors

Un **décor** (lieu) contient un ou plusieurs **sous-décors** ; le sous-décor est ce qui
appartient au lieu. Le lieu d'un sous-décor se choisit à sa création et ne se change qu'en
**déplaçant** le sous-décor vers un autre lieu — un sous-décor mal classé se répare, il ne se
supprime pas. Les séquences se relient à des sous-décors. Le **code** d'un sous-décor (A, B… AA)
est attribué par l'application, numéroté sur tout le projet, et jamais saisi.

## Le catalogue des éléments

Un **élément** est tout ce qui doit être présent un jour de tournage et n'est pas une personne :
accessoires, costumes, véhicules, animaux… dans un seul catalogue, avec une catégorie et une
sous-catégorie libre. Les mêmes colonnes de suivi s'appliquent à tout : propriétaire, qui
l'apporte, sécurisé, prêt, rendu, et où. Son **code** (par exemple PRP-3) est attribué par
l'application et réécrit si vous changez sa catégorie.

## Photos et documents

Photos et documents sont **référencés par leur chemin, jamais incorporés**. Une fiche pointe
simplement vers un fichier ; un fichier manquant est une situation **normale et attendue**, pas
une erreur.

## Confirmations

Chaque suppression sur une feuille — personne, rôle, sous-décor, élément — et **Retirer ce
candidat** demandent d'abord confirmation, par un dialogue dont le libellé varie selon l'action.

## Les deux documents

- **Classeur (XLSX)** à quatre feuilles : personnes, rôles, décors, éléments.
- **Liste de contacts (PDF)** — toute l'équipe et le casting sur une feuille à faire circuler,
  groupés par département. Il n'y a délibérément **aucune adresse postale**, puisque cette
  feuille circule auprès de tout le monde.

Une recherche dans la barre d'outils filtre la liste de l'onglet actif, en ignorant les accents
(« lea » trouve « Léa »).
