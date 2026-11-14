import { router } from '@inertiajs/react'

declare global {
  interface Window {
    // Defined by the GA4 snippet in app/views/layouts/inertia.html.erb.
    gtag?: (...args: unknown[]) => void
  }
}

// GA4 page views for the Inertia pages: one on the first load and one after every Inertia visit.
// The layout's gtag config sends none itself (send_page_view: false). Inertia swaps the head a
// moment after the navigate event, so the title is read a little later.
export function trackPageViews() {
  router.on('navigate', () => {
    window.setTimeout(() => {
      window.gtag?.('event', 'page_view', { page_location: window.location.href, page_title: document.title })
    }, 10)
  })
}
