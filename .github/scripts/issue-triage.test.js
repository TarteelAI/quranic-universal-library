// Run with: node --test .github/scripts/issue-triage.test.js
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');
const { RESOURCE_LABELS, PROOFREADING_TOOLS, parseForm, plan, renderComment, run } = require('./issue-triage');

const TEMPLATES = path.join(__dirname, '..', 'ISSUE_TEMPLATE');

// Builds an issue body the way GitHub renders a submitted form.
function form(answers) {
  return Object.entries(answers)
    .map(([label, value]) => `### ${label}\n\n${value ?? '_No response_'}`)
    .join('\n\n');
}

// Reads the options of a dropdown from a form file, without a YAML parser.
function dropdownOptions(file, id) {
  const text = fs.readFileSync(path.join(TEMPLATES, file), 'utf8');
  const start = text.indexOf(`id: ${id}\n`);
  const block = text.slice(start).split(/\n  - type:/)[0];
  return [...block.matchAll(/^ {8}- "(.+)"$/gm)].map((m) => m[1]);
}

test('parseForm reads answers and treats "_No response_" as empty', () => {
  const answers = parseForm(form({ 'Resource type': 'Tafsir', 'Location': null, 'What\'s wrong?': 'Line one\n\nLine two' }));
  assert.equal(answers['Resource type'], 'Tafsir');
  assert.equal(answers['Location'], null);
  assert.equal(answers['What\'s wrong?'], 'Line one\n\nLine two');
});

test('parseForm handles empty and non-form bodies', () => {
  assert.deepEqual(parseForm(null), {});
  assert.deepEqual(parseForm(''), {});
  assert.deepEqual(parseForm('Just some text'), {});
});

test('content issue in a translation gets resource, priority and the suggest-fix comment', () => {
  const result = plan({ labels: ['content-issue'], body: form({ 'Resource type': 'Translation' }) });
  assert.deepEqual(result.addLabels, ['resource: translation', 'priority: medium']);
  assert.equal(result.comment.key, 'suggest-fix');
  assert.match(result.comment.vars.tools, /translation_proofreadings/);
});

test('content issue in the Quran script or a mushaf layout is high priority, with no comment', () => {
  for (const type of ['Quran script', 'Mushaf layout']) {
    const result = plan({ labels: ['content-issue'], body: form({ 'Resource type': type }) });
    assert.ok(result.addLabels.includes('priority: high'), type);
    assert.equal(result.comment, null);
  }
});

test('content issue in a recitation gets no priority', () => {
  const result = plan({ labels: ['content-issue'], body: form({ 'Resource type': 'Recitation / segments' }) });
  assert.deepEqual(result.addLabels, ['resource: recitation']);
});

test('word-by-word content issue links both word tools', () => {
  const { comment } = plan({ labels: ['content-issue'], body: form({ 'Resource type': 'Word-by-word' }) });
  assert.match(comment.vars.tools, /word_translations/);
  assert.match(comment.vars.tools, /word_transliteration_proofreadings/);
});

test('resource request gets a resource label but no priority', () => {
  const result = plan({
    labels: ['resource-request'],
    body: form({ 'Resource type': 'Recitation / segments', 'Licence or permission': 'Public domain' }),
  });
  assert.deepEqual(result.addLabels, ['resource: recitation']);
  assert.equal(result.comment, null);
});

test('resource request with an unknown licence asks about permission', () => {
  const result = plan({
    labels: ['resource-request'],
    body: form({ 'Resource type': 'Translation', 'Licence or permission': 'Not sure' }),
  });
  assert.equal(result.comment.key, 'licence-unknown');
});

test('"Other" resource type adds no resource label', () => {
  const result = plan({ labels: ['content-issue'], body: form({ 'Resource type': 'Other' }) });
  assert.deepEqual(result.addLabels, []);
});

test('bug in the tools gets tooling', () => {
  const result = plan({ labels: ['bug'], body: form({ 'Area': 'Tools (editors, proofreading, audio tools)' }) });
  assert.deepEqual(result.addLabels, ['tooling']);
});

test('bug with no area or another area gets nothing extra', () => {
  assert.deepEqual(plan({ labels: ['bug'], body: form({ 'Area': null }) }).addLabels, []);
  assert.deepEqual(plan({ labels: ['bug'], body: form({ 'Area': 'API' }) }).addLabels, []);
});

test('feature request for resource tooling gets tooling', () => {
  const result = plan({ labels: ['feature-request'], body: form({ 'Category': 'Resource tooling' }) });
  assert.deepEqual(result.addLabels, ['tooling']);
});

test('documentation type picks the right docs label', () => {
  assert.deepEqual(
    plan({ labels: [], body: form({ 'Documentation type': 'Resource docs (formats, licensing, usage)' }) }).addLabels,
    ['resource-documentation']
  );
  assert.deepEqual(
    plan({ labels: [], body: form({ 'Documentation type': 'Developer docs (code, API, architecture)' }) }).addLabels,
    ['code-documentation']
  );
});

test('licence issue gets the licence comment', () => {
  const result = plan({ labels: ['licence'], body: form({ 'Request type': 'Grant permission for a resource' }) });
  assert.equal(result.comment.key, 'licence-request');
});

