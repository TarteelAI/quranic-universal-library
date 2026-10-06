# Cypress Tests Readme

## Prerequisites

Before running Cypress tests, ensure you have the following installed:

- **Node.js** (LTS version recommended)
- **npm** or **yarn**
- **Cypress** installed in your project (via `npm install cypress` or `yarn add cypress`)

## Configuration (required)

The signup / forgot-password specs read confirmation emails from a
[testmail.app](https://testmail.app) inbox. The API key and namespace are
secrets and are **not** stored in the repository. Provide them one of two ways:

1. Environment variables (recommended for CI):
   ```bash
   export TESTMAIL_APIKEY=your-testmail-api-key
   export TESTMAIL_NAMESPACE=your-testmail-namespace
   ```
2. A local `cypress.env.json` next to `cypress.config.js` (gitignored):
   ```json
   {
     "apikey": "your-testmail-api-key",
     "namespace": "your-testmail-namespace"
   }
   ```

Never commit real credentials. If a key is ever committed, rotate it in the
testmail.app dashboard immediately.

## Running Tests

### 1. Via Test Runner

The Test Runner provides a GUI for running tests and debugging interactively.

#### Steps:

1. Open your terminal and navigate to your project directory like .
2. Run the following command to open Cypress Test Runner:
   ```bash
   npx cypress open
   ```
3. In the Test Runner, select the browser in which you want to run the tests.
4. Click on the desired test file to execute it.

### 2. Via CLI

Running tests via CLI is suitable for CI/CD pipelines or headless execution.

#### Steps:

1. Open your terminal and navigate to your project directory.
2. Run the following command to execute all tests in headless mode:
   ```bash
   npx cypress run
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
