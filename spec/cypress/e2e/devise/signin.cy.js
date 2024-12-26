import {adminEmail, password} from './../../support/index'

describe('user sign in', () => {
  it('Should sign in the user', () => {
    cy.loginUser();
    cy.signOut();
  })
})