import { test as base, type Request, type Route } from '@playwright/test'

type Handler = (route: Route) => Promise<void> | void

export type Stubs = {
  // page.route that records what the test stubbed, for the provenance line.
  route: (pattern: string | RegExp, handler: Handler) => Promise<void>
}

export type PageView = { location: string; title: string }

const GA_COLLECT = /google-analytics\.com\/g\/collect/
// The layout's GA4 property. Its Google tag also forwards every event to a second measurement
// id, so each page view leaves the browser twice, once per id (tid); count this one.
const MEASUREMENT_ID = 'G-57749XV2P9'

// Each GA4 hit carries one event in its query string, or several, one per body line.
function pageViews(request: Request): PageView[] {
  const url = new URL(request.url())
  if (url.searchParams.get('tid') !== MEASUREMENT_ID) return []

  const lines = request.method() === 'POST' && request.postData() ? request.postData()!.split('\n') : ['']
  return lines
    .map((line) => new URLSearchParams(`${url.search.slice(1)}&${line}`))
    .filter((params) => params.getAll('en').includes('page_view'))
    .map((params) => ({ location: params.get('dl') ?? '', title: params.get('dt') ?? '' }))
}

// Every test reports what it ran against: `real backend` when every request reached Rails, or
// `mixed` with the routes it stubbed. The line is printed and kept as an annotation in the HTML
// report. GA4's collect requests are always answered here, so no test sends page views to
// Google; `analytics` lists the page views the page sent.
export const test = base.extend<{ stubs: Stubs; analytics: PageView[] }>({
  analytics: [
    async ({ page }, use) => {
      const views: PageView[] = []
      await page.route(GA_COLLECT, async (route) => {
        views.push(...pageViews(route.request()))
        await route.fulfill({ status: 204 })
      })
      await use(views)
    },
    { auto: true },
  ],
  stubs: [
    async ({ page }, use, testInfo) => {
      const stubbed: string[] = []
      await use({
        route: async (pattern, handler) => {
          stubbed.push(String(pattern))
          await page.route(pattern, handler)
        },
      })
      const backend = stubbed.length ? `mixed: real backend, stubbed ${stubbed.join(', ')}` : 'real backend'
      const line = `${backend} (GA4 collect answered by the harness)`
      testInfo.annotations.push({ type: 'provenance', description: line })
      console.log(`[provenance] ${testInfo.project.name} › ${testInfo.titlePath.slice(1).join(' › ')}: ${line}`)
    },
    { auto: true },
  ],
})

export { expect } from '@playwright/test'
