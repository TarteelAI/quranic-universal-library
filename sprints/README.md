# Sprints

Each folder is one Ralph sprint, `{NNN}-{slug}/`:

| File | Written by | What it is |
| --- | --- | --- |
| `PRD.md` | `create-sprint` | Scope, non-goals and exit criteria: the plan of record |
| `spec.json` | `ralph-plan`, then the loop | Stories, deps, and each story's handoff once built |
| `lessons.md` | `ralph-plan`, then builders | Durable gotchas for later stories, append-only |
| `VALIDATION.md` | the final validation story | Live proof that the sprint met its exit criteria |
| `STACK.md` | `ralph-loop` | The sprint's stacked PRs, when it opens them |

The loop's policy for this repo is in [`.agents/ralph/constitution.md`](../.agents/ralph/constitution.md).
To start a sprint: `create-sprint` → `ralph-plan` → `ralph-loop`.
