<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: CC-BY-4.0
-->

# Installation

Open Cine Prod Tools est une application de bureau. On l'installe en téléchargeant le fichier
correspondant à son système, puis en l'ouvrant. Cette page décrit chaque plateforme.

## Où télécharger

Tous les fichiers d'installation se trouvent sur la page
[GitHub Releases](https://github.com/borlnov/open_cine_prod_tools/releases) du projet. Chaque
version publiée y propose :

- le paquet `.deb` pour **Linux** ;
- l'installeur pour **Windows** ;
- l'image disque `.dmg` pour **macOS**.

Choisissez la dernière version, puis le fichier de votre système.

:::info Applications non signées

Les binaires ne sont pas signés numériquement. Ce n'est pas un signe de danger, mais votre
système affichera un avertissement au premier lancement. Les sections ci-dessous expliquent
comment passer outre sur chaque plateforme.

:::

## Plateformes prises en charge

| Plateforme | État |
| --- | --- |
| Linux | Développement actif |
| Windows | Développement actif |
| macOS | Build disponible, non signé et **jamais testé** |
| Android | Ébauche (pas encore utilisable) |
| iOS | Ébauche (pas encore utilisable) |

Linux et Windows sont les deux plateformes réellement développées et utilisées. Android et iOS
ne sont pour l'instant que des ébauches.

## Linux

Téléchargez le paquet `.deb`, puis installez-le depuis un terminal :

```bash
sudo apt install ./open-cine-prod-tools_<version>_amd64.deb
```

Remplacez `<version>` par le numéro du fichier téléchargé. L'application apparaît ensuite dans
votre menu d'applications.

## Windows

Téléchargez l'installeur et lancez-le. Comme l'application n'est pas signée, **SmartScreen**
peut afficher un écran bleu « Windows a protégé votre ordinateur » au premier lancement :

1. cliquez sur **Informations complémentaires** ;
2. cliquez sur **Exécuter quand même**.

L'avertissement ne réapparaît plus ensuite.

## macOS

:::warning Build jamais testé sur Mac

Le `.dmg` est produit automatiquement, mais **personne n'a encore lancé l'application sur un
Mac** : le projet n'en dispose pas. Considérez cette version comme un essai, et n'hésitez pas
à faire remonter ce qui fonctionne ou non.

:::

Ouvrez le `.dmg` téléchargé, puis glissez **Open Cine Prod Tools** sur le raccourci
`Applications` placé à côté.

Comme l'application n'est pas signée, **Gatekeeper** refuse de la lancer directement. Deux
façons de passer outre :

- faites un clic droit sur l'application dans `Applications`, choisissez **Ouvrir**, puis à
  nouveau **Ouvrir** dans la fenêtre qui suit ;
- ou levez une fois pour toutes l'attribut de quarantaine depuis un terminal :

```bash
xattr -dr com.apple.quarantine "/Applications/Open Cine Prod Tools.app"
```

## Et ensuite

Une fois l'application installée, passez aux [premiers pas](first-steps.md) pour créer votre
premier projet.
