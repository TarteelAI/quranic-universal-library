import {Controller} from "@hotwired/stimulus";

// Bootstrap Collapse removed - using custom bootstrap-collapse controller instead

export default class extends Controller {
  connect() {
    // This controller is now replaced by bootstrap-collapse-controller.js
    console.warn('This collapse controller is deprecated. Use bootstrap-collapse controller instead.')
  }

  disconnect() {
  }
}
