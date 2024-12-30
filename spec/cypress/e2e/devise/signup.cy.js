describe('Signup', () => {
  it('Signup suite for users', () => {
    cy.visit('http://localhost:3000');
    cy.get("[data-cy='admin-cta']").click()
    cy.get("[data-cy='signup']").click()
    cy.get("[data-cy='first_name']").type('User')
    cy.get("[data-cy='last_name']").type(`${Number(Math.random(1000))}`)
    cy.get("[data-cy='email']").type(`cytest-${Number(Math.random(1000) * 10000)}@user.com`)
    cy.get("[data-cy='password']").type('admin123')
    cy.get("[data-cy='i-agree']").click()

    cy.get("[data-cy='submit_btn']").click()
    cy.wait(100)

    cy.contains('A message with a confirmation link has been sent to your email address. Please follow the link to activate your account.').should('exist')

    // cy.getURLFromLastEmail().then((href) => {
    //   if (href) {
    //     cy.visit(href)
    //     cy.wait(2000)
    //     cy.contains('Your email address has been successfully confirmed.').should('exist')
    //   }
    // })
  })
})
