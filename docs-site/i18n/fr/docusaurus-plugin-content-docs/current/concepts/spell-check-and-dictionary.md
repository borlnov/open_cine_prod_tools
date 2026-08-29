<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: CC-BY-4.0
-->

# Correction orthographique et dictionnaire de projet

## Comment fonctionne la correction

La correction s'exécute **au fil de la frappe**, dans les deux modes d'édition du scénario. Elle
utilise des dictionnaires **français et anglais britannique** fournis avec l'application :
aucune connexion Internet ni service du système n'est requis.

Elle vérifie la **prose** et laisse la **forme du scénario tranquille** : les en-têtes de
séquence, les noms de personnage et les transitions ne sont jamais soulignés, pas plus que les
mots tout en majuscules ou contenant des chiffres.

Pour qu'un mot soit vérifié, **deux réglages** doivent être actifs :

- la **langue du scénario**, propre au projet (dans les réglages du projet) — l'option **Aucune**
  désactive la correction pour ce projet ;
- **Afficher la correction**, propre à cette machine (dans le menu **⋮**).

## Corriger un mot

Dans l'éditeur stylé, faites un **clic droit** sur un mot souligné : jusqu'à cinq suggestions
apparaissent, ainsi que **Ignorer ce mot** (le temps de la session) et **Ajouter au
dictionnaire du projet**.

## Le dictionnaire de projet

Les mots que vous apprenez à l'application voyagent **dans le fichier `.ocpt`** : ils suivent le
projet sur la machine d'un collègue.

- Un mot est stocké **tel que vous l'avez tapé** et reconnu sans tenir compte de la casse.
- Pour le gérer, ouvrez les **réglages du projet → section Dictionnaire** (elle affiche le
  nombre de mots) et cliquez sur **Modifier…**. La fenêtre permet de **lire, filtrer, ajouter
  et supprimer** des mots. La suppression d'un mot est confirmée **dans sa propre ligne**
  (`Supprimer ? / Oui / Non`), pour élaguer une longue liste sans qu'une fenêtre surgisse à
  chaque mot.
