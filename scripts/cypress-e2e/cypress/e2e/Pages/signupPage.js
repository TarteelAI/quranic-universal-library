class SIGNUP {
  constructor() {
    this.EMAILADDRESS = null;
    this.USERNAME = null;
  }

  generateRandomNumber(length) {
    if (length <= 0 || length >= 12) {
      throw new Error("Length must be between 1 and 12");
    }
    const min = Math.pow(10, length - 1);
    const max = Math.pow(10, length) - 1;
    return Math.floor(Math.random() * (max - min + 1)) + min;
  }

  generateRandomString(digit, characters) {
    const letters = "abcdefghijklmnopqrstuvwxyz";
    const digits = "0123456789";
    let randomLetters = "";
    for (let i = 0; i < characters; i++) {
      randomLetters += letters.charAt(
        Math.floor(Math.random() * letters.length)
      );
    }
    let randomDigits = "";
    for (let i = 0; i < digit; i++) {
      randomDigits += digits.charAt(Math.floor(Math.random() * digits.length));
    }
    return randomLetters + randomDigits;
  }

  validateLandingPage() {
    cy.get(".qul-logo").should("be.visible");
    cy.get('a[href="/resources"]').should("contain.text", "Resources");
    cy.get('a[href="/tools"]').should("contain.text", "Tools");
    cy.get('a[href="https://discord.gg/HAcGh8mfmj"]').should(
      "contain.text",
      "Community"
    );
    cy.get('a[href="/faq"]').should("contain.text", "FAQ");
    cy.get(
      'a[href="https://github.com/TarteelAI/quranic-universal-library"]'
    ).should("contain.text", "Sign In");
  }

  goToAdminPanel() {
    cy.intercept("GET", "**/admin").as("getAdmin");
    cy.intercept("GET", "**/users/sign_in").as("signIn");
    cy.get('a[href="/admin"]')
      .click()
      .then(() => {
        cy.wait("@getAdmin").then((interception) => {
          expect(interception.response.statusCode).to.eq(302);
        });
        cy.wait("@signIn").then((interception) => {
          expect(interception.response.statusCode).to.eq(200);
        });
      });
  }

  toostMessage(message) {
    cy.get(".toast-message").should("contain.text", message);
    cy.get("button.toast-close-button").should("be.visible").click();
  }

  extractAutheticityToken() {
    cy.get('input[name="authenticity_token"]')
      .invoke("val")
      .then((token) => {
        cy.log("Authenticity Token:", token);
        return token;
      });
  }

  waitFor(loadingTime) {
    cy.wait(loadingTime);
  }

  createNewUser() {
    cy.intercept("GET", "**/users/sign_up").as("signUp");
    cy.get('[href="/users/sign_up"]')
      .should("be.visible")
      .click()
      .then(() => {
        cy.wait("@signUp").then((interception) => {
          expect(interception.response.statusCode).to.eq(200);
        });
      });
  }

  signUpForm(emailAddress) {
    cy.get('[name="user[first_name]"]').type("Test_User_first_name");
    cy.get('[name="user[last_name]"]').type("Test_User_last_name");
    cy.get('[name="user[email]"]').type(emailAddress);
    cy.get('[name="user[password]"]').type("TestPassword123");
    cy.get('input[name="user[add_to_mailing_list]"][type="checkbox"]').click();
    cy.get('input[value="Sign up"]').click();
    cy.get(".toast-message").should(
      "contain.text",
      "A message with a confirmation link has been sent to your email address. Please follow the link to activate your account."
    );
  }

  extractConfirmationLink = (text) => {
    const regex =
      /https:\/\/qul\.tarteel\.ai\/users\/confirmation\?confirmation_token=[\w-]+/g;
    const match = text.match(regex);
    return match ? match[0] : null;
  };

  extractResetPasswordLink = (text) => {
    const regex = /Change my password\n\[(https:\/\/qul\.tarteel\.ai\/users\/password\/edit\?locale=en&reset_password_token=[\w-]+)\]/;
    const match = text.match(regex);
    return match ? match[1] : null;
  };

  validateSignupConfirmation(tag, namespace) {
    cy.request({
      method: "GET",
      url: Cypress.env("api_url"),
      failOnStatusCode: false,
      qs: {
        apikey: Cypress.env("apikey"),
        namespace: Cypress.env("namespace"),
        inbox: `${namespace}.${tag}@inbox.testmail.app`,
        tag: tag,
        livequery: true,
      },
    }).then((response) => {
      cy.log(response.body);
      expect(response.status).to.eq(200);
      let email = response.body.emails.find((email) =>
        email.subject.includes("Confirmation instructions")
      );
      if (email) {
        cy.log("Email Subject: Confirmation instructions");
        let emailText = email.text;
        this.EMAILADDRESS = email.to;
        cy.log(`Email Text: ${emailText}`);
        const confirmationLink = this.extractConfirmationLink(emailText);
        cy.log(`Confirmation Link: ${confirmationLink}`);
        expect(confirmationLink).to.not.be.null;
        if (confirmationLink) {
          cy.visit(confirmationLink);
          this.toostMessage(
            "Your email address has been successfully confirmed."
          );
          this.signIn(
            `${namespace}.${tag}@inbox.testmail.app`,
            "TestPassword123"
          );
          this.toostMessage("Signed in successfully.");
        } else {
          cy.log("Confirmation link not found.");
        }
      } else {
        cy.log("Email with subject 'Confirmation instructions' not found.");
      }
    });
  }

  validateResetPassword(tag, namespace) {
    cy.request({
      method: "GET",
      url: Cypress.env("api_url"),
      failOnStatusCode: false,
      qs: {
        apikey: Cypress.env("apikey"),
        namespace: Cypress.env("namespace"),
        inbox: `${namespace}.${tag}@inbox.testmail.app`,
        tag: tag,
        livequery: true,
      },
    }).then((response) => {
      cy.log(response.body);
      expect(response.status).to.eq(200);
      let email = response.body.emails.find((email) =>
        email.subject.includes("Reset password instructions")
      );
      if (email) {
        cy.log("Email Subject: Reset password instructions");
        let emailText = email.text;
        this.EMAILADDRESS = email.to;
        cy.log(`Email Text: ${emailText}`);
        const confirmationLink = this.extractResetPasswordLink(emailText);
        cy.log(`Reset Password Link: ${confirmationLink}`);
        expect(confirmationLink).to.not.be.null;
        if (confirmationLink) {
          cy.visit(confirmationLink);
          this.resetPassword("changePassword", "changePassword");
          this.toostMessage("Your password has been changed successfully. You are now signed in.")
          this.validateSignInSuccess();
        } else {
          cy.log("Reset password instructions link not found.");
        }
      } else {
        cy.log("Email with subject 'Reset password instructions' not found.");
      }
    });
  }

  signIn(email, password) {
    cy.get("input#user_email").type(email);
    cy.get("input#user_password").type(password);
    cy.get('[name="commit"]').click();
  }

  validateSignInSuccess() {
    cy.get('[href="/users/sign_out"]').should("contain.text", "Logout");
  }

  forgotPassword(email) {
    cy.intercept("POST", "**/users/password").as("forgotPassword");
    cy.get('a[href="/users/password/new"]').click();
    cy.get('[name="user[email]"]').type(email);
    cy.get('input[value="Send me reset password instructions"]')
      .click()
      .then(() => {
        cy.wait("@forgotPassword").then((interception) => {
          expect(interception.response.statusCode).to.eq(302);
        });
        this.toostMessage(
          "If your email address exists in our database, you will receive a password recovery link at your email address in a few minutes."
        );
        cy.get('input[value="Send me reset password instructions"]').should(
          "not.exist"
        );
        cy.get('[value="Sign in"]').should("be.visible");
      });
  }

  resetPassword(email, password) {
    cy.get('input[name="user[password]"]').type(email);
    cy.get("input#user_password_confirmation").type(password);
    cy.get('[value="Change my password"]').click();
  }
}

export default SIGNUP;
