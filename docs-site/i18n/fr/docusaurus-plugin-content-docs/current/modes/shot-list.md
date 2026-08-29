<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: CC-BY-4.0
-->

# Découpage

## À quoi sert le découpage

Le mode Découpage est là où vous découpez le scénario **plan par plan**. Chaque séquence du
scénario devient une ligne ; à l'intérieur, vous écrivez les plans que vous comptez tourner, en
décrivant l'image (valeur de plan, cadre, mouvement de caméra, optique, format), la difficulté,
le son, vos notes de **mise en scène** et les personnages présents. Vous notez aussi la
**couverture** de chaque plan : quels passages exacts de la séquence écrite ce plan filme.

![Le mode Découpage et le tableau des plans](/img/screenshots/shot-list.png)

## La disposition de l'écran

Trois zones, toutes redimensionnables (le menu **⋮** → **Réinitialiser la disposition**
restaure les réglages) :

- **Panneau de gauche — l'arbre des séquences.** Une ligne par séquence, avec son numéro (dans
  la couleur d'accent), son en-tête et un résumé (nombre de plans · difficulté moyenne). Cliquez
  une séquence pour la sélectionner ; elle se déplie et liste ses plans. Un groupe spécial
  **« orphelins »** rassemble les plans dont la séquence a été supprimée du scénario — supprimer
  une séquence ne détruit jamais ses plans. Le pied de panneau porte le bouton **`+ Plan`**.
- **Centre — le tableau des plans.** Un tableau dense, en lecture seule, des plans de la
  séquence sélectionnée. Colonnes toujours présentes : code du plan, personnages, valeur de
  plan, cadre, mouvement de caméra, difficulté. Le menu **`Colonnes ▾`** en ajoute d'autres
  (décor, optique, format, durée, prises, son, jour de tournage, état). Cliquer une ligne
  sélectionne le plan et ouvre l'inspecteur — pas d'édition dans le tableau.
- **Panneau de droite — le dock à onglets** : **Inspecteur** (éditer le plan), **Métadonnées**
  (résumé en lecture seule) et **Versions**.
- **Barre d'état** : nombre de séquences, total de plans, plans tournés, plans à vérifier.

## Ajouter, éditer, supprimer un plan

- **Ajouter** : sélectionnez une vraie séquence (pas le groupe des orphelins), puis **`+ Plan`**.
  Un plan est créé à la fin de la séquence et sélectionné.
- **Éditer** : cliquez un plan pour ouvrir l'**inspecteur**, puis modifiez les champs sur place.
  Les champs texte s'enregistrent seuls quelques secondes après que vous cessez de taper.
- **Réordonner** : les codes de plan sont `séquence/rang` et se déduisent automatiquement ;
  l'application renumérote après une suppression.
- **Supprimer** : **`Supprimer le plan`** en bas de l'inspecteur (ou le bouton de suppression de
  la ligne, pour un plan orphelin). Les deux demandent confirmation.

## L'inspecteur du plan

L'inspecteur regroupe : un en-tête avec le code et une pastille d'**état**, plus un encart **« à
vérifier »** quand le texte couvert a changé ; **Personnages** (des pastilles à activer, tirées
du scénario) ; **Couverture** (voir ci-dessous) ; **Image** (valeur de plan, abréviation, cadre,
mouvement, optique, format d'enregistrement) ; **Difficulté** (quatre axes — décor, mouvement,
jeu, son — notés de 0 à 5, dont la moyenne s'affiche et rougit en montant) ; **Production**
(durée estimée en m:ss, notes de son) ; **Notes** (mise en scène) ; **Repérage** (notes de
lieu).

## La couverture — relier un plan au scénario

La section **Couverture** liste, en lecture seule, les extraits que le plan filme, avec un
compteur « N mots couverts sur M » et le code des autres plans qui couvrent le même texte. Pour
la modifier, cliquez **`Sélectionner…`** : une fenêtre montre la séquence composée sur une
feuille, en police de scénario. **Cliquez un mot pour ouvrir une plage, cliquez de nouveau pour
la fermer** (une plage peut traverser plusieurs blocs) ; cliquer un texte déjà couvert retire
cette plage. La couverture de votre plan apparaît en surbrillance forte, celle des autres plans
en léger lavis. **`Tout effacer`** retire toutes les plages.

Si le scénario change ensuite, les extraits touchés reçoivent un badge **Modifié** et le plan
est signalé à vérifier — vous levez le drapeau avec **Marquer comme vérifié**.

## Ce que ce mode exporte

- **Classeur du découpage (XLSX)** — une feuille, une ligne par plan portant tous ses champs
  (code, personnages, décor, valeur de plan, cadre, mouvement, optique, format, durée, prises,
  son, difficulté, jour, état, notes).
- **PDF de couverture du scénario** — votre scénario imprimé normalement, avec une **barre de
  couleur en marge** le long de chaque passage qu'un plan couvre ; les passages qu'aucun plan ne
  couvre sont estompés. Chaque plan a sa couleur (unique dans sa séquence). Une fenêtre d'options
  propose le format de page, la page de titre, les numéros de séquence, une page de légende et
  une page de résumé.

:::note

Le **jour de tournage** et les **prises prévues** apparaissent ici, mais c'est le mode Plan de
travail qui les possède : le découpage ne fait que les afficher.

:::
