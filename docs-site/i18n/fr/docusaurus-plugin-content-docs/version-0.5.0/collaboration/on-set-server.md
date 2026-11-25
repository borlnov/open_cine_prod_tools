# Le relais de plateau

<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: CC-BY-4.0
-->

Un tournage n'a souvent aucun accès fiable à internet, mais profite quand même de voir tous les
appareils se synchroniser entre eux sur le réseau local du plateau. Cette page couvre le fait de
pointer votre appareil vers ce relais local pour la journée, et ce qu'implique d'en faire tourner
un pour la personne qui apporte l'ordinateur.

## Pourquoi un plateau a son propre relais

Plutôt que de dépendre d'une connexion internet qu'un lieu peut simplement ne pas avoir, une
production peut faire tourner son propre relais pour la journée sur un ordinateur déjà présent en
plateau — via le même panneau « Héberger sur ce poste » décrit dans [Partager un
projet](sharing-a-project.md) (une fonctionnalité d'ordinateur). Chaque appareil en plateau se
synchronise alors avec cette machine sur le réseau local uniquement, sans aucun accès à internet. En
fin de journée, la personne qui fait tourner cet ordinateur renvoie le travail de la journée vers le
relais habituel de la production avec l'action **Réconcilier amont…** du panneau : collez le lien
d'invitation du relais habituel, choisissez **Réconcilier**, et le panneau indique combien de
modifications ont été envoyées et reçues. Le guide de l'opérateur, indiqué plus bas, couvre la
journée entière.

![Le panneau « Héberger sur ce poste »](/img/screenshots/collab-host.png)

## Pointer votre appareil vers le relais de plateau

Votre projet n'a pas besoin d'être rejoint à nouveau pour fonctionner avec le relais de plateau —
il garde sa propre identité et son historique. Ce qui change, c'est seulement *où* il cherche son
relais :

1. Sur l'indicateur d'état de synchronisation dans la barre d'état de votre espace de travail
   (voir
   [Comment fonctionne la collaboration](how-collaboration-works.md#lindicateur-détat-de-synchronisation)),
   ouvrez le panneau et choisissez **Changer de relais…**. L'écran s'intitule
   `Changer de relais pour « <nom du projet> »`.
2. Saisissez l'**Adresse du relais** de plateau et son **Secret d'enrôlement**, puis choisissez
   **Changer de relais**. Sur une tablette ou un téléphone, vous pouvez à la place choisir
   **Scanner un QR de relais** et pointer la caméra vers le code QR affiché par le relais de
   plateau — sur l'écran de l'ordinateur qui l'héberge (choisissez **Rediriger un appareil qui
   l'a déjà** dans son panneau d'hébergement), ou remis par la personne qui le fait tourner
   depuis un terminal ; **Saisir manuellement** ramène le formulaire. Un ordinateur n'a pas de
   scan : il utilise toujours le formulaire.
3. Votre appareil se synchronise désormais avec le relais de plateau. Rien ne change dans le
   contenu de votre projet ; seul le point de rendez-vous change. L'écran propose ensuite un QR
   **Prêt pour l'appareil suivant**, avec **Copier le lien d'enrôlement**, pour transmettre le
   même changement à la personne suivante ; choisissez **Terminé** quand vous avez fini.

Le même QR permet de repointer n'importe quel projet — il désigne un relais, pas un projet précis
— si bien qu'un seul code affiché une fois suffit pour que toute l'équipe pointe ses propres
appareils vers lui, chacun gardant son propre projet.

## La remarque sur le pare-feu, en clair

Héberger un relais — depuis l'application ou depuis les outils d'un opérateur technique — l'ouvre
volontairement au reste du réseau local sur lequel il tourne : c'est ainsi que le reste des
appareils de l'équipe le rejoignent. Pour un réseau de plateau ou la machine d'une petite
production, c'est un choix accepté et délibéré, pas un oubli. Cela signifie aussi qu'un relais de
plateau n'est censé être joint que depuis *ce* réseau local — le joindre depuis ailleurs par
internet sort du cadre prévu, et une production qui en a réellement besoin devrait utiliser un
relais permanent et correctement sécurisé plutôt qu'un relais de plateau.

## Si l'ordinateur qui le fait tourner est perdu

Le relais de plateau est une commodité, jamais l'unique endroit où vit le travail de la journée :
chaque appareil en plateau détient déjà sa propre copie complète du projet, modifications
comprises. Si l'ordinateur faisant tourner le relais est perdu, tombe en panne ou reste simplement
sur place, n'importe quel autre ordinateur qui était en plateau peut tout simplement se mettre à
héberger à sa place et continuer — rien dans la journée ne dépend d'une seule machine qui survivrait
jusqu'au soir.

## Pour la personne qui fait tourner le relais

Transformer un ordinateur en relais de plateau pour toute une journée — le démarrer, partager son
QR, renvoyer le travail de la journée vers le relais de la production le soir — est couvert pas à
pas dans le guide opérateur du projet, `docs/on-set-server.md` dans le dépôt de l'application. Il
ne suppose aucune connaissance en programmation, seulement l'aisance de faire tourner le relais
pour la journée ; confiez-le à la personne à qui l'on demande d'apporter l'ordinateur.
