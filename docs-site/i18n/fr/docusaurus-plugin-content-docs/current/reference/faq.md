<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: CC-BY-4.0
-->

# Foire aux questions

## Mes données partent-elles sur un serveur ?

Non. Tout est **local** : un projet tient dans un seul fichier `.ocpt` sur votre disque. Rien
n'est envoyé en ligne. Le travail collaboratif et la synchronisation sont prévus pour plus tard,
mais ne font pas partie de la version actuelle.

## L'application fonctionne-t-elle hors ligne ?

Oui, entièrement — y compris la correction orthographique, dont les dictionnaires sont fournis
avec l'application.

## Comment sauvegarder un projet ?

Copiez son fichier `.ocpt`, tout simplement. Pour envoyer un projet complet à quelqu'un,
exportez-le en paquet **`.ocptz`** (voir [Exporter votre travail](../exports/exporting-your-work.md)).
Pensez aussi aux [versions de projet](../concepts/project-versions.md) pour poser des jalons à
l'intérieur d'un projet.

## Puis-je gérer une série ?

Oui. Un projet contient un ou plusieurs **épisodes** dans un même fichier — un scénario par
épisode, mais une seule équipe et un seul plan de travail. Voir [Projets et
épisodes](../concepts/projects-and-episodes.md).

## Quels formats puis-je importer et exporter ?

- **Importer** un scénario : `.fountain`, `.fdx` (Final Draft) et `.celtx` (Celtx). Les deux
  derniers sont convertis en Fountain à l'import, sans retour possible.
- **Exporter** : PDF, XLSX et `.fountain`, selon le mode. La liste complète est dans [Exporter
  votre travail](../exports/exporting-your-work.md).

## Sur quels systèmes tourne-t-elle ?

Linux et Windows sont en développement actif. Un build macOS existe mais **n'a jamais été testé**.
Android et iOS ne sont pour l'instant que des ébauches. Voir
[Installation](../getting-started/installation.md).

## En quelles langues existe l'application ?

L'interface est en **anglais** et en **français**. Ce guide l'est aussi ; le sélecteur de langue
est en haut à droite.

## Sous quelle licence ?

L'application est publiée sous licence libre **Apache-2.0**. Le contenu de ce guide est publié
sous **CC-BY-4.0**.
