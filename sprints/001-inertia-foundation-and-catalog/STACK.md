# Sprint 001 stack

Layers are cut from `sprint/001-inertia-foundation-and-catalog` at story commits and opened as
draft PRs. Each layer's base is the layer below it; the first is based on `qul-next`. Layers are
merged forward, never rebased or force-pushed, while the sprint runs.

| # | Branch | PR | Base | Cut at story | Files |
| --- | --- | --- | --- | --- | --- |
| 1 | `stack/001-01-foundation-spikes` | #1025 | `qul-next` | 001-03 | 64 |

## Notes

- The CI workflow runs on `main` only until story 001-06 lands, so layer 1 has no checks yet.
- The local gate ran at the layer 1 head: every step passed. The standalone `test/` step needs
  the gems CI installs (`minitest activesupport csv rubyzip sqlite3`) on a plain Ruby, or
  `bundle exec` in the dev container.
