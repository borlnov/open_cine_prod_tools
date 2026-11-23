# Comment fonctionne la collaboration

<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: CC-BY-4.0
-->

Un projet peut être **partagé** : le réalisateur sur un ordinateur portable, l'assistant
réalisateur sur une tablette en plateau, un producteur chez lui, tous travaillant sur le même
projet, chacun sur son propre appareil. Cette page explique ce que cela signifie avant d'ouvrir
les écrans de partage eux-mêmes.

## Chaque appareil garde le projet en entier

Il n'existe pas de serveur détenant « le vrai » projet dont votre appareil ne ferait qu'emprunter
un aperçu. Chaque appareil qui rejoint un projet partagé en garde une **copie complète** — le
scénario, le dépouillement, les ressources, le plan de travail, le budget, tout — et reste
entièrement utilisable avec cette seule copie, sans aucune connexion.

C'est ce qui permet à l'application de fonctionner sur un plateau sans réseau : vous continuez à
écrire, à taguer des plans, à déplacer des personnes sur le plan de travail, et chaque changement
est enregistré localement exactement comme dans un projet que vous n'auriez jamais partagé.

## Les modifications s'empilent et se fondent à la reconnexion

Tant que vous êtes hors ligne, vos modifications s'empilent simplement sur votre appareil. Dès
qu'une connexion au relais du projet partagé revient — wifi, partage de connexion, réseau de
plateau — votre appareil envoie ses modifications en attente et reçoit celles que les autres ont
faites entre-temps. Les deux côtés se retrouvent avec le même projet.

Deux personnes peuvent modifier sans risque **des champs différents d'une même fiche** en même
temps — le réalisateur ajustant le cadre d'un plan pendant que l'assistant réalisateur fixe son
jour de tournage, par exemple — et les deux changements survivent ; ni l'un ni l'autre n'écrase
l'autre. Deux modifications sur le tout **même** champ sont résolues automatiquement, sans vous
demander de trancher, si bien que le partage ne bloque jamais votre travail en attendant une
décision.

La seule exception est le texte du scénario lui-même : deux personnes tapant dans le même passage
au même moment voient leurs modifications fusionnées ligne à ligne, comme le ferait un outil de
gestion de versions. Dans le cas rare où les deux modifications se heurtent réellement sur les mêmes
lignes, l'application ne devine pas : elle laisse votre texte tel que vous l'avez écrit au lieu de
l'écraser en silence, et aucun écran ne permet encore de régler le heurt — mieux vaut donc
convenir entre vous de qui modifie tel passage.

## L'indicateur d'état de synchronisation

Une fois un projet partagé, un petit indicateur se place dans la barre d'état de l'espace de
travail, visible depuis chaque mode. Il indique en un coup d'œil où en est votre appareil par
rapport au reste du projet :

- **En sync** — tout ce que vous et les autres avez fait est réconcilié ; rien n'est en
  attente.
- **Synchronisation…** — des modifications sont en train d'être envoyées ou reçues.
- **Hors ligne · 3 modifications en attente** — le nombre indique combien de vos propres
  modifications attendent encore d'être envoyées. C'est normal et attendu dès que l'appareil n'a
  pas de connexion au relais ; rien n'est perdu, cela n'est simplement pas encore parti. Quand le
  nombre n'est pas connu, l'indicateur affiche « Hors ligne · modifications en attente ».
- **Erreur de synchronisation** — quelque chose que le relais lui-même a refusé, qui mérite un
  coup d'œil plutôt qu'une simple coupure de connexion ; le panneau ci-dessous le détaille sous la
  forme « Erreur du relais : … ».

Cliquez sur l'indicateur pour ouvrir un panneau de quatre actions : **Synchroniser maintenant** ;
**Afficher le QR d'invitation** et **Ré-appairer…**, qui ouvrent toutes deux l'[écran de
partage](sharing-a-project.md) du projet ; et **Changer de relais…**, qui pointe le projet vers un
autre relais (voir [Le relais de plateau](on-set-server.md)). L'indicateur, et son panneau,
n'apparaissent qu'une fois le projet partagé — un projet non partagé n'affiche ni l'un ni l'autre.
Sur un projet ouvert en aperçu en lecture seule, le panneau est là, mais ses actions sont
retirées.

## La présence : qui d'autre l'a ouvert

Une grappe de petits avatars ronds dans la barre d'outils supérieure, juste avant **Exporter**,
montre chaque appareil ayant actuellement le projet ouvert, le vôtre compris — jamais les
personnes qui en possèdent simplement une copie quelque part, seulement celles qui l'ont ouvert à
l'instant. Chaque avatar porte l'initiale du système de l'appareil (par exemple L pour Linux, W
pour Windows) ; au-delà de trois, les autres se replient dans une pastille « +2 ». Survolez un
avatar pour voir son nom et son mode, ou cliquez sur la grappe pour ouvrir la liste « Sur ce
projet », avec le nombre de connectés et, pour chaque appareil, son nom — le système et les trois
derniers caractères de son identifiant, comme « Linux · a3f » — et **le mode** dans lequel il
travaille (Scénario, Planning, Budget…), ce qui suffit souvent à lui seul à savoir s'il est
prudent, par exemple, de réordonner le planning.

Il n'y a ni comptes ni noms à saisir : chaque appareil se distingue par sa propre couleur,
constante pour cet appareil, et par ce court identifiant. Le vôtre est toujours listé en premier,
cerclé de la couleur d'accent et marqué « Vous ». La présence est entièrement en direct — elle ne
dit rien de qui *a* modifié quelque chose, seulement de qui est *actuellement* sur le projet — et
disparaît avec l'indicateur de synchronisation sur un projet non partagé.

## Pour la suite

- [Partager un projet](sharing-a-project.md) pour inviter le reste de l'équipe.
- [Rejoindre un projet](joining-a-project.md) pour l'appareil qui reçoit l'invitation.
- [Le relais de plateau](on-set-server.md) pour un tournage avec son propre relais local.
- [Travailler sur tablette ou téléphone](tablet-and-phone.md) pour les dispositions sur petit
  écran.
