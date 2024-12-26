
const { defineConfig } = require('cypress')
module.exports = defineConfig({
  projectId: 'i5yg5o',
  e2e: {
    baseUrl: "http://localhost:3000",
    defaultCommandTimeout: 10000,
    supportFile: "cypress/support/index.js",
    chromeWebSecurity: false,
    downloadsFolder: 'tmp/cypress/download',
    experimentalMemoryManagement: true,
    numTestsKeptInMemory: 0
  },
  retries: {
    // Configure retry attempts for `cypress run`
    // Default is 0
    runMode: 0,
    // Configure retry attempts for `cypress open`
    // Default is 0
    openMode: 0
  }
})
