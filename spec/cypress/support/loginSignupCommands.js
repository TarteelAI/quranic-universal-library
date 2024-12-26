import { adminEmail, password } from './index'

Cypress.Commands.add('loginUser', () => {
  cy.visit('http://localhost:3000');
  cy.get("[data-cy='admin-cta']").click()
  cy.get('[data-cy="email"]').type(adminEmail)
  cy.get('[data-cy="password"]').type(password)
  cy.get('[data-cy="submit"]').click()
  cy.wait(100)
  cy.contains('Signed in successfully.').should('exist')
})

Cypress.Commands.add('signOut', () => {
  cy.visit('http://localhost:3000');
  cy.get('[data-cy="sign-out-btn"]').should('exist').click({ force: true })
  cy.contains('Signed out successfully.').should('exist')
})
