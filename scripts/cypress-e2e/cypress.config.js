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
    apikey: "f8be8b50-a843-4597-89c8-477ededbe1d7",
    namespace: "dzzqh",
    api_url: "https://api.testmail.app/api/json"
  },
  e2e: {
    baseUrl: 'https://qul.tarteel.ai',
    setupNodeEvents(on, config) {
      
    },
  },
});
