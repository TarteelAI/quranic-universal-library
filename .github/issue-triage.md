# Issue forms and triage

Every new issue goes through a form in `.github/ISSUE_TEMPLATE/`. Blank issues are turned off.

| Form | Label it adds |
|---|---|
| Report a content issue | `content-issue` |
| Request a resource | `resource-request` |
| Submit your app | `app-submission` |
| Report a bug | `bug` |
| Request a feature | `feature-request` |
| Documentation | (set by the triage script) |
| Licence or permission | `licence` |
| Ask a question | `question` |
| New contributor application | none |

## What the triage script adds

When an issue is opened, `.github/workflows/issue-triage.yml` runs `.github/scripts/issue-triage.js`. It reads the form answers and adds:

- **A resource label** from the "Resource type" dropdown, e.g. Translation → `resource: translation`.
- **A priority** for content issues: Quran script and Mushaf layout → `priority: high`, Translation and Tafsir → `priority: medium`.
- **`tooling`** for bugs in the tools and feature requests for resource tooling.
- **`resource-documentation` or `code-documentation`** from the documentation form.

It also posts one comment for some issues. The text lives in `.github/issue-comments/`:

| Comment | Posted on |
|---|---|
| `suggest-fix.md` | Content issues in a translation, tafsir, transliteration or word-by-word, linking the proofreading tool where anyone can suggest the fix |
| `licence-unknown.md` | Resource requests where the licence is "Not sure" |
| `licence-request.md` | Licence or permission issues |

There is no AI involved: each answer maps to a label in the script.

## Correcting labels

Change the labels by hand. The script only runs when an issue is opened, and it only ever adds labels, so it won't undo your change. It also leaves alone any priority a maintainer has already set.

## Changing the rules

- **Add a resource type:** add the option to the "Resource type" dropdown in both `content_issue.yml` and `resource_request.yml`, and add it to `RESOURCE_LABELS` in the script. The tests fail if the two drift apart.
- **Rename a form field the script reads:** update the script too. The tests check the field names.
- **Rename a label:** update the script. Labels missing from the repo are skipped with a warning in the workflow log, never created.
- **Change a comment:** edit the file in `.github/issue-comments/`.

Run the tests with:

```sh
node --test .github/scripts/issue-triage.test.js
```

## Troubleshooting

- **No labels were added:** open the "Issue triage" run in the Actions tab. A warning lists any labels that don't exist in the repo.
- **An issue opened without a form** (e.g. by a maintainer, or through the API) gets no labels. Add them by hand.
- **Re-running a workflow** is safe: labels already on the issue are skipped, and each comment is posted only once.
