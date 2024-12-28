import SIGNUP from "../Pages/signupPage";
let namespace = Cypress.env("namespace");
let tag = new Date().getTime();
let signup;

describe("Signup & Forgot Password Scenarios.", () => {
  it("Signup process for new user.", () => {
    let signup = new SIGNUP();
    cy.visit("/");
    // signup.validateLandingPage();
    signup.goToAdminPanel();
    signup.toostMessage("You need to sign in or sign up before continuing.");
    signup.createNewUser();
    signup.signUpForm(`${namespace}.${tag}@inbox.testmail.app`);
  });

  it("Signup confirmation & Login for new users", () => {
    signup = new SIGNUP();
    signup.waitFor(3000);
    signup.validateSignupConfirmation(tag, namespace);
  });

  it("Forgot Password scenario for user.", () => {
    let forgotpassword = new SIGNUP();
    cy.visit("/");
    forgotpassword.goToAdminPanel();
    forgotpassword.toostMessage("You need to sign in or sign up before continuing.");
    forgotpassword.forgotPassword(signup.EMAILADDRESS);
  });

  it("Reset Password scenario for user.", () => {
    let forgotpassword = new SIGNUP();
    forgotpassword.validateResetPassword(tag, namespace);
  });

});
