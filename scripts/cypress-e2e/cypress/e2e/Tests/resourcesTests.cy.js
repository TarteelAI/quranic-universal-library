import SIGNUP from "../Pages/signupPage";
import RESOURCES from "../Pages/resourcesPage";

describe('Resources Page Tests', () => {
    beforeEach(() => {
        cy.visit('/');
    })

    it('Login successfully suite for user.', () => {
        let signup = new SIGNUP();
        signup.validateLandingPage();
        signup.goToAdminPanel();
        signup.toostMessage('You need to sign in or sign up before continuing.');
        signup.signIn('sajjadakbar43@gmail.com', 'test123');
        signup.toostMessage('Signed in successfully.');
        signup.validateSignInSuccess();
    })

    it('Resources name search in listing & grid view test case.', () => {
        let resources = new RESOURCES();
        resources.validateLandingPage();
        resources.clickResourcesTab();
        resources.clickLogo();
        resources.clickGetStartedButton();
        resources.verifyAvailableResources();
        resources.verifyResourcesNamesListViewSearch();
        resources.selectResourceViewType('grid');
        resources.hardRefreshBrowser();
        resources.verifyResourcesNamesGridViewSearch();
    })

    it('Resources count sorting test cases.', () => {
        let sorting = new RESOURCES();
        sorting.validateLandingPage();
        sorting.clickResourcesTab();
        sorting.sortingResources('asc', 'up');
        sorting.sortingResources('desc', 'down ');     
    })
  })