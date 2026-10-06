const { defineConfig } = require("cypress");

module.exports = defineConfig({
  viewportWidth: 1440,
  viewportHeight: 900,
  pageLoadTimeout: 300000,
  requestTimeout: 180000,
  responseTimeout: 180000,
  failOnStatusCode: false,
  defaultCommandTimeout: 60000,
  watchForFileChanges: false,
  chromeWebSecurity: false,
  failOnNonZeroExit: false,
  video: true,
  videoCompression: true,
  screenshotOnRunFailure: true,
  numTestsKeptInMemory: 1000,
  execTimeout: 120000,
  experimentalMemoryManagement: true,
  preserveResponse: false,
  env: {
    // testmail.app credentials are secrets and must NOT be committed.
    // Provide them via environment variables (TESTMAIL_APIKEY, TESTMAIL_NAMESPACE)
    // or a local, gitignored cypress.env.json. See readme.md.
    apikey: process.env.TESTMAIL_APIKEY,
    namespace: process.env.TESTMAIL_NAMESPACE,
    api_url: "https://api.testmail.app/api/json"
  },
  e2e: {
    baseUrl: 'https://qul.tarteel.ai',
    setupNodeEvents(on, config) {
      
    },
  },
});
