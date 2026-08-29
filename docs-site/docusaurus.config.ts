// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import type {Config} from '@docusaurus/types';
import type * as Preset from '@docusaurus/preset-classic';
import {themes as prismThemes} from 'prism-react-renderer';

// The user guide is served from the project's GitHub Pages site. `url` and `baseUrl` must match the
// `https://borlnov.github.io/open_cine_prod_tools/` address the deploy workflow publishes to; the
// repository slug in `baseUrl` is what makes assets resolve under the project sub-path.
const config: Config = {
  title: 'Open Cine Prod Tools',
  tagline: 'The open-source suite of film-production tools',
  favicon: 'img/ocpt_logo_glyph.svg',

  url: 'https://borlnov.github.io',
  baseUrl: '/open_cine_prod_tools/',

  organizationName: 'borlnov',
  projectName: 'open_cine_prod_tools',

  // A broken link is a documentation bug, so the build fails on one rather than shipping it.
  onBrokenLinks: 'throw',
  onBrokenMarkdownLinks: 'warn',

  // The guide ships in the two languages the application's UI speaks. English is the default locale,
  // so its content lives in `docs/`; French lives under `i18n/fr/`. The navbar's locale dropdown
  // (declared below) switches between them.
  i18n: {
    defaultLocale: 'en-GB',
    locales: ['en-GB', 'fr'],
    localeConfigs: {
      'en-GB': {label: 'English', htmlLang: 'en-GB'},
      fr: {label: 'Français', htmlLang: 'fr'},
    },
  },

  presets: [
    [
      'classic',
      {
        docs: {
          // The guide is the whole site: the docs are served at the root rather than under `/docs`.
          routeBasePath: '/',
          sidebarPath: './sidebars.ts',
          // "Edit this page" points at the source in this repository so a reader can propose a fix.
          editUrl:
            'https://github.com/borlnov/open_cine_prod_tools/tree/main/docs-site/',
          editLocalizedFiles: true,
        },
        // The guide has no blog; only the documentation.
        blog: false,
        theme: {
          customCss: './src/css/custom.css',
        },
      } satisfies Preset.Options,
    ],
  ],

  themeConfig: {
    image: 'img/ocpt_logo_glyph.svg',
    // Near-black surfaces are the application's own look, so the guide opens in dark mode and still
    // honours a reader who has asked their system for light.
    colorMode: {
      defaultMode: 'dark',
      respectPrefersColorScheme: true,
    },
    navbar: {
      title: 'Open Cine Prod Tools',
      logo: {
        alt: 'Open Cine Prod Tools logo',
        src: 'img/ocpt_logo_light.svg',
        srcDark: 'img/ocpt_logo_dark.svg',
      },
      items: [
        {
          type: 'docSidebar',
          sidebarId: 'guideSidebar',
          position: 'left',
          label: 'Guide',
        },
        // The version dropdown appears once the first release version of the guide is cut; until
        // then it silently shows the current, unreleased content.
        {
          type: 'docsVersionDropdown',
          position: 'right',
        },
        {
          type: 'localeDropdown',
          position: 'right',
        },
        {
          href: 'https://github.com/borlnov/open_cine_prod_tools',
          label: 'GitHub',
          position: 'right',
        },
      ],
    },
    footer: {
      style: 'dark',
      links: [
        {
          title: 'Guide',
          items: [
            {label: 'Introduction', to: '/'},
            {label: 'Installation', to: '/getting-started/installation'},
          ],
        },
        {
          title: 'Project',
          items: [
            {
              label: 'GitHub',
              href: 'https://github.com/borlnov/open_cine_prod_tools',
            },
            {
              label: 'Releases',
              href: 'https://github.com/borlnov/open_cine_prod_tools/releases',
            },
          ],
        },
      ],
      copyright: `Copyright © ${new Date().getFullYear()} Benoit Rolandeau. Guide content licensed CC-BY-4.0.`,
    },
    prism: {
      theme: prismThemes.github,
      darkTheme: prismThemes.dracula,
      additionalLanguages: ['bash'],
    },
  } satisfies Preset.ThemeConfig,
};

export default config;
