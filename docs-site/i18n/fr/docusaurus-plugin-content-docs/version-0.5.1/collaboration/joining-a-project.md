# Rejoindre un projet

<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: CC-BY-4.0
-->

Rejoindre est la façon dont un projet partagé arrive sur un appareil qui ne l'a pas encore — une
nouvelle tablette en plateau, l'ordinateur portable d'un producteur, quiconque a reçu l'invitation
depuis [Partager un projet](sharing-a-project.md).

## Ouvrir l'écran pour rejoindre

Depuis la barre d'outils de l'écran d'accueil, choisissez **Rejoindre un projet partagé…** (sur
un téléphone, elle se trouve dans le menu **⋮** de la barre d'outils). Contrairement à
l'ouverture d'un projet, rejoindre n'a pas besoin d'en avoir déjà un sur votre appareil — c'est
tout l'intérêt — l'action est donc accessible à tout moment depuis l'écran d'accueil, pas depuis
l'intérieur d'un projet qu'il vous faudrait déjà avoir.

L'écran qui s'ouvre s'intitule « Rejoindre un projet partagé », avec un badge « Aucune copie
locale » et deux onglets : **Scanner (tablette)** et **Saisir manuellement**.

![L'écran pour rejoindre un projet partagé](/img/screenshots/collab-join.png)

## Scanner ou coller l'invitation

Il vous faut l'invitation que quelqu'un vous a partagée, sous quelque forme qu'elle vous soit
parvenue :

- **Sur une tablette ou un téléphone**, l'écran s'ouvre sur l'onglet **Scanner (tablette)**, qui
  propose un scan à la caméra : pointez la caméra vers le code QR affiché sur l'écran de partage
  de l'appareil qui vous invite.
- **Sur ordinateur**, l'écran s'ouvre sur **Saisir manuellement** : collez le **Lien
  d'invitation** que vous avez reçu dans ce champ, puis choisissez **Rejoindre**. Un ordinateur
  n'a pas de scan ici — son onglet de scan indique seulement « Caméra indisponible ».

Les deux méthodes aboutissent à la même invitation ; il n'y a rien d'autre à configurer. Un
bandeau à l'écran rappelle ce que fait rejoindre : cela crée une copie locale complète du projet
en téléchargeant l'instantané du relais, puis continue de se synchroniser, et une nouvelle carte
apparaît à l'accueil une fois terminé. Si le code ou le lien n'est pas une invitation valide, un
message en bas de l'écran indique qu'il est impossible de rejoindre le projet et vous invite à
vérifier le lien d'invitation.

## Ce que rejoindre fait réellement

Valider l'invitation :

1. Demande où le projet atterrit : sur ordinateur, un sélecteur de dossier vous laisse choisir —
   il propose le dossier où vous avez enregistré un projet en dernier, et son bouton de
   validation indique **Rejoindre ici** — et le projet crée son propre dossier à l'intérieur de
   celui que vous choisissez ; sur tablette ou téléphone, où il n'y a pas de telle fenêtre, il
   est placé automatiquement aux côtés de vos autres projets. Annuler le sélecteur annule
   l'opération.
2. Affiche un panneau de progression — « Connexion au relais… », « Récupération du projet… »,
   « Ouverture… » — pendant qu'il télécharge le contenu actuel du projet depuis le relais indiqué
   dans l'invitation, dans un nouveau fichier de projet à cet endroit, et enregistre le couplage
   du projet, de sorte que votre appareil se synchronise désormais avec le même relais que tous
   ceux qui l'ont rejoint. Un bouton **Annuler** l'interrompt.
3. Se termine sur « Projet récupéré », avec un bouton **Ouvrir** qui vous emmène dans le projet.

À partir de là, votre appareil se comporte comme n'importe quel autre détenant le projet : il en a
une copie complète, fonctionne hors ligne, et synchronise ses modifications dès qu'il peut à
nouveau joindre le relais — voir
[Comment fonctionne la collaboration](how-collaboration-works.md) pour ce que cela signifie au
quotidien.

## Si vous ne pouvez pas joindre le relais

Rejoindre a besoin d'une connexion fonctionnelle au relais au moment où vous rejoignez, puisqu'il
faut télécharger le projet. Si le relais est inaccessible — pas de réseau en plateau, une adresse
qui a changé — l'opération s'arrête sur le même message « Impossible de rejoindre ce projet ».
Attendez d'avoir une connexion, ou demandez à la personne qui héberge de vous fournir une
invitation à jour si le relais lui-même a changé de place (voir
[Le relais de plateau](on-set-server.md)).
