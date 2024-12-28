import SIGNUP from "../Pages/signupPage";

describe('Signup', () => {
    it('Login successfully suite for user.', () => {
        let signup = new SIGNUP();
        cy.visit('/');
        // signup.validateLandingPage();
        signup.goToAdminPanel();
        signup.toostMessage('You need to sign in or sign up before continuing.');
        signup.signIn('sajjadakbar43@gmail.com', 'test123');
        signup.toostMessage('Signed in successfully.');
        signup.validateSignInSuccess();
    })
  })