# Aide-mémoire de la syntaxe Fountain

<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: CC-BY-4.0
-->

Le **Fountain** met en forme un scénario à partir de texte simple. En mode stylé, l'éditeur
applique ces règles pour vous ; en mode brut, vous les tapez directement. Voici les éléments les
plus courants. L'éditeur propose aussi un **guide de la syntaxe** dans le panneau de droite.

## En-tête de séquence

Une ligne qui commence par `INT.`, `EXT.`, `INT./EXT.` ou `EST.` :

```text
INT. CAFÉ - JOUR

EXT. RUE PAVÉE - NUIT
```

Un numéro de séquence explicite s'écrit entre dièses en fin de ligne :

```text
INT. CAFÉ - JOUR #12#
```

## Action

Un simple paragraphe. Il décrit ce qu'on voit :

```text
Marie pousse la porte. La salle est vide, une tasse fume encore sur le comptoir.
```

## Personnage, dialogue et parenthèse

Un nom en **majuscules** introduit une réplique ; la parenthèse se met entre les deux :

```text
MARIE
(à voix basse)
Il y a quelqu'un ?
```

Une extension se note entre parenthèses après le nom, par exemple `MARIE (V.O.)` pour une voix
off.

## Transition

Une ligne en majuscules qui se termine par `TO:` (ou préfixée de `>`) :

```text
COUPE FRANCHE :
```

## Texte centré

Encadré par `>` et `<` :

```text
> FIN <
```

## Note (hors impression)

Un commentaire visible dans la source mais absent du scénario imprimé, entre doubles crochets :

```text
[[à vérifier avec la production]]
```

## Emphase

Comme en Markdown : `*italique*`, `**gras**`, `_souligné_`.

## Page de titre

En tête du fichier, sous forme de champs `Clé: valeur`. En mode stylé, elle s'édite plutôt comme
une première feuille (voir [Scénario](../modes/screenplay.md)).

```text
Title: Mon Film
Author: Une Autrice
```
