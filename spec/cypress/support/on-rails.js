
// CypressOnRails: dont remove these command
Cypress.Commands.add('appCommands', function (body) {
  Object.keys(body).forEach(key => body[key] === undefined ? delete body[key] : {});
  const log = Cypress.log({ name: "APP", message: body, autoEnd: false })
  return cy.request({
    method: 'POST',
    url: "/__e2e__/command",
    body: JSON.stringify(body),
    log: false,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
    },
    failOnStatusCode: false
  }).then((response) => {
    console.log("COMMADN RESPONSE", response.body);

    log.end();
    /*if (response.status !== 201) {
      expect(response.body.message).to.equal('')
      expect(response.status).to.be.equal(201)
    }*/
    return response.body
  });
});

Cypress.Commands.add('app', function (name, command_options) {
  return cy.appCommands({name: name, options: command_options}).then((body) => {
    return body[0]
  });
});

Cypress.Commands.add('appScenario', function (name, options = {}) {
  return cy.app('scenarios/' + name, options)
});

Cypress.Commands.add('appEval', function (code) {
  return cy.app('eval', code)
});

Cypress.Commands.add('appFactories', function (options) {
  return cy.app('factory_bot', options)
});

Cypress.Commands.add('appFixtures', function (options) {
  cy.app('activerecord_fixtures', options)
});
// CypressOnRails: end


Cypress.Commands.add('getById', (id) => {
  return cy.get(`#${id}`)
})

Cypress.Commands.add('getByClass', (className) => {
  return cy.get(`.${className}`)
})

Cypress.Commands.add('unregisterAllServiceWorkers', () => {
  if (window.navigator && navigator.serviceWorker) {
    navigator.serviceWorker.getRegistrations()
      .then((registrations) => {
        registrations.forEach((registration) => {

          Cypress.log({
            name: 'unregisterAllServiceWorkers',
            displayName: 'Service Worker',
            message: `Unregistering: ${registration?.active?.scriptURL}`
          })

          registration.unregister()
        })
      })
  }
})

Cypress.Commands.add('goOffline', () => {
  Cypress.log({
    name: 'goOffline',
    displayName: 'Network',
    message: 'Going offline'
  })

  // https://chromedevtools.github.io/devtools-protocol/1-3/Network/#method-emulateNetworkConditions
  return Cypress.automation('remote:debugger:protocol', { command: 'Network.enable' })
    .then(() => {
      return Cypress.automation('remote:debugger:protocol',
        {
          command: 'Network.emulateNetworkConditions',
          params: {
            offline: true,
            latency: -1,
            downloadThroughput: -1,
            uploadThroughput: -1,
          },
        })
    })
})

Cypress.Commands.add('goOnline', () => {
  Cypress.log({
    name: 'goOnline',
    displayName: 'Network',
    message: 'Going back online'
  })

  // https://chromedevtools.github.io/devtools-protocol/1-3/Network/#method-emulateNetworkConditions
  return Cypress.automation('remote:debugger:protocol',
      {
        command: 'Network.emulateNetworkConditions',
        params: {
          offline: false,
          latency: -1,
          downloadThroughput: -1,
          uploadThroughput: -1,
        },
      })
    .then(() => {
      return Cypress.automation('remote:debugger:protocol',
        {
          command: 'Network.disable',
        })
    })
})

// The next is optional
beforeEach(() => {
  cy.unregisterAllServiceWorkers()
})

// comment this out if you do not want to attempt to log additional info on test fail
Cypress.on('fail', (err, runnable) => {
  // allow app to generate additional logging data
  /*Cypress.$.ajax({
    url: '/__e2e__/command',
    data: JSON.stringify({name: 'log_fail', options: {error_message: err.message, runnable_full_title: runnable.fullTitle() }}),
    async: false,
    method: 'POST'
  });
*/
  throw err;
});

Cypress.Commands.add("isChecked", (selector, string) => {
  return cy.get(selector + string).then(($element) => {
    const elementType = $element.prop("type");
    let isChecked = false;
    if (elementType === "checkbox" || elementType === "radio") {
      isChecked = $element.is(":checked");
    }
    return isChecked;
  });
});

Cypress.Commands.add("UncaughtException", () => {
  Cypress.on("uncaught:exception", (err, runnable) => {
    return false;
  });
});

Cypress.Commands.add('setLocalStorageItem', (key, value) => {
  cy.window().then((win) => {
    win.localStorage.setItem(key, value);
  });
});

Cypress.Commands.add('getLocalStorageItem', (key) => {
  return cy.window().then((win) => {
    return Cypress.Promise.resolve(win.localStorage.getItem(key));
  });
});

Cypress.Commands.add('getURLFromLastEmail', () => {
  return cy.visit("/letter_opener")
    .pause()
    .get("div.col.left .message-headers.active a")
    .invoke('attr', 'href')
    .then((link) => {
      if (link) {
        cy.log(`Extracted new page link: ${link}`);
        cy.visit(link);
        cy.get('div#container iframe') 
        .its('0.contentDocument.body') 
        .find('a') 
        .invoke('attr', 'href') 
        .then((href) => {
          cy.log(`The href attribute of the link is: ${href}`);
          return Cypress.Promise.resolve(href);
        });
      } else {
        cy.log('Error: Reset Password link not found or href is empty.');
      }
    });
});