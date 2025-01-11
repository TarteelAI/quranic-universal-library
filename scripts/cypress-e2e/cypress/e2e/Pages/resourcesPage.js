class RESOURCES {
  constructor() {
    this.EMAILADDRESS = null;
    this.USERNAME = null;
  }

  clickResourcesTab() {
    cy.get('header a[href="/resources"]')
      .first()
      .click()
      .then(() => {
        cy.url().should("include", "/resources");
        cy.get("#resources h1")
          .invoke("text")
          .should(
            "eq",
            "Quranic Universal Library, is the largest library of Quranic content available for download. Build amazing projects using these invaluable resources."
          );
      });
  }

  validateLandingPage() {
    cy.get(".qul-logo").should("be.visible");
    cy.get('a[href="/resources"]').first().should("contain.text", "Resources");
    cy.get('a[href="/tools"]').first().should("contain.text", "Tools");
    cy.get('a[href="https://discord.gg/HAcGh8mfmj"]')
      .first()
      .should("contain.text", "Community");
    cy.get('a[href="/faq"]').first().should("contain.text", "FAQ");
    cy.get('a[href="https://github.com/TarteelAI/quranic-universal-library"]')
      .first()
      .should("contain.text", "Github");
  }

  clickLogo() {
    cy.get(".qul-logo")
      .click()
      .then(() => {
        cy.url().should("include", "/");
        cy.get("#resources h1").should("not.exist");
        cy.get(
          'spline-viewer[url="https://static-cdn.tarteel.ai/qul/spline/scene.splinecode"]'
        )
          .shadow()
          .find("canvas")
          .should("be.visible");
        cy.get(
          'spline-viewer[url="https://static-cdn.tarteel.ai/qul/spline/scene.splinecode"]'
        )
          .shadow()
          .find("#preloader #spinner")
          .should("exist");
        cy.get("div h1")
          .last()
          .invoke("text")
          .should("eq", "The Toolkit for Muslim Developers");
      });
  }

  clickGetStartedButton() {
    cy.get("#get-started")
      .first()
      .click()
      .then(() => {
        cy.url().should("include", "/resources");
        cy.get("#resources h1")
          .invoke("text")
          .should(
            "eq",
            "Quranic Universal Library, is the largest library of Quranic content available for download. Build amazing projects using these invaluable resources."
          );
      });
  }

  verifyAvailableResources() {
    cy.get("#resources .resources-list h2")
      .invoke("text")
      .then((text) => {
        expect(text.trim()).to.eq("Available Resources");
      });
    cy.get(".resources-list h2+div")
      .invoke("text")
      .then((text) => {
        cy.get(".resources-table tr[data-search]").should(
          "have.length",
          Number(text)
        );
      });
  }

  selectResourceViewType(viewType) {
    cy.get(`[href="/resources?view=${viewType}"]`)
      .click()
      .then(() => {
        cy.url().should("include", `view=${viewType}`);
      });
  }

  hardRefreshBrowser() {
    cy.url().then((url) => {
      cy.visit(url);
    });
  }

  verifyResourcesNamesListViewSearch() {
    cy.get(
      ".resources-table tr[data-search] div div span.tw-font-semibold"
    ).then(($elements) => {
      const totalLength = $elements.length;
      $elements.each((index, $el) => {
        const text = $el.textContent.trim();
        cy.log(text);
        cy.get('input[placeholder="Quick Search..."]')
          .as("searchField")
          .type(text)
          .then(() => {
            cy.get(
              '.resources-table tr[data-search][class*="tw-hidden"]'
            ).should("have.length", totalLength - 1);
            cy.get(
              '.resources-table tr[data-search]:not([class*="tw-hidden"])'
            ).should("have.length", 1);
            cy.get("@searchField").clear();
            cy.get(
              '.resources-table tr[data-search]:not([class*="tw-hidden"])'
            ).should("have.length", totalLength);
          });
      });
    });
  }

  verifyResourcesNamesGridViewSearch() {
    cy.get(".resources-list a.tw-inline-block div p.tw-font-semibold").then(
      ($elements) => {
        const totalLength = $elements.length;
        $elements.each((index, $el) => {
          const text = $el.textContent.trim();
          cy.log(text);
          cy.get('input[placeholder="Quick Search..."]')
            .as("searchField")
            .type(text)
            .then(() => {
              cy.get(
                '.resources-list a.tw-inline-block[data-search][class*="tw-hidden"]'
              ).should("have.length", totalLength - 1);
              cy.get(
                '.resources-list a.tw-inline-block[data-search]:not([class*="tw-hidden"])'
              ).should("have.length", 1);
              cy.get("@searchField").clear();
              cy.get(
                '.resources-list a.tw-inline-block[data-search]:not([class*="tw-hidden"])'
              ).should("have.length", totalLength);
            });
        });
      }
    );
  }

  sortingResources(type, direction) {
    cy.get(`a[href="/resources?sort_key=count&sort_order=${type}"] .fa-sort-${direction}`)
      .scrollIntoView()
      .should('be.visible')
      .click({ force: true })
      .then(() => {
        cy.wait(1000); 
        cy.get(".resources-table tr[data-search] td a.tw-rounded-full")
          .then(($elements) => {
            return Array.from($elements)
              .map((el) => Number(el.textContent.trim()))
              .filter((num) => !isNaN(num));
          })
          .should((numbers) => {
            for (let i = 1; i < numbers.length; i++) {
              if (type === "asc") {
                expect(numbers[i]).to.be.gte(
                  numbers[i - 1],
                  `Expected ${numbers[i]} to be greater than or equal to ${numbers[i - 1]}`
                );
              } else {
                expect(numbers[i]).to.be.lte(
                  numbers[i - 1],
                  `Expected ${numbers[i]} to be less than or equal to ${numbers[i - 1]}`
                );
              }
            }
          });
      });
  }
}
export default RESOURCES;
