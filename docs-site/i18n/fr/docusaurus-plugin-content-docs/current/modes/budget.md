<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: CC-BY-4.0
-->

# Budget

## À quoi sert ce mode

Le Budget est là où vit l'argent de la production, du premier devis jusqu'au partage des
recettes. Il sert deux lecteurs à la fois à partir des mêmes chiffres : une **commission** ou un
financeur qui attend des documents formels, et une petite équipe qui tient un simple livre de
comptes. Il tient quatre choses côte à côte :

- le **devis** — votre budget prévisionnel, rangé selon les catégories du CNC ;
- le **journal de caisse** — chaque euro entré ou sorti du compte, plus ce qui est dû mais pas
  encore payé ;
- le **plan de financement** — ce qui paie le film ;
- le **partage des recettes** — une fois le film gagnant, qui touche quoi.

Le mode s'organise en quatre onglets : **Tableau de bord**, **Dépenses**, **Ressources** et
**Outils** (un tiroir avec trois utilitaires : Flux de trésorerie, Régie, Partage).

## La règle de l'argent

Chaque montant est stocké **exactement tel que vous l'avez tapé** et n'est jamais changé en
douce. Quelques conséquences visibles :

- Chaque montant retient s'il a été saisi **TTC** (par défaut) ou **HT**, et quel taux de TVA
  s'applique. Un interrupteur d'en-tête fait basculer le devis d'une base à l'autre.
- Si aucun taux n'est renseigné, l'application laisse les chiffres dérivés **vides** plutôt que
  de deviner. Elle vous dit « 6 catégories couvertes sur 9 » au lieu d'imprimer un faux total.
- L'argent **réellement déplacé** se lit toujours TTC : un solde bancaire n'a qu'une lecture
  honnête.

## Le devis contre la nomenclature CNC

La **nomenclature CNC** est le plan de comptes standard qu'attend une commission française : dix
**postes** de tête (par exemple *Transports, défraiements, régie*). L'application les crée
automatiquement à la première ouverture du budget. Ces dix postes sont un **point de départ, pas
une cage** : on les renomme, réordonne, scinde ou supprime comme n'importe quelle ligne.

Pour construire un devis :

1. allez dans l'onglet **Dépenses** ; ajoutez un poste (`+ Poste`) ou utilisez les dix du CNC ;
2. sélectionnez un poste et choisissez **Ajouter** pour créer une **ligne** (un libellé, une
   quantité, un prix unitaire). Le total d'un poste est la simple somme de ses lignes ;
3. au besoin, **Depuis le dépouillement** tire les éléments du script, chacun rangé sous son
   poste.

## Le journal de caisse et les engagements

Le **journal de caisse** (Outils › Flux de trésorerie) est votre vrai livre de comptes : chaque
écriture, débit ou crédit, dans l'ordre où l'argent a bougé, avec un solde courant et un numéro
de pièce (J-001, J-002…). Son solde est toujours celui du compte entier.

- Les **dépenses hors devis sont nommées, pas cachées** : un ticket pour ce que le CNC n'avait
  pas prévu apparaît dans une ligne *Hors devis*, pour que votre total dépensé colle au réel.
- Un **engagement** est une dette : quelque chose commandé et dû mais pas encore payé. Il se
  **solde tout seul** dès que les paiements qui le nomment atteignent le montant dû — pas de
  case « payé » à cocher. La plupart du temps, le bouton d'une ligne est simplement **Payer
  {total}** : l'engagement est créé de façon invisible derrière le paiement. On peut aussi
  **Engager cette ligne…** d'abord, et payer par échéances.

Le rapport de coût d'un poste montre cinq lectures : **Devis, Engagé, Payé, Reste à dépenser**
et **Coût final**, avec les colonnes d'écart.

## Le plan de financement et la régie

L'onglet **Ressources** est ce qui paie le film. Il groupe trois familles : **subventions**,
**apports** (en numéraire ou en nature) et **recettes**. Une jauge en pied montre la couverture
en deux tons : ce qui est **promis** et ce qui est **réellement arrivé**. Un apport **en nature**
est *valorisé, pas encaissé* : sa valeur est notée, mais aucun argent n'est attendu contre lui.

La **Régie** (Outils › Régie) est la passe cantine et transport, lue dans deux sens :

- **colonne de gauche, calculée** : ce que chaque journée coûte en repas et en-cas, lu
  directement sur votre plan de travail ;
- **colonne de droite, saisie** : le compte des **défraiements** par personne. Les défraiements
  de transport peuvent être chiffrés à partir d'un **barème** kilométrique.

Une bande propose de **provisionner** ces chiffres calculés dans le devis, sans jamais écraser
un montant que vous avez corrigé à la main.

## Le partage des recettes

La vue **Partage** (Outils › Partage) répartit ce que le film gagne. La règle est arithmétique :
**les recettes entrent, les apports remboursables sont retirés en premier, et seul le reste est
partagé.** La part de chaque participant s'exprime en pour mille. L'application partage au plus
juste, laisse visible le centime restant, et **énonce les parts sans les policer** : si elles ne
font pas 100 %, elle vous le montre plutôt que de bloquer. On paie quelqu'un avec **Enregistrer
un versement** ; le « payé » se lit sur le journal, jamais un compteur stocké.

## Les quatre exports

Depuis la commande **Exporter**, chacun enregistré par un dialogue natif :

- **Devis** (PDF) — toute la nomenclature CNC, poste par poste. Le seul export qui propose une
  base de TVA.
- **Plan de financement** (PDF) — ce qui paie le film, les apports en nature tenus visiblement à
  part.
- **Journal de caisse** (XLSX) — chaque écriture dans l'ordre où l'argent a bougé, avec son
  numéro de pièce.
- **Rapport financier** (PDF) — le devis lu contre le payé et l'engagé, avec l'écart et une
  ligne *Hors devis*.

Toutes les règles d'honnêteté des écrans valent pour les documents : un total incomplet imprime
une note de couverture, un solde illisible imprime une case vide, et un export impossible (aucun
poste, aucune ressource, aucune écriture) est grisé avec sa raison.
