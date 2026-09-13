# Partager un projet

<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: CC-BY-4.0
-->

Partager transforme un projet qui ne vit que sur votre appareil en un projet que le reste de
l'équipe peut rejoindre. Lisez d'abord
[Comment fonctionne la collaboration](how-collaboration-works.md) si ce n'est pas fait — cette
page explique ce que « partagé » veut dire avant d'ouvrir les écrans eux-mêmes.

## Ouvrir l'écran de partage

L'écran de partage n'est accessible que depuis l'**écran d'accueil** : ouvrez le menu **⋮** de la
fiche d'un projet et choisissez **Partager** (le même menu propose aussi Exporter… et Retirer de
la liste). Il n'est pas accessible depuis l'intérieur d'un projet déjà ouvert — le partage se met
en place avant, ou entre, les sessions de travail, depuis la fiche elle-même.

![Le menu ⋮ de la fiche projet ouvert sur Partager](/img/screenshots/collab-share-menu.png)

Partager a besoin d'un lieu de rendez-vous pour chaque appareil : un **relais** — soit un déjà en
service quelque part (un serveur auto-hébergé, ou celui qu'un collègue a mis en place), soit votre
propre machine en faisant office, ce qui est couvert plus bas.

## Se coupler à un relais

Si vous connaissez déjà l'adresse d'un relais — celui de votre production, ou celui que vous
hébergez vous-même — choisissez l'option du relais distant et saisissez :

- l'**adresse** du relais ;
- le **secret d'inscription** que l'opérateur de ce relais vous a donné.

![L'étape de configuration de l'écran de partage, relais distant](/img/screenshots/collab-share.png)

Valider cela **couple** le projet à ce relais : cela génère un jeton privé pour ce projet, envoie
le contenu actuel de votre projet au relais pour que la prochaine personne qui le rejoint puisse
le télécharger, et démarre la synchronisation. À partir de là, le projet est partagé.

## L'invitation

Une fois couplé, l'écran affiche l'**invitation** du projet : un code QR et son équivalent sous
forme de lien copiable. Quiconque scanne le QR ou ouvre le lien peut rejoindre le projet — voir
[Rejoindre un projet](joining-a-project.md) pour ce que cela donne de leur côté.

Partagez le QR en pointant la caméra d'un collègue vers votre écran, ou envoyez le lien copié
comme vous enverriez n'importe quel autre lien (messagerie, courriel). L'invitation ne porte aucun
mot de passe à dicter à voix haute : quiconque détient le QR ou le lien peut rejoindre le projet,
traitez-le donc comme vous traiteriez le lien d'un document partagé.

Une action **arrêter le partage** se trouve aussi ici, pour le moment où un projet ne doit plus
accepter de nouveaux appareils ni continuer à se synchroniser ; comme cela ne peut pas être annulé
depuis l'écran, elle est confirmée avant de prendre effet.

## Héberger le relais vous-même

Si aucun relais n'est disponible, ou si le tournage n'a aucun accès à internet, le même écran
propose un panneau **« Héberger sur ce poste »** : un interrupteur qui transforme votre propre
appareil en relais que tous les autres viennent coupler, sans rien d'autre à installer ni à
lancer. C'est le bon choix pour un ordinateur portable déjà ouvert sur le projet — la machine de
video-village d'un tournage, ou l'ordinateur d'un producteur faisant office de point de rendez-vous
durable du projet entre deux tournages.

![Le panneau « Héberger sur ce poste »](/img/screenshots/collab-host.png)

Ce panneau montre aussi qui est actuellement connecté à votre relais hébergé, ainsi qu'une option
**« réhéberger au démarrage »** pour que l'hébergement reprenne de lui-même la prochaine fois que
vous ouvrez le projet. Héberger un relais l'ouvre volontairement au reste de votre réseau local —
voir la remarque sur le pare-feu dans [Le relais de plateau](on-set-server.md) pour ce que cela
signifie en pratique.

Quiconque fait réellement tourner la machine comme relais pour une journée entière de tournage —
plutôt que de simplement activer l'interrupteur pour un couplage rapide — est le public du guide
opérateur plus technique, `docs/on-set-server.md` dans le dépôt de l'application ; orientez-le
vers ce guide plutôt que d'improviser.

## L'hébergement est réservé à l'ordinateur

Transformer un appareil *en* relais est une fonctionnalité d'ordinateur : une tablette ou un
téléphone peuvent se coupler à un relais et rejoindre un projet partagé comme n'importe quel
autre appareil, mais ils ne peuvent pas en héberger un eux-mêmes.
