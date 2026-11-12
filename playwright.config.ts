import { defineConfig, devices } from '@playwright/test'

// Browser tests against real Rails in development, on the development clones of the snapshot
// (AGENTS.md, "Browser tests"). `yarn test:browser` starts Vite and Rails, or reuses the ones
// already running on these ports (for example Rails in Docker).
const baseURL = process.env.QUL_BROWSER_BASE_URL ?? 'http://localhost:3000'
const pageGroups = process.env.QUL_PAGE_GROUPS ?? 'home,catalog,apps,content'

export default defineConfig({
  testDir: 'spec/browser',
  outputDir: 'tmp/playwright/results',
  globalSetup: './spec/browser/support/global-setup.ts',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  reporter: [['list'], ['html', { outputFolder: 'tmp/playwright/report', open: 'never' }]],
  use: { baseURL, trace: 'retain-on-failure', screenshot: 'only-on-failure' },
  projects: [
    { name: 'desktop', use: { ...devices['Desktop Chrome'], viewport: { width: 1280, height: 800 } } },
    { name: 'phone', use: { ...devices['Pixel 7'] } },
  ],
  webServer: [
    {
      command: 'node_modules/.bin/vite',
      url: 'http://localhost:3036/vite-dev/@vite/client',
      env: { RAILS_ENV: 'development' },
      reuseExistingServer: true,
    },
    {
      command: 'bin/rails server -p 3000',
      url: `${baseURL}/health`,
      env: { QUL_PAGE_GROUPS: pageGroups },
      reuseExistingServer: true,
      timeout: 120_000,
    },
  ],
})
