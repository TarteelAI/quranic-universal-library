import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.trackEvents()
  }

  trackEvents() {
    $(document).on('click', '[data-event]', function () {
      const $el = $(this)
      const eventName = $el.data('event')
      const category = $el.data('event-category') || 'ui_interaction'
      const label = $el.data('event-label') || $el.text().trim()
      const value = $el.data('event-value')

      gtag('event', eventName, {
        event_category: category,
        event_label: label,
        ...(value !== undefined && { value: parseInt(value) }),
      })
    })
  }
}
