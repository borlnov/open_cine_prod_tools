# Découpage

<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: CC-BY-4.0
-->

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
- **Centre — le tableau des plans, le storyboard ou les plans au sol.** Un sélecteur **`Tableau
  · Storyboard · Plans au sol`** dans l'en-tête central bascule cette zone entre le tableau dense
  décrit ci-dessous, le [storyboard](#le-storyboard) et les [plans au sol](#plans-au-sol). Les
  trois vues partagent l'arbre des séquences à gauche, le dock à droite et le plan que vous avez
  sélectionné.
- **Le tableau des plans**, la vue par défaut des trois : un tableau dense, en lecture seule, des
  plans de la séquence sélectionnée. Colonnes toujours présentes : code du plan, personnages,
  valeur de plan, cadre, mouvement de caméra, difficulté. Le menu **`Colonnes ▾`** en ajoute
  d'autres (décor, optique, format, durée, prises, son, jour de tournage, état). Cliquer une
  ligne sélectionne le plan et ouvre l'inspecteur — pas d'édition dans le tableau.
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

## Le storyboard

Basculez l'en-tête central sur **Storyboard** pour disposer les images de référence de chaque
plan au lieu de sa ligne dans le tableau. L'arbre des séquences, le dock et le plan sélectionné
restent les mêmes que dans les deux autres vues — choisir un plan ici est la même sélection que
celle du tableau et des plans au sol.

![Le storyboard, avec les panneaux d'un plan et sa fiche meneuse](/img/screenshots/shot-list-board.png)

### Les panneaux

Un plan peut porter **plusieurs panneaux** — son début et sa fin, ou un par cadre distinct —
chacun une petite carte dans le bandeau du plan. **Importer une image** amène un JPEG ou un PNG
depuis le disque ; l'image est **référencée par son chemin**, comme toute photo et tout document
du projet, jamais copiée dans le fichier. **Remplacer l'image** change le cadre d'un panneau sans
toucher à son commentaire ni à ses annotations. Le ratio d'un panneau suit le format
d'enregistrement du plan, avec un repli en 16:9 quand aucun n'est défini, pour qu'un storyboard
mélangeant les formats reste honnête plutôt que de forcer chaque panneau à la même forme.

Faites glisser un panneau pour le réordonner dans le bandeau, ou utilisez **Déplacer plus tôt** /
**Déplacer plus tard**. Le menu **Taille des panneaux** (Petite / Moyenne / Grande) règle la
place que le bandeau donne à chacun. Le champ **commentaire** sous un panneau est du texte libre
— une note pour le cadreur, un rappel sur un accessoire. À côté des panneaux, une **fiche
meneuse** affiche toujours les informations de découpage du plan (valeur de plan, cadre,
mouvement de caméra), pour ne jamais perdre de vue ce que vous storyboardez en faisant défiler
ses images.

**Supprimer le panneau** retire pour de bon son image, son commentaire et ses annotations, et
demande confirmation.

### Les annotations

Marquez directement l'image d'un panneau avec les outils **flèche de mouvement** (comment
quelque chose bouge dans le cadre — un acteur qui traverse, une voiture qui passe), **flèche de
mouvement de caméra** (comment la caméra elle-même bouge — un pano, un travelling, une poussée)
et **étiquette** — un marquage léger, pas un nouveau dessin du cadre. Cliquez une marque pour la
sélectionner, puis **Supprimer la marque** ; comme toute suppression dans le mode, cela demande
confirmation.

## Plans au sol

Basculez l'en-tête central sur **Plans au sol** pour une vue schématique, vue de dessus, du décor
où sont mis en scène les plans d'une séquence : où sont les murs et le mobilier, où pointe chaque
caméra, où se tiennent les comédiens et les lumières.

![Un plan au sol, avec son décor dessiné, des caméras placées et un personnage dans la pièce](/img/screenshots/shot-list-floor-plan.png)

### Un plan appartient à son décor, pas à une séquence

Un plan au sol est le plan d'un **décor** Resources — un plan par décor, partagé par toute
séquence qui s'y lie, que ce soit depuis la ligne des décors du [dépouillement](breakdown.md) ou
depuis la galerie de ce mode ci-dessous. L'édition reste ici, dans le découpage ; la fiche du
décor dans [Resources](resources.md) ne montre qu'un indicateur et une action **Ouvrir dans le
découpage** (voir plus bas).

Ce que vous dessinez se situe à l'une de **trois portées** :

```text
Décor · Cuisine — partagé par toute la séquence   murs, portes, mobilier, le fond
Séquence 7 — cette séquence seulement             mobilier redisposé, accessoires de la séquence
Plan 7/3 — ce plan seulement                      caméras, personnages, lumières, flèches
```

Concrètement : une cuisine est filmée par les séquences 3 et 7. Les murs, le plan de travail et
le réfrigérateur sont de portée **Décor** — dessinez-les une fois et les deux séquences les
montrent. Dans la séquence 7, la table est poussée contre le mur pour une fête ; c'est un
changement de portée **Séquence**, fait une fois pour la séquence 7 et laissé intact dans la
séquence 3. La position de la caméra, les personnages présents dans la pièce et la lumière clé du
plan 7/3 sont de portée **Plan** : ils n'appartiennent qu'à ce seul plan, et le plan 7/4 de la
même séquence peut placer sa propre caméra sans les déranger.

### Lier un décor à une séquence

Une séquence sans décor lié affiche une **galerie d'état vide** : une carte par décor déjà
dessiné dans le projet, avec sa propre vignette, la suggestion de l'en-tête de séquence étoilée
et listée en premier. Cliquez une carte pour lier ce décor ; **Créer un décor…** ouvre le même
sélecteur que le bouton **`＋ Décor`**. Le menu de ce bouton propose le décor suggéré en premier,
**Lier un décor existant** (groupé par lieu), **Créer un décor** (dans un lieu existant, ou un
nouveau), puis, une fois un décor lié, **Dupliquer ce décor** (une copie indépendante, dans le
même lieu) et **Copier le placement d'un plan…** (reprendre les caméras, personnages et lumières
d'un autre plan sur celui-ci).

Délier un décor d'une séquence garde le plan du décor lui-même ; la fenêtre compte ce qui
disparaît de la vue de cette séquence (« 4 caméras, 2 personnages et 3 accessoires y sont placés :
ils reviennent si vous liez à nouveau ce décor »).

### Dessiner le décor — les trois groupes de la palette

La palette le long du canevas nomme **où atterrit un élément placé** :

- **`Décor · <nom> — partagé`** — les outils mur, porte, mobilier et forme libre, pour ce qui
  appartient à la pièce elle-même. Faites glisser un outil sur le canevas, ou cliquez pour
  l'armer puis cliquez le canevas pour placer, puis dessinez ou redimensionnez-le en mètres.
- **`Séquence <n> — cette séquence seulement`** — des puces pour les accessoires du
  dépouillement de la séquence en cours (les éléments étiquetés du [dépouillement](breakdown.md)),
  chacun placé avec son propre nom, plus une puce **`Autre…`** pour un libellé libre ; et le
  mobilier redisposé de cette séquence.
- **`Plan <code> — ce plan seulement`** — caméra, personnage et lumière, pour ce qui n'appartient
  qu'à ce seul plan.
- **`Affichage`** — la visibilité des calques, le fond, la pelure d'oignon, les mesures et les
  bascules de champ de vision (voir plus bas). Aucun outil n'est jamais grisé : placer ou
  déplacer quelque chose est simplement retenu sous un aperçu en lecture seule.

### Caméras, personnages et le fond

Une caméra garde le **numéro du plan auquel elle appartient** : un plan avec une seule caméra se
lit `3`, et dès qu'une deuxième caméra rejoint le même plan les deux sont lettrées (`3A`, `3B`) —
un numéro manquant sur le bandeau de focus est un plan encore à placer. Faites glisser le **cône
de champ de vision** d'une caméra par ses poignées de bord pour élargir ou resserrer l'angle, et
par sa **poignée de pointe** pour régler sa portée ; faites-la pivoter en visant sa poignée vers
où elle doit pointer.

Placer un **personnage** demande son nom sur-le-champ, en suggérant d'abord les personnages du
plan — le nommer ne modifie jamais le champ personnages du plan, puisque n'importe qui peut se
trouver physiquement dans la pièce. Un **fond** — un plan au sol photographié ou une photo de
lieu, JPEG ou PNG, référencé par son chemin — se place derrière tout le reste ; **Importer un
fond** en amène un, que vous redimensionnez et déplacez librement pour l'aligner sur la barre
d'échelle. **Remplacer le fond** et **Effacer le fond** (qui demande confirmation) le gèrent
ensuite.

Rien ici n'est calé sur une grille : le plan est schématique, sa géométrie stockée en mètres. Une
silhouette de personnage de taille étalon et une barre d'échelle, toujours visibles en bas,
reflètent le zoom en cours. Activez **Afficher les mesures** pour voir la distance entre l'objet
sélectionné et chaque autre objet visible (ou, une caméra sélectionnée, jusqu'à son sujet) — le
petit bouton d'aide à côté de la bascule l'explique, pour quand une infobulle est hors de portée
sur un écran tactile.

### Pelure d'oignon et parcourir les plans

Un **bandeau de focus** en bas liste les plans de la séquence en pastilles — un point plein
signifie que le plan a déjà une caméra sur le décor affiché, un point creux qu'il n'en a pas
encore — et les flèches du clavier permettent de passer de l'un à l'autre. La **pelure d'oignon**
fait apparaître en fantôme les caméras et personnages du plan précédent et/ou suivant par-dessus
le plan courant, avec un curseur d'opacité, pour cadrer un plan par rapport à ses voisins sans
perdre de vue lequel est lequel. **Recentrer** recadre le canevas sur le contenu du plan à tout
moment ; ouvrir un décor depuis Resources ou changer d'onglet fait de même automatiquement.

### Déplacer un élément partagé — la question de portée

Déplacer, pivoter ou redimensionner un élément de portée **Décor** utilisé par deux séquences ou
plus fait apparaître, dans une petite bulle sur l'élément lui-même : **`Toutes les séquences
(n)`** / **`Seulement la séq. 7`** / **`Annuler`**. Un décor utilisé par une seule séquence se
déplace simplement — rien à demander. La même question se pose une portée plus bas : modifier un
élément de portée **Séquence** (un accessoire, ou un élément du décor déjà surchargé pour cette
séquence) sur une séquence de deux plans ou plus demande **`Toute la séquence`** / **`Seulement
le plan 7/3`** / **`Annuler`**. **Le placement ne demande jamais** — le groupe de la palette d'où
vous avez fait glisser a déjà décidé la portée.

Répondre « seulement celle-ci » écrit une **surcharge** : un contour pointillé et une pastille
l'indiquent, l'original reste visible en fantôme léger, et l'inspecteur propose **Rétablir comme
dans le décor** (ou **Rétablir comme dans la séquence**) pour lever la surcharge.

### Supprimer

Supprimer un élément partagé pose la même question par la fenêtre de confirmation, étendue d'une
troisième option : **`Annuler`** / **`Retirer de la séquence 7`** (ou **`Retirer du plan 7/3`**
— une surcharge **masquée** : l'élément disparaît seulement de cette séquence ou de ce plan,
montré en fantôme, rétablissable) / **`Supprimer partout`** (ou **`Supprimer de la séquence`** —
destructeur, et redemande confirmation). Un élément utilisé nulle part ailleurs se supprime
simplement.

### Visibilité des calques

Chaque ligne de calque (**Décor**, **Mobilier**, **Accessoires fixes**, le fond, **Caméras**,
**Personnages**, **Lumières**, **Accessoires**) porte son propre compte en direct et une bascule
**Afficher**/**Masquer**, pour par exemple masquer toutes les caméras afin de vérifier la
décoration de la pièce sans qu'elles ne gênent.

### Ouvrir le plan d'un décor depuis Resources

La carte d'un décor dans la fiche d'un lieu, dans [Resources](resources.md), affiche **`Plan au
sol · N séquences`** (ou **`Pas de plan au sol`**) et une action **Ouvrir dans le découpage** qui
amène ici, directement sur le plan du décor à sa première séquence liée.

## Ce que ce mode exporte

- **Classeur du découpage (XLSX)** — une feuille, une ligne par plan portant tous ses champs
  (code, personnages, décor, valeur de plan, cadre, mouvement, optique, format, durée, prises,
  son, difficulté, jour, état, notes).
- **PDF de couverture du scénario** — votre scénario imprimé normalement, avec une **barre de
  couleur en marge** le long de chaque passage qu'un plan couvre ; les passages qu'aucun plan ne
  couvre sont estompés. Chaque plan a sa couleur (unique dans sa séquence). Une fenêtre d'options
  propose le format de page, la page de titre, les numéros de séquence, une page de légende et
  une page de résumé.
- **PDF du storyboard** — les images importées de chaque plan, annotées, avec ses informations
  clés. Une fenêtre d'options règle le nombre de plans par page, et peut ajouter les plans au sol
  de chaque séquence après elle.
- **PDF des plans au sol** — un plan au sol par plan portant une caméra placée, répété autant de
  fois que la séquence a de plans, chacun montrant la mise en place propre à ce plan (sans pelure
  d'oignon).

:::note

Le **jour de tournage** et les **prises prévues** apparaissent ici, mais c'est le mode Plan de
travail qui les possède : le découpage ne fait que les afficher.

:::
