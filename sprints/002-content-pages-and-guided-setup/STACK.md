# Sprint 002 stack

Layers are cut from `sprint/002-content-pages-and-guided-setup` at story commits and opened as
draft PRs. Each layer's base is the layer below it; the first is based on `qul-next`. Layers are
merged forward, never rebased or force-pushed, while the sprint runs.

| # | Branch | PR | Base | Cut at story | Files |
| --- | --- | --- | --- | --- | --- |
| 1 | `stack/002-01-spikes` | #1044 | `qul-next` | 002-03 | 94 |
| 2 | `stack/002-02-content-pages` | #1045 | layer 1 | 002-08 | 122 |
| 3 | `stack/002-03-catalog-detail-apps` | #1046 | layer 2 | 002-14 (+ RuboCop fix bdeca7bf) | 142 |
| 4 | `stack/002-04-setup-bundle-requests` | #1048 | layer 3 | 002-19 (+ Prettier fix) | 123 |

## Notes

- The local gate ran at the layer 1 head, split across the dev container and the host: Ruby
  steps in `qul-dev` (standalone tests with `RUBYOPT=-rbundler/setup`, `bin/rails
  typelizer:check`, `VITE_RUBY_AUTO_BUILD=false bundle exec rspec`), the yarn steps and
  `node_modules/.bin/vite build --ssr` on the host, before RSpec. Every step passed (RSpec 317
  examples).
- The gate ran the same split at the layer 2 head (002-08): every step passed (standalone 245
  runs, RuboCop 63 files, RSpec 347 examples, Vitest 352 tests). Cut before 002-09 to stay under
  the 150-file cap.
- The gate at the layer 3 head first failed only at RuboCop (147 offences in sprint-001 catalog
  files the layer touched); bdeca7bf clears them. Then every step passed (RuboCop 107 files,
  RSpec 399 examples, Vitest 387 tests).
- The gate at the layer 4 head failed only at Prettier (`spec/browser/kits.spec.ts`, formatting
  from before this layer); 252ed82c formats it. Then every step passed (RuboCop 143 files, RSpec
  505 examples, Vitest 444 tests).
