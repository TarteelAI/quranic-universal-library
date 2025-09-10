// Cypress configuration that delegates to scripts/cypress-e2e/
// This allows running Cypress from the project root while keeping the actual configuration
// and tests organized in the scripts/cypress-e2e directory

const { defineConfig } = require("cypress");
const path = require("path");

// Import the actual configuration from scripts/cypress-e2e/
const cypressConfig = require("./scripts/cypress-e2e/cypress.config.js");

module.exports = defineConfig({
  ...cypressConfig,
  e2e: {
    ...cypressConfig.e2e,
    // Update specPattern to point to the correct location
    specPattern: "scripts/cypress-e2e/cypress/e2e/**/*.cy.{js,jsx,ts,tsx}",
    // Update supportFile to point to the correct location
    supportFile: "scripts/cypress-e2e/cypress/support/e2e.js",
    // Update fixturesFolder to point to the correct location
    fixturesFolder: "scripts/cypress-e2e/cypress/fixtures",
    // Update screenshotsFolder for output
    screenshotsFolder: "scripts/cypress-e2e/cypress/screenshots",
    // Update videosFolder for output
    videosFolder: "scripts/cypress-e2e/cypress/videos",
  },
});