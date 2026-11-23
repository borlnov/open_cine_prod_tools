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

Il y a deux chemins. Depuis l'**écran d'accueil**, ouvrez le menu **⋮** de la fiche d'un projet
et choisissez **Partager / Synchroniser…** (le même menu propose aussi Exporter… et Retirer de la
liste). Et une fois un projet partagé, le même écran est aussi à un clic depuis l'intérieur du
projet ouvert, par le panneau de l'indicateur d'état de synchronisation — **Afficher le QR
d'invitation** ou **Ré-appairer…**, voir
[Comment fonctionne la collaboration](how-collaboration-works.md#lindicateur-détat-de-synchronisation).
Un projet pas encore partagé n'a pas d'indicateur : le menu de sa fiche est donc l'endroit où le
partage commence.

![Le menu ⋮ de la fiche projet ouvert sur Partager / Synchroniser…](/img/screenshots/collab-share-menu.png)

L'écran qui s'ouvre s'intitule `Partager « <nom du projet> »`, avec une étape « ① Configurer » et
un badge « Non appairé » en haut à droite. Sur ordinateur, un sélecteur à deux segments le
divise en deux façons de partager : **Relais distant** (par défaut, couvert juste après) et
**Héberger sur ce poste** (couvert plus bas). Dans les deux cas, partager a besoin d'un lieu de
rendez-vous pour chaque appareil : un **relais** — soit un déjà en service quelque part (un
serveur auto-hébergé, ou celui qu'un collègue a mis en place), soit votre propre machine en
faisant office.

## S'appairer à un relais

Si vous connaissez déjà l'adresse d'un relais — celui de votre production, ou celui que vous
hébergez vous-même — gardez l'option **Relais distant** et saisissez :

- l'**Adresse du relais** (une adresse comme `https://relais.exemple.org`) ;
- le **Secret d'enrôlement** que l'opérateur de ce relais vous a donné, qui reste masqué tant que
  vous ne cliquez pas sur l'œil au bout du champ.

![L'étape de configuration de l'écran de partage, relais distant](/img/screenshots/collab-share.png)

Une note sous ces champs explique qu'un jeton de projet est généré automatiquement et conservé
dans le stockage sécurisé — il n'est jamais écrit dans le fichier du projet. Valider avec
**Appairer et créer sur le relais** **appaire** le projet à ce relais : cela envoie le contenu
actuel de votre projet pour que la prochaine personne qui le rejoint puisse le télécharger, et
démarre la synchronisation. Si l'adresse ou le secret est faux, un message en bas de l'écran
indique que l'appairage a échoué et vous invite à les vérifier. À partir de là, le projet est
partagé.

## L'invitation

Une fois appairé, l'écran passe à sa seconde étape — les badges affichent désormais
« ② Inviter » et « En sync » — et montre une carte **Invitez votre équipe** : le code QR du
projet, avec **Enregistrer le QR…** et **Copier le lien d'invitation** en dessous. Quiconque
scanne le QR ou ouvre le lien peut rejoindre le projet — voir
[Rejoindre un projet](joining-a-project.md) pour ce que cela donne de leur côté.

Partagez le QR en pointant la caméra d'un collègue vers votre écran, ou envoyez le lien copié
comme vous enverriez n'importe quel autre lien (messagerie, courriel). L'invitation ne porte aucun
mot de passe à dicter à voix haute : quiconque détient le QR ou le lien peut rejoindre le projet,
traitez-le donc comme vous traiteriez le lien d'un document partagé.

Une carte **Connexion**, en dessous, montre l'adresse du relais et le jeton du projet, masqué
tant que vous ne choisissez pas l'icône d'affichage à côté.

Un bouton **Cesser de partager…** se trouve en bas, pour le moment où un projet ne doit plus
accepter de nouveaux appareils ni continuer à se synchroniser. Comme cela ne peut pas être annulé
depuis l'écran, il vous interroge d'abord — « Cesser de partager ce projet ? » — et précise que
chaque appareil qui détient déjà une copie la conserve, mais cesse d'envoyer et de recevoir des
modifications.

## Héberger le relais vous-même

Si aucun relais n'est disponible, ou si le tournage n'a aucun accès à internet, basculer le
sélecteur sur **Héberger sur ce poste** propose un interrupteur **Hébergement** (il indique
« Arrêté » tant qu'il est coupé, puis « Démarrage… » et « En ligne », ou « L'hébergement n'a pas
pu démarrer » si quelque chose a échoué) qui transforme votre propre appareil en relais auquel
tous les autres se connectent, sans rien d'autre à installer ni à lancer. C'est le bon choix pour
un ordinateur portable déjà ouvert sur le projet — la machine de video-village d'un tournage, ou
l'ordinateur d'un producteur faisant office de point de rendez-vous durable du projet entre deux
tournages.

![Le panneau « Héberger sur ce poste »](/img/screenshots/collab-host.png)

Tant que l'interrupteur est activé, le panneau montre aussi :

- l'**Adresse annoncée** que les autres devront joindre (une liste déroulante, pour une machine
  présente sur plusieurs réseaux) et le **Port**, que vous pouvez modifier puis **Appliquer** ;
- un code QR et un bouton de copie du lien, avec deux choix : **Envoyer le projet à un appareil**
  (pour un appareil qui n'a pas encore le projet — il le scanne depuis **Rejoindre un projet
  partagé…**) et **Rediriger un appareil qui l'a déjà** (pour un appareil qui a déjà le projet —
  il le scanne depuis **Changer de relais…**) ;
- une liste **Connectés** des appareils actuellement sur votre relais, ou « Personne n'a encore
  rejoint » ;
- **Réconcilier amont…**, qui renvoie le travail de la journée vers le relais habituel de la
  production (voir [Le relais de plateau](on-set-server.md)).

Une case **Réhéberger ce projet au démarrage** fait reprendre l'hébergement de lui-même la
prochaine fois que vous ouvrez le projet ; elle reste grisée tant que le projet n'a pas été
partagé ou hébergé une fois. Héberger un relais l'ouvre volontairement au reste de votre réseau
local — voir la remarque sur le pare-feu dans
[Le relais de plateau](on-set-server.md#la-remarque-sur-le-pare-feu-en-clair) pour ce que cela
signifie en pratique.

Quiconque fait réellement tourner la machine comme relais pour une journée entière de tournage —
plutôt que de simplement activer l'interrupteur pour un essai rapide — est le public du guide
opérateur plus technique, `docs/on-set-server.md` dans le dépôt de l'application ; orientez-le
vers ce guide plutôt que d'improviser.

## L'hébergement est réservé à l'ordinateur

Transformer un appareil *en* relais est une fonctionnalité d'ordinateur : sur une tablette ou un
téléphone, l'écran de partage n'a pas de sélecteur « Héberger sur ce poste », seulement le
formulaire du relais distant. Un tel appareil peut tout de même s'appairer à un relais et
rejoindre un projet partagé comme n'importe quel autre appareil, mais il ne peut pas en héberger
un lui-même. Un projet ouvert en aperçu en lecture seule ne peut pas non plus héberger ni
ré-appairer.