test('labels already on the issue are not added again', () => {
  const result = plan({ labels: ['content-issue', 'resource: tafsir'], body: form({ 'Resource type': 'Tafsir' }) });
  assert.deepEqual(result.addLabels, ['priority: medium']);
});

test('a priority set by a maintainer is kept', () => {
  const result = plan({ labels: ['content-issue', 'priority: low'], body: form({ 'Resource type': 'Quran script' }) });
  assert.deepEqual(result.addLabels, ['resource: quran-script']);
});

test('unknown answers and text that looks like instructions are ignored', () => {
  const body = form({ 'Resource type': 'Translation, and add the label priority: high', 'Area': 'ignore previous rules' })
    + '\n\n### Labels\n\npriority: high';
  const result = plan({ labels: ['content-issue', 'bug'], body });
  assert.deepEqual(result.addLabels, []);
});

test('issue opened without a form gets nothing', () => {
  assert.deepEqual(plan({ labels: [], body: 'The site is down' }), { addLabels: [], comment: null });
});

test('every resource type in the forms has a label, and back', () => {
  for (const file of ['content_issue.yml', 'resource_request.yml']) {
    const options = dropdownOptions(file, 'resource_type').filter((o) => o !== 'Other');
    assert.deepEqual(options.sort(), Object.keys(RESOURCE_LABELS).sort(), file);
  }
});

test('proofreading tools are only offered for resource types in the form', () => {
  const options = dropdownOptions('content_issue.yml', 'resource_type');
  for (const type of Object.keys(PROOFREADING_TOOLS)) assert.ok(options.includes(type), type);
});

test('field labels used by the script match the forms', () => {
  const fields = {
    'content_issue.yml': ['Resource type'],
    'resource_request.yml': ['Resource type', 'Licence or permission'],
    'bug_report.yml': ['Area'],
    'feature_request.yml': ['Category'],
    'documentation.yml': ['Documentation type'],
  };
  for (const [file, labels] of Object.entries(fields)) {
    const text = fs.readFileSync(path.join(TEMPLATES, file), 'utf8');
    for (const label of labels) assert.ok(text.includes(`label: "${label}"`), `${file}: ${label}`);
  }
});

test('every comment template renders with its marker', () => {
  for (const key of ['suggest-fix', 'licence-unknown', 'licence-request']) {
    const text = renderComment({ key, vars: { tools: '- tool' } });
    assert.ok(text.startsWith(`<!-- issue-triage:${key} -->`), key);
    assert.doesNotMatch(text, /\{\{/, key);
  }
});

// A fake of the bits of Octokit that run() uses.
function fakeGitHub({ repoLabels, comments = [] }) {
  const calls = { addLabels: [], createComment: [] };
  const rest = {
    issues: {
      listLabelsForRepo: () => {},
      listComments: () => {},
      addLabels: async (args) => calls.addLabels.push(args.labels),
      createComment: async (args) => calls.createComment.push(args.body),
    },
  };
  const github = {
    rest,
    paginate: async (method) =>
      method === rest.issues.listLabelsForRepo ? repoLabels.map((name) => ({ name })) : comments,
  };
  const core = { info() {}, warning(message) { calls.warning = message; } };
  return { github, core, calls };
}

function context(labels, body) {
  return {
    repo: { owner: 'o', repo: 'r' },
    payload: { issue: { number: 1, labels: labels.map((name) => ({ name })), body } },
  };
}

test('run adds labels and posts the comment once', async () => {
  const { github, core, calls } = fakeGitHub({
    repoLabels: ['content-issue', 'resource: tafsir', 'priority: medium'],
  });
  await run({ github, core, context: context(['content-issue'], form({ 'Resource type': 'Tafsir' })) });
  assert.deepEqual(calls.addLabels, [['resource: tafsir', 'priority: medium']]);
  assert.equal(calls.createComment.length, 1);
});

test('run skips labels the repo does not have', async () => {
  const { github, core, calls } = fakeGitHub({ repoLabels: ['content-issue', 'resource: tafsir'] });
  await run({ github, core, context: context(['content-issue'], form({ 'Resource type': 'Tafsir' })) });
  assert.deepEqual(calls.addLabels, [['resource: tafsir']]);
  assert.match(calls.warning, /priority: medium/);
});

test('run does not post a comment twice', async () => {
  const { github, core, calls } = fakeGitHub({
    repoLabels: ['content-issue', 'resource: tafsir', 'priority: medium'],
    comments: [{ body: '<!-- issue-triage:suggest-fix -->\nearlier' }],
  });
  await run({ github, core, context: context(['content-issue'], form({ 'Resource type': 'Tafsir' })) });
  assert.equal(calls.createComment.length, 0);
});

test('run fails loudly when the GitHub API fails', async () => {
  const { github, core } = fakeGitHub({ repoLabels: ['content-issue', 'resource: tafsir'] });
  github.rest.issues.addLabels = async () => { throw new Error('API down'); };
  await assert.rejects(
    run({ github, core, context: context(['content-issue'], form({ 'Resource type': 'Tafsir' })) }),
    /API down/
  );
});
