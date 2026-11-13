import type {
  ContentDoc,
  ContentDocNavCategory,
  ContentDocsIndex,
  ContentDocsShow,
  ContentPagesCredits,
  ContentPagesFaq,
  ContentPagesTools,
} from '@/types/serializers'

// Shaped like Content::DocResource for a tutorial: prose, a code block and a runnable example.
export const tutorialDoc: ContentDoc = {
  key: 'tutorial-recitation-end-to-end',
  kind: 'page',
  title: 'Tutorial 1: Recitation End-to-End',
  description: 'Download a recitation and play it with word highlighting.',
  segments: [
    {
      kind: 'html',
      html: '<h1 id="tutorial-1-recitation-end-to-end">Tutorial 1: Recitation End-to-End</h1><h2 id="what-you-will-build">What you will build</h2><p>A player that <a href="/docs/datasets">highlights</a> each word.</p>',
      language: null,
      label: null,
      code: null,
    },
    { kind: 'code', html: null, language: 'json', label: 'JSON', code: '{ "1:1": { "segments": [] } }' },
    {
      kind: 'html',
      html: '<h3 id="run-the-example">Run the example</h3>',
      language: null,
      label: null,
      code: null,
    },
    {
      kind: 'playground',
      html: null,
      language: 'javascript',
      label: 'JavaScript',
      code: 'document.getElementById("app").textContent = "Word 1:1:1"',
    },
  ],
  contents: [
    { id: 'what-you-will-build', text: 'What you will build', level: 2 },
    { id: 'run-the-example', text: 'Run the example', level: 3 },
  ],
  position: {
    category: { key: 'download-resources', title: 'Download Resources' },
    previous: { key: 'tutorials', title: 'Tutorials' },
    next: { key: 'tutorial-mushaf-layout-end-to-end', title: 'Mushaf Layout' },
  },
}

// A tag page: no h1 in the body, no place in the manifest.
export const tagDoc: ContentDoc = {
  key: 'murattal',
  kind: 'tag',
  title: 'Murattal',
  description: 'A recitation style marked by a slow, measured pace.',
  segments: [
    {
      kind: 'html',
      html: '<p>A recitation style.</p><h2 id="resources-related-to-murattal-tag">Resources related to <strong>Murattal</strong> tag</h2>',
      language: null,
      label: null,
      code: null,
    },
  ],
  contents: [{ id: 'resources-related-to-murattal-tag', text: 'Resources related to Murattal tag', level: 2 }],
  position: { category: null, previous: null, next: null },
}

// Shaped like Content::DocNavCategoryResource: two categories of config/docs.yml, cut short.
export const docsNavigation: ContentDocNavCategory[] = [
  {
    key: 'download-resources',
    title: 'Download Resources',
    description: 'Discover, download, and integrate QUL datasets.',
    badge: null,
    pages: [
      { key: 'download-resources', title: 'Overview', depth: 0 },
      { key: 'datasets', title: 'Datasets', depth: 0 },
      { key: 'tutorials', title: 'Tutorials', depth: 0 },
      { key: 'tutorial-recitation-end-to-end', title: 'Recitation', depth: 1 },
      { key: 'tutorial-mushaf-layout-end-to-end', title: 'Mushaf Layout', depth: 1 },
    ],
  },
  {
    key: 'api',
    title: 'API',
    description: 'A REST API to access every QUL resource.',
    badge: 'Coming soon',
    pages: [{ key: 'api', title: 'Overview', depth: 0 }],
  },
]

export const docsPageProps: ContentDocsShow = { doc: tutorialDoc, navigation: docsNavigation }

export const docsIndexProps: ContentDocsIndex = { navigation: docsNavigation }

// Shaped like Content::PagesFaqResource: answers are prose HTML the server sanitized.
export const faqProps: ContentPagesFaq = {
  items: [
    { id: 1, question: 'What is QUL?', answer: '<p>A library of <strong>Quran resources</strong>.</p>' },
    { id: 7, question: 'Who is behind QUL?', answer: '<p>See the <a href="/credits">Credits page</a>.</p>' },
  ],
}

// Shaped like Content::PagesCreditsResource.
export const creditsProps: ContentPagesCredits = {
  organizations: [
    {
      name: 'Tafsir Center',
      url: 'https://tafsir.net/',
      description: '<p>A research center for <em>Quranic studies</em>.</p>',
      logoUrl: '/rails/active_storage/blobs/redirect/abc/logo.png',
    },
    { name: 'No Logo Foundation', url: null, description: '<p>Text.</p>', logoUrl: null },
  ],
  acknowledgements: [
    {
      entities: [{ name: 'Tanzil', url: 'https://tanzil.net/' }],
      description: 'For preparing and auditing the Quran text.',
    },
    {
      entities: [
        { name: 'Sami Rifai', url: null },
        { name: 'ReciteQuran.com', url: 'https://recitequran.com' },
      ],
      description: 'For providing recitations.',
    },
  ],
  codeContributors: [
    { login: 'octocat', url: 'https://github.com/octocat', avatarUrl: 'https://example.com/a.png', contributions: 1 },
  ],
}

// Shaped like Content::PagesToolsResource: two groups of SiteNav::ContributeTools.overview.
export const toolsProps: ContentPagesTools = {
  groups: [
    {
      heading: 'Translations & tafsir',
      summary: 'Read and fix translations, tafsirs and surah introductions.',
      tools: [
        {
          label: 'Ayah translations',
          href: '/translations',
          description: 'Proofread and suggest fixes for ayah translations in many languages.',
          category: null,
          icon: 'languages',
          external: false,
          inertia: false,
        },
      ],
    },
    {
      heading: 'Mushaf & scripts',
      summary: 'Page layouts, Quran scripts and tajweed.',
      tools: [
        {
          label: 'Mushaf layouts',
          href: '/mushaf_layouts',
          description: 'Build and proofread Mushaf page layouts.',
          category: null,
          icon: 'layout-panel-top',
          external: false,
          inertia: false,
        },
        {
          label: 'Tajweed rules',
          href: '/tajweed_words',
          description: 'Proofread and fix the tajweed rules.',
          category: null,
          icon: 'palette',
          external: false,
          inertia: false,
        },
      ],
    },
  ],
}
