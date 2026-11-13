# Sprint 002 stack

Layers are cut from `sprint/002-content-pages-and-guided-setup` at story commits and opened as
draft PRs. Each layer's base is the layer below it; the first is based on `qul-next`. Layers are
merged forward, never rebased or force-pushed, while the sprint runs.

| # | Branch | PR | Base | Cut at story | Files |
| --- | --- | --- | --- | --- | --- |
| 1 | `stack/002-01-spikes` | #1044 | `qul-next` | 002-03 | 94 |
| 2 | `stack/002-02-content-pages` | #1045 | layer 1 | 002-08 | 122 |

## Notes

- The local gate ran at the layer 1 head, split across the dev container and the host: Ruby
  steps in `qul-dev` (standalone tests with `RUBYOPT=-rbundler/setup`, `bin/rails
  typelizer:check`, `VITE_RUBY_AUTO_BUILD=false bundle exec rspec`), the yarn steps and
  `node_modules/.bin/vite build --ssr` on the host, before RSpec. Every step passed (RSpec 317
  examples).
- The gate ran the same split at the layer 2 head (002-08): every step passed (standalone 245
  runs, RuboCop 63 files, RSpec 347 examples, Vitest 352 tests). Cut before 002-09 to stay under
  the 150-file cap.
