# Sprint 001 stack

Layers are cut from `sprint/001-inertia-foundation-and-catalog` at story commits and opened as
draft PRs. Each layer's base is the layer below it; the first is based on `qul-next`. Layers are
merged forward, never rebased or force-pushed, while the sprint runs.

| # | Branch | PR | Base | Cut at story | Files |
| --- | --- | --- | --- | --- | --- |
| 1 | `stack/001-01-foundation-spikes` | #1025 | `qul-next` | 001-03 | 64 |
| 2 | `stack/001-02-type-pages-slice` | #1026 | layer 1 | 001-06 | 78 |
| 3 | `stack/001-03-catalog-data-and-downloads` | #1027 | layer 2 | 001-10 | 96 |
| 4 | `stack/001-04-catalog-pages` | #1030 | layer 3 | 001-13 | 90 |
| 5 | `stack/001-05-detail-page-and-previews` | #1031 | layer 4 | 001-16 | 121 |
| 6 | `stack/001-06-home-apps-validation-docs` | #1032 | layer 5 | 001-19 | 83 |

## Notes

- CI for `qul-next`, `sprint/**` and `stack/**` (`.github/workflows/qul-next.yml`) lands in layer 2,
  so layer 1 has no checks of its own.
- The local gate ran at the layer 1 head: every step passed. The standalone `test/` step needs
  the gems CI installs (`minitest activesupport csv rubyzip sqlite3`) on a plain Ruby, or
  `bundle exec` in the dev container.
- The local gate ran at the layer 6 head (001-19): every step passed (standalone 245 runs, RSpec 269
  examples, Vitest 239 tests).
- Layer 6 is the last layer. Story 001-20 adds only sprint-folder files; they reach `qul-next` with
  the sprint merge and are in the cutover PR against `main`.
