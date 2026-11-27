# Scénario

<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: CC-BY-4.0
-->

Le mode Scénario est là où vous écrivez le scénario de l'épisode sélectionné. L'application
travaille en **Fountain** (un format de scénario en texte simple), mais vous n'avez jamais à
penser en « code » : vous écrivez sur une page mise en forme, ou vous éditez le texte Fountain
brut avec un aperçu à côté.

![Le mode Scénario et sa page mise en forme](/img/screenshots/screenplay.png)

## Les deux modes d'édition

- **Éditeur stylé** — une surface qui montre le scénario tel qu'il s'imprimera. Chaque
  paragraphe est un bloc typé (en-tête de séquence, action, personnage, dialogue…), mis en
  forme automatiquement. Avec la simulation de page, votre texte se pose sur de vraies feuilles
  au format, numéros de page compris.
- **Texte Fountain brut** — un champ de texte où vous tapez directement la source Fountain,
  avec un **aperçu papier côte à côte** qui montre le résultat mis en forme au fur et à mesure.

Pour basculer d'un mode à l'autre : **Ctrl+Maj+M** (ou le menu **⋮**). L'historique d'annulation
appartient à la surface où vous êtes : basculer repart d'un historique neuf, terminez donc une
modification avant de changer.

## Zoomer la page

Vous pouvez zoomer la page, dans l'éditeur stylé et dans l'aperçu papier du mode brut (le texte
Fountain brut garde sa taille). Le zoom est le même dans les deux, et il est mémorisé pour vous,
quel que soit le projet.

- Utilisez le **`−`**, le pourcentage et le **`+`** à droite de la barre d'état. Cliquez sur le
  pourcentage pour la liste des tailles, de 50 % à 200 %, et **Ajuster à la largeur** : la page
  remplit alors la largeur de la zone et suit la fenêtre quand vous la redimensionnez.
- Maintenez **Ctrl** (**Cmd** sur Mac) et tournez la molette : un palier par cran, autour du point
  sous le curseur, quelle que soit la course d'un cran sur votre système. Une molette lisse ou un
  pavé tactile, qui envoient beaucoup de petits mouvements, changent de palier chaque fois qu'ils
  s'additionnent jusqu'à un cran. La molette seule fait toujours défiler.
- **Ctrl** et **+** (ou **=**) zooment, **Ctrl** et **−** dézooment, **Ctrl** et **0** reviennent
  à 100 %.

La pagination ne change pas avec le zoom : les mêmes lignes tombent sur les mêmes pages. Quand la
page est plus large que la zone, faites défiler latéralement. Sur un téléphone ou une fenêtre
étroite, il n'y a pas de zoom.

## Les éléments que l'éditeur comprend

L'éditeur reconnaît et met en forme les éléments standard d'un scénario : **en-têtes de
séquence** (`INT.`/`EXT.`, avec un numéro écrit `#N#` si besoin), **action**, **personnage**
(avec des extensions comme `(V.O.)`), **dialogue** et **parenthèses**, **transitions**, **texte
centré**, **notes** (hors impression), ainsi que **sections**, **synopsis** et **paroles de
chanson**.

Quelques gestes utiles dans l'éditeur stylé :

- **Tab / Maj+Tab** fait défiler le type d'un bloc parmi les six types courants et le verrouille.
- **Entrée** enchaîne sur le type qui suit normalement ; **Maj+Entrée** garde le même type.
- Un menu de type de bloc et les bascules **G / I / S** vivent dans la barre d'outils ; un
  clic droit offre Couper, Copier, Coller, Tout sélectionner, Insérer une note et Supprimer la
  note, et un sous-menu de type de bloc.
- Le copier-coller interne conserve les types de blocs ; un texte venu de l'extérieur est
  analysé et réparti dans les bons éléments.

## Le double dialogue

Deux personnages qui parlent en même temps s'écrivent en **double dialogue** : le nom du second
personnage se termine par `^` (par exemple `KIM ^`), et les deux répliques s'impriment **côte à
côte**, une colonne chacune, sur la page de l'aperçu, du PDF et des feuilles des autres modes. Une
paire n'est jamais coupée par un saut de page : si elle ne tient pas, elle passe entière à la page
suivante. Un `^` sans réplique juste avant pour s'y apparier s'imprime comme un dialogue ordinaire,
et une note ou toute autre ligne entre les deux répliques casse la paire.

Dans l'éditeur stylé, vous ne tapez pas le `^` : placez le curseur dans la seconde réplique et
choisissez **Double dialogue** dans le menu du clic droit, dans les contrôles de mise en forme de
la barre d'outils (ou leur menu **⋮**), ou appuyez sur **Ctrl+Alt+D** (**Cmd+Alt+D** sous macOS).
L'entrée est cochée tant que la réplique fait partie d'une paire, et la choisir de nouveau défait
l'appariement. Elle n'apparaît que si une autre réplique jouxte celle où vous êtes. L'éditeur stylé
garde les deux répliques **l'une sous l'autre**, et une **accolade dans la marge gauche** montre
qu'elles forment une paire ; un `^` qui ne s'apparie à rien s'affiche estompé après le nom du
personnage. Taper un `^` à la fin d'un nom fonctionne aussi, et le texte Fountain brut le montre
tel qu'il est écrit.

