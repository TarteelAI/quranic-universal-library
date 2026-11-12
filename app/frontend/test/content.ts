import type { ContentDoc, ContentDocsShow } from '@/types/serializers'

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

export const docsPageProps: ContentDocsShow = { doc: tutorialDoc }
