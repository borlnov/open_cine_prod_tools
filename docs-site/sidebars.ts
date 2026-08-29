// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import type {SidebarsConfig} from '@docusaurus/plugin-content-docs';

// The guide's structure is declared explicitly rather than inferred from the folder tree, so the
// chapter order is owned in one place and matches the outline agreed for the site. Every id below
// is the path of a file under `docs/` (without its `.md` extension); the French translation mirrors
// the same ids under `i18n/fr/`.
const sidebars: SidebarsConfig = {
  guideSidebar: [
    'index',
    {
      type: 'category',
      label: 'Getting started',
      collapsed: false,
      items: [
        'getting-started/installation',
        'getting-started/first-steps',
        'getting-started/workspace-tour',
      ],
    },
    {
      type: 'category',
      label: 'Core concepts',
      items: [
        'concepts/projects-and-episodes',
        'concepts/fountain-source-of-truth',
        'concepts/project-versions',
        'concepts/read-only-preview',
        'concepts/spell-check-and-dictionary',
        'concepts/exporting-overview',
      ],
    },
    {
      type: 'category',
      label: 'Production modes',
      items: [
        'modes/screenplay',
        'modes/shot-list',
        'modes/resources',
        'modes/breakdown',
        'modes/schedule',
        'modes/budget',
      ],
    },
    {
      type: 'category',
      label: 'Exporting your work',
      items: ['exports/exporting-your-work'],
    },
    {
      type: 'category',
      label: 'Reference',
      items: [
        'reference/fountain-cheatsheet',
        'reference/keyboard-shortcuts',
        'reference/troubleshooting',
        'reference/faq',
        'reference/glossary',
      ],
    },
  ],
};

export default sidebars;
