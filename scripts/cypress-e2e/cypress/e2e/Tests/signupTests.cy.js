import SIGNUP from "../Pages/signupPage";
let namespace = Cypress.env('namespace');
let tag = new Date().getTime();

describe("Signup", () => {
  it("Signup process for user.", () => {
    let signup = new SIGNUP();
    cy.visit("/");
    // signup.validateLandingPage();
    signup.goToAdminPanel();
    signup.toostMessage("You need to sign in or sign up before continuing.");
    signup.createNewUser();
    signup.signUpForm(`${namespace}.${tag}@inbox.testmail.app`);
  });

  it("Signup confirmation & Login for users", () => {
    let signup = new SIGNUP();
    cy.wait(3000);
    signup.validateSignupConfirmation(tag, namespace);
  });
});
