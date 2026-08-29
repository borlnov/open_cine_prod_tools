# Exporter votre travail

<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: CC-BY-4.0
-->

Cette page rassemble, mode par mode, tous les documents que l'application sait produire. Le
principe général — la commande **Exporter**, le panneau de cartes, le dialogue « Enregistrer
sous » — est décrit dans [Exporter, en bref](../concepts/exporting-overview.md).

## Formats

L'application exporte aujourd'hui trois formats : **PDF** (documents à imprimer ou diffuser),
**XLSX** (classeurs tableurs modifiables) et **`.fountain`** (scénario en texte simple).

## Les documents, mode par mode

### Scénario

- **PDF du scénario** — le script composé en pages, avec la page de titre et les numéros de
  séquence explicites. *(PDF)*
- **Scénario Fountain** — le scénario en texte Fountain. *(.fountain)*

### Dépouillement

- **Fiches de dépouillement** — une feuille par séquence. *(PDF)*
- **Classeur de dépouillement** — une feuille *Séquences* et une feuille *Dépouillement*
  filtrable. *(XLSX)*

### Découpage

- **Couverture du scénario** — le scénario imprimé avec une barre de couleur en marge le long de
  chaque passage couvert ; options de format, page de titre, numéros de séquence, légende,
  résumé. *(PDF)*
- **Classeur du découpage** — une ligne par plan, tous ses champs. *(XLSX)*

### Ressources

- **Classeur des ressources** — quatre feuilles : personnes, rôles, décors, éléments. *(XLSX)*
- **Liste de contacts** — l'équipe et le casting sur une feuille à faire circuler. *(PDF)*

### Plan de travail

- **Feuilles de service** — générale et nominatives. *(PDF)*
- **Plan de travail détaillé** — grilles de synthèse et agenda par journée. *(PDF)*
- **Plan de travail** — le même en tableur, avec une chronologie. *(XLSX)*
- **Day Out of Days** — le plan du casting. *(PDF)*
- **Plan de travail synthétique** — une ligne par séquence dans l'ordre de tournage. *(PDF)*
- **Pages du jour** — les pages du scénario d'une journée. *(PDF)*

### Budget

- **Devis** — la nomenclature CNC, poste par poste ; propose une base de TVA. *(PDF)*
- **Plan de financement** — ce qui paie le film. *(PDF)*
- **Journal de caisse** — chaque écriture, avec son numéro de pièce. *(XLSX)*
- **Rapport financier** — le devis contre le payé et l'engagé. *(PDF)*

## Options et portée

- Certains documents ouvrent une **fenêtre d'options** avant l'enregistrement — par exemple la
  couverture du scénario propose le format de page, la page de titre, les numéros de séquence,
  une page de légende et une page de résumé.
- Un export lié à un épisode produit **l'épisode sélectionné**, et le nom proposé inclut une
  étiquette d'épisode dès que le projet en compte plusieurs.

## Envoyer le projet entier

Pour transmettre le projet complet à quelqu'un, exportez-le en **paquet `.ocptz`** — voir
[Exporter, en bref](../concepts/exporting-overview.md).