## Les notes

Une note est un texte pour vous et votre équipe, qui ne s'imprime jamais : un rappel, une question
pour l'équipe son, un accessoire à vérifier. Fountain l'écrit entre doubles crochets,
`[[comme ceci]]`, et le texte Fountain brut la montre ainsi.

Dans l'éditeur stylé, une note est une petite **bulle** dans la ligne, et son texte se trouve dans
une **carte dans la marge**, à droite de la page, à hauteur de sa ligne :

- **Cliquez une bulle**, ou une carte, pour sélectionner la note : sa carte se rapproche de la
  page, reliée à la bulle par un trait, et vous pouvez y écrire aussitôt.
- **Entrée** ou **Échap** vous ramène au scénario, le curseur juste après la bulle.
  **Maj+Entrée** passe à la ligne dans la note.
- **Ctrl+Z** annule en une fois toute la modification d'une note, même depuis sa carte.
- Pour ajouter une note, faites un clic droit à l'endroit voulu et choisissez **Insérer une
  note** : une carte vide s'ouvre, prête à recevoir votre texte. Si vous la laissez vide, la note
  disparaît.
- Pour en supprimer une, utilisez le bouton **Supprimer la note** de sa carte, ou **Supprimer la
  note** dans le menu du clic droit.

Quand la fenêtre est trop étroite pour la marge, les cartes sont masquées et un clic sur une bulle
ouvre la note dans une **bulle flottante** sous elle, où l'on écrit de la même façon. Un clic à
côté la referme. La marge revient dès qu'il y a de nouveau la place.

Rechercher et remplacer (**Ctrl+F**, **Ctrl+H**) cherche aussi dans les notes : la bulle d'une
note qui contient un résultat est teintée, et quand le résultat courant est dans une note, sa carte
ou sa bulle flottante s'ouvre avec le résultat surligné. Une note ne peut contenir ni `]]`, ni
`/*`, ni `*/` : un remplacement qui y en mettrait un laisse cette note telle quelle.

Une note peut s'étendre sur plusieurs lignes. Au sein d'un paragraphe d'action ou de dialogue, elle
ne peut pas contenir de ligne vide, qui couperait ce paragraphe en deux ; une note seule sur ses
lignes le peut.

## Le panneau des séquences (à gauche)

Un panneau redimensionnable liste vos séquences pour naviguer et sauter de l'une à l'autre.

À propos des **numéros de séquence** : un `#N#` explicite est toujours respecté. En mode stylé,
l'éditeur peut en plus **afficher un numéro calculé** pour un en-tête qui n'en a pas (bascule
*Afficher les numéros de séquence* dans le menu **⋮**, active par défaut). Les numéros calculés
ne sont qu'un affichage : ils ne sont jamais écrits dans votre fichier, et un `#N#` explicite
l'emporte toujours. L'aperçu et le PDF n'impriment que les numéros explicites.

## La page de titre

En mode stylé, la page de titre est une **première feuille éditable**. Elle montre ses six
champs — **Titre, Crédit, Auteur, Date de version, Contact, Source** — avec des indices pour
les champs vides, disposés comme une vraie page de titre. Vous éditez sur place, ou via le
bouton **Modifier…** du panneau de métadonnées. Si tous les champs sont vides, aucune page de
titre n'est écrite ; quand elle est présente, elle occupe toute la page 1 et n'entre pas dans
la numérotation.

## Importer un scénario d'un autre format

L'application ouvre un scénario reçu d'une production — un **Final Draft `.fdx`** ou un
**Celtx `.celtx`** — et le convertit en Fountain, qui devient votre source. En-têtes, action,
personnages, parenthèses, dialogues, transitions, dialogues en vis-à-vis, ruptures d'acte,
emphase et page de titre sont repris.

:::caution La conversion est à sens unique et non exhaustive

Un `.fdx` laisse derrière lui ses notes en marge, ses marques de révision et ses pages
verrouillées. Un `.celtx` n'apporte que son **premier** document scénario. Importer **remplace**
le scénario courant : l'application vous le fait **confirmer** avant d'écraser votre texte.

:::

## Statistiques et outils

- La **barre d'état** affiche des compteurs vivants sur le scénario imprimable : nombre de
  pages, de séquences, de personnages parlants, de mots et de signes.
- Le panneau de droite, à onglets, contient un aperçu, un inspecteur de séquence (en-tête,
  personnages parlants, durée estimée), la page de titre, les versions, et un **guide de la
  syntaxe Fountain** consultable dans les deux modes.
- La **correction orthographique** fonctionne au fil de la frappe : voir [Correction
  orthographique et dictionnaire](../concepts/spell-check-and-dictionary.md).

## Ce que ce mode exporte

- un **PDF du scénario** (paginé, avec la page de titre et vos numéros de séquence explicites) ;
- un fichier **`.fountain`** (texte).

Les deux proposent un nom de fichier incluant l'épisode, pour ne pas écraser un scénario d'un
autre épisode enregistré dans le même dossier.
