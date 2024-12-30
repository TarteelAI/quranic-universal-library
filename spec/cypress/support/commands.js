import './loginSignupCommands'
Cypress.Commands.add('selectFromDropdown', (dropdownSelector, inputSelector, value) => {
  // Click on the dropdown to activate it
  cy.get(dropdownSelector).click()

  // Type the desired value into the search field
  cy.get(inputSelector).type(value)

  // Wait for the dropdown options to become visible and select the desired value
  cy.get('.select2-results__options').should('be.visible').contains(value).click()
})

Cypress.Commands.add("clickLink", (label)=>{
  cy.get("a").contains(label).click();
});
