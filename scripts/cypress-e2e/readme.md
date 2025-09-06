# Cypress Tests Readme

This directory contains the end-to-end testing setup for QUL using [Cypress](https://www.cypress.io/).

## Quick Start

From the **project root**, you can run Cypress tests using these npm scripts:

```bash
# Open Cypress Test Runner (interactive)
npm run test:e2e:open

# Run tests in headless mode  
npm run test:e2e

# Alternative commands
npm run cypress:open     # Interactive test runner
npm run cypress:run      # Headless execution
```

## Prerequisites

Before running Cypress tests, ensure you have the following installed:

- **Node.js** (LTS version recommended)
- **npm** or **yarn**
- **Cypress** installed in your project (via `npm install cypress` or `yarn add cypress`)

## Running Tests

### 1. Via Test Runner

The Test Runner provides a GUI for running tests and debugging interactively.

#### Steps:

1. Open your terminal and navigate to your project directory.
2. Run the following command to open Cypress Test Runner:
   ```bash
   npm run cypress:open
   ```
3. In the Test Runner, select the browser in which you want to run the tests.
4. Click on the desired test file to execute it.

### 2. Via CLI

Running tests via CLI is suitable for CI/CD pipelines or headless execution.

#### Steps:

1. Open your terminal and navigate to your project directory.
2. Run the following command to execute all tests in headless mode:
   ```bash
   npm run cypress:run
   ```
3. (Optional) To execute tests in a specific spec file, use:
   ```bash
   npx cypress run --spec "cypress/e2e/Tests/<spec-file>.cy.js"
   ```
   Replace `<spec-file>` with the name of the test file.
4. To run tests in a specific browser, use:
   ```bash
   npx cypress run --browser chrome
   ```
   Supported browsers include `chrome`, `edge`, `firefox`, etc.

## Test Structure

- **Configuration**: `cypress.config.js` - Main Cypress configuration
- **Test Files**: `cypress/e2e/Tests/` - Contains all test spec files
- **Page Objects**: `cypress/e2e/Pages/` - Page object models for better test organization
- **Support Files**: `cypress/support/` - Custom commands and global configuration
- **Fixtures**: `cypress/fixtures/` - Test data files

## Available Test Suites

- **signupTests.cy.js**: User registration and email verification workflows
- **signinTests.cy.js**: User authentication and login validation

## Configuration

The main configuration is in `cypress.config.js` which includes:
- Base URL: `https://qul.tarteel.ai`
- Viewport settings: 1440x900
- Timeout configurations
- Test environment variables

## CI/CD Integration

Cypress tests are automatically run in GitHub Actions for:
- Pull requests to `main` and `develop` branches
- Pushes to `main` and `develop` branches

See `.github/workflows/cypress.yml` for the complete CI configuration.
