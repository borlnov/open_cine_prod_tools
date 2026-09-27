# Dépannage

<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: CC-BY-4.0
-->

## Windows refuse de lancer l'application (SmartScreen)

Comme l'application n'est pas signée, SmartScreen affiche « Windows a protégé votre
ordinateur » au premier lancement. Cliquez sur **Informations complémentaires**, puis sur
**Exécuter quand même**. L'avertissement ne réapparaît plus ensuite.

## macOS refuse de lancer l'application (Gatekeeper)

Faites un clic droit sur l'application dans `Applications`, choisissez **Ouvrir**, puis à
nouveau **Ouvrir**. Voir la [page Installation](../getting-started/installation.md) pour
l'alternative en ligne de commande. Rappel : le build macOS n'a jamais été testé.

## « Ce fichier a été créé par une version plus récente »

Un projet enregistré par une version **plus récente** de l'application ne peut pas être ouvert
par une version plus ancienne : le fichier est **refusé, pas abîmé**, et laissé intact. Mettez
l'application à jour vers la dernière version, puis rouvrez le fichier.

## « Ce fichier doit être migré »

À l'inverse, un projet dans un **ancien format** demande une migration avant de s'ouvrir.
L'application vous le fait confirmer et indique où elle garde une **copie de sauvegarde**
(un fichier `.backup-v<n>.ocpt` posé à côté de l'original) avant de migrer. Sans sauvegarde, pas
de migration.

## Une photo ou un document n'apparaît pas

Photos et documents sont **référencés par leur chemin, pas incorporés** dans le projet. Si le
fichier a été déplacé ou supprimé, la fiche le signale : c'est une situation normale. Remettez le
fichier à son emplacement, ou référencez-le à nouveau depuis la fiche.

## La correction orthographique ne souligne rien

Deux réglages doivent être actifs : la **langue du scénario** (réglages du projet — pas
**Aucune**) et **Afficher la correction** (menu **⋮**). Voir [Correction orthographique et
dictionnaire](../concepts/spell-check-and-dictionary.md).

## Un envoi de projet signale des fichiers manquants

Avant d'écrire un paquet `.ocptz`, l'application vérifie les fichiers référencés et vous prévient
si certains manquent. Vous pouvez poursuivre malgré tout : le paquet portera alors les
références, sans les fichiers absents.
