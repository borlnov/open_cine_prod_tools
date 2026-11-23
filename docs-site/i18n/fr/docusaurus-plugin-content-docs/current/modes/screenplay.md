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
  clic droit offre Couper, Copier, Coller, Tout sélectionner et un sous-menu de type de bloc.
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
