// Adds labels and a helpful comment to new issues, based on the answers in
// the issue form. No AI: each dropdown answer maps to a label.
//
// It only ever adds labels. Anything a maintainer removes stays removed,
// because the workflow only runs when an issue is opened.

const fs = require('fs');
const path = require('path');

const RESOURCE_LABELS = {
  'Quran script': 'resource: quran-script',
  'Font': 'resource: font',
  'Mushaf layout': 'resource: mushaf-layout',
  'Translation': 'resource: translation',
  'Tafsir': 'resource: tafsir',
  'Transliteration': 'resource: transliteration',
  'Word-by-word': 'resource: word-by-word',
  'Recitation / segments': 'resource: recitation',
  'Morphology / grammar': 'resource: morphology',
  'Surah info': 'resource: surah-info',
  'Ayah topics': 'resource: ayah-topics',
  'Ayah themes': 'resource: ayah-theme',
  'Similar ayah': 'resource: similar-ayah',
  'Mutashabihat': 'resource: mutashabihat',
  'Qiraat': 'resource: qiraat',
  'Quran metadata': 'resource: quran-metadata',
};

// Mistakes in the Quran text itself matter most.
const CONTENT_ISSUE_PRIORITY = {
  'Quran script': 'priority: high',
  'Mushaf layout': 'priority: high',
  'Translation': 'priority: medium',
  'Tafsir': 'priority: medium',
};

const BUG_AREA_LABELS = {
  'Tools (editors, proofreading, audio tools)': 'tooling',
};

const FEATURE_CATEGORY_LABELS = {
  'Resource tooling': 'tooling',
};

const DOCS_TYPE_LABELS = {
  'Resource docs (formats, licensing, usage)': 'resource-documentation',
  'Developer docs (code, API, architecture)': 'code-documentation',
};

// Tools where any signed-in user can suggest a fix.
const QUL = 'https://qul.tarteel.ai';
const PROOFREADING_TOOLS = {
  'Translation': [['Translation proofreading', `${QUL}/translation_proofreadings`]],
  'Tafsir': [['Tafsir proofreading', `${QUL}/tafsir_proofreadings`]],
  'Transliteration': [['Transliteration proofreading', `${QUL}/transliteration_proofreadings`]],
  'Word-by-word': [
    ['Word translations', `${QUL}/word_translations`],
    ['Word transliteration proofreading', `${QUL}/word_transliteration_proofreadings`],
  ],
};

const COMMENTS_DIR = path.join(__dirname, '..', 'issue-comments');

// Issue forms render each answer as "### <field label>" followed by the
// answer. Unanswered fields read "_No response_".
function parseForm(body) {
  const answers = {};
  if (!body) return answers;

  const sections = body.split(/^### /m).slice(1);
  for (const section of sections) {
    const newline = section.indexOf('\n');
    const label = (newline === -1 ? section : section.slice(0, newline)).trim();
    const value = newline === -1 ? '' : section.slice(newline + 1).trim();
    answers[label] = value === '' || value === '_No response_' ? null : value;
  }
  return answers;
}

// Works out what to do with a newly opened issue. Pure, so it can be tested
// without GitHub.
function plan({ labels, body }) {
  const existing = new Set(labels);
  const answers = parseForm(body);
  const add = new Set();
  let comment = null;

  const resourceType = answers['Resource type'];
  if (RESOURCE_LABELS[resourceType]) add.add(RESOURCE_LABELS[resourceType]);

  if (existing.has('content-issue')) {
    if (CONTENT_ISSUE_PRIORITY[resourceType]) add.add(CONTENT_ISSUE_PRIORITY[resourceType]);
    if (PROOFREADING_TOOLS[resourceType]) {
      comment = { key: 'suggest-fix', vars: { tools: toolList(PROOFREADING_TOOLS[resourceType]) } };
    }
  }

  if (existing.has('resource-request') && answers['Licence or permission'] === 'Not sure') {
    comment = { key: 'licence-unknown', vars: {} };
  }

  if (existing.has('licence')) {
    comment = { key: 'licence-request', vars: {} };
  }

  if (existing.has('bug') && BUG_AREA_LABELS[answers['Area']]) {
    add.add(BUG_AREA_LABELS[answers['Area']]);
  }

  if (existing.has('feature-request') && FEATURE_CATEGORY_LABELS[answers['Category']]) {
    add.add(FEATURE_CATEGORY_LABELS[answers['Category']]);
  }

  if (DOCS_TYPE_LABELS[answers['Documentation type']]) {
    add.add(DOCS_TYPE_LABELS[answers['Documentation type']]);
  }

  // A maintainer may already have set a priority by hand.
  if ([...existing].some((label) => label.startsWith('priority: '))) {
    for (const label of add) if (label.startsWith('priority: ')) add.delete(label);
  }

  return {
    addLabels: [...add].filter((label) => !existing.has(label)),
    comment,
  };
}

function toolList(tools) {
  return tools.map(([name, url]) => `- [${name}](${url})`).join('\n');
}

function marker(key) {
  return `<!-- issue-triage:${key} -->`;
}

function renderComment({ key, vars }) {
  const template = fs.readFileSync(path.join(COMMENTS_DIR, `${key}.md`), 'utf8');
  const text = template.replace(/\{\{(\w+)\}\}/g, (_, name) => vars[name] ?? '');
  return `${marker(key)}\n${text.trim()}\n`;
}

// Entry point for actions/github-script.
async function run({ github, context, core }) {
  const issue = context.payload.issue;
  const repo = context.repo;
  const result = plan({
    labels: issue.labels.map((label) => label.name),
    body: issue.body,
  });

  // Adding a label that doesn't exist would create it, so only add labels
  // the repo already has.
  const repoLabels = new Set(
    (await github.paginate(github.rest.issues.listLabelsForRepo, { ...repo, per_page: 100 }))
      .map((label) => label.name)
  );
  const missing = result.addLabels.filter((label) => !repoLabels.has(label));
  if (missing.length) core.warning(`Skipping labels missing from the repo: ${missing.join(', ')}`);
  const labels = result.addLabels.filter((label) => repoLabels.has(label));

  if (labels.length) {
    await github.rest.issues.addLabels({ ...repo, issue_number: issue.number, labels });
    core.info(`Added labels: ${labels.join(', ')}`);
  }

  if (result.comment) {
    const comments = await github.paginate(github.rest.issues.listComments, {
      ...repo,
      issue_number: issue.number,
      per_page: 100,
    });
    const alreadyPosted = comments.some((c) => c.body && c.body.includes(marker(result.comment.key)));

    if (!alreadyPosted) {
      await github.rest.issues.createComment({
        ...repo,
        issue_number: issue.number,
        body: renderComment(result.comment),
      });
      core.info(`Posted comment: ${result.comment.key}`);
    }
  }
}

module.exports = {
  RESOURCE_LABELS,
  PROOFREADING_TOOLS,
  parseForm,
  plan,
  renderComment,
  run,
};
