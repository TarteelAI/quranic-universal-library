import { Application } from "@hotwired/stimulus"

const application = Application.start()

// Configure Stimulus development experience
application.debug = false
window.Stimulus   = application


const context = require.context(".", true, /\.js$/)
context.keys().forEach((key) => {
  if (key !== "./application.js" && key !== "./index.js") {
    const module = context(key)
    const controllerName = key.replace(/^\.\//, "").replace(/\.js$/, "").replace(/\//g, "--")
    const controllerClass = module.default || module[Object.keys(module)[0]]
    
    if (controllerClass && typeof controllerClass === "function") {
      application.register(controllerName, controllerClass)
    }
  }
})

export { application }
