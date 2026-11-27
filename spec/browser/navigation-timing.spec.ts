import { expect, type Locator, type Page, test } from '@playwright/test'

// A measurement, not a test: `QUL_NAV_TIMING=1 yarn test:browser navigation-timing.spec.ts
// --project desktop` times in-app navigations (click to the next page rendered) and counts the
// requests a scripted browse makes. Point it at a deployed server with QUL_BROWSER_BASE_URL;
// behind Cloudflare Access, CF_ACCESS_CLIENT_ID and CF_ACCESS_CLIENT_SECRET in the environment
// sign the browser in once (Access answers with its cookie), so no other host sees the token.
//
// It uses Playwright's own `test`, not the harness's: a routed page has no HTTP cache, so every
// visit would download its page's script again, which a returning visitor does not. The browser
// blocks instead (DevTools protocol, cache kept): GA4, so no page views reach Google, and the
// URL patterns in QUL_NAV_BLOCK (comma-separated), for a script a deployed server adds that
// would take the page elsewhere. Real backend otherwise.
//
//   QUL_NAV_RUNS   navigations per case (default 20)
//   QUL_NAV_DWELL  how long the pointer rests on a link before the click, in ms (default 200;
//                  0 clicks at once, which leaves Inertia's hover prefetch no time)
//   QUL_NAV_BLOCK  more URL patterns for the browser to block
//
// It prints one `[nav]` line per case (p50, p95, mean, ms) and one `[load]` line per browse,
// each with the commit the page names (data-build), so a set records what it measured.
const RUNS = Number(process.env.QUL_NAV_RUNS ?? 20)
const DWELL = Number(process.env.QUL_NAV_DWELL ?? 200)

test.skip(!process.env.QUL_NAV_TIMING, 'Set QUL_NAV_TIMING=1 to measure navigation.')
// In order, one at a time: concurrent runs would load the server and each other
test.describe.configure({ mode: 'default' })

const BLOCKED = [
  '*google-analytics.com/*',
  '*googletagmanager.com/*',
  ...(process.env.QUL_NAV_BLOCK?.split(',').filter(Boolean) ?? []),
]

test.beforeEach(async ({ page }, testInfo) => {
  test.skip(testInfo.project.name !== 'desktop', 'measured at desktop width')
  test.setTimeout(RUNS * 30_000)
  page.setDefaultTimeout(15_000)
  const cdp = await page.context().newCDPSession(page)
  await cdp.send('Network.enable')
  await cdp.send('Network.setBlockedURLs', { urls: BLOCKED })
  page.on('response', (response) => {
    if (/google-analytics\.com|googletagmanager\.com/.test(response.url()))
      throw new Error(`not blocked: ${response.url()}`)
  })
  const id = process.env.CF_ACCESS_CLIENT_ID
  const secret = process.env.CF_ACCESS_CLIENT_SECRET
  if (id && secret) {
    const response = await page.context().request.get('/health', {
      headers: { 'CF-Access-Client-Id': id, 'CF-Access-Client-Secret': secret },
    })
    expect(response.ok()).toBe(true)
  }
})

async function build(page: Page) {
  return (
    (await page
      .locator('[data-build]')
      .first()
      .getAttribute('data-build')
      .catch(() => null)) ?? 'unknown'
  )
}

async function hydrated(page: Page) {
  await page.waitForFunction(() =>
    Object.keys(document.getElementById('app') ?? {}).some((key) => key.startsWith('__reactContainer')),
  )
}

// Rests the pointer on the link for DWELL ms, clicks it, and returns the time from the click to
// the first frame in which the page at `path` has rendered its heading.
async function navigate(page: Page, link: Locator, path: string) {
  await link.scrollIntoViewIfNeeded()
  await link.hover()
  if (DWELL > 0) await page.waitForTimeout(DWELL)
  const before = await page.locator('h1').first().textContent()
  await page.evaluate(() =>
    document.addEventListener('click', () => Object.assign(window, { clickedAt: performance.now() }), {
      capture: true,
      once: true,
    }),
  )
  await link.click()
  const handle = await page.waitForFunction(
    ([target, previous]) => {
      const heading = document.querySelector('h1')?.textContent
      if (location.pathname !== target || !heading || heading === previous) return false
      return performance.now() - (window as unknown as { clickedAt: number }).clickedAt
    },
    [path, before] as const,
    { polling: 'raf' },
  )
  return (await handle.jsonValue()) as number
}

function report(name: string, times: number[], commit: string) {
  const sorted = [...times].sort((a, b) => a - b)
  const at = (q: number) => sorted[Math.min(sorted.length - 1, Math.ceil(q * sorted.length) - 1)]
  const mean = sorted.reduce((sum, t) => sum + t, 0) / sorted.length
  const line = `[nav] ${name} dwell=${DWELL} n=${sorted.length} p50=${at(0.5).toFixed(0)} p95=${at(0.95).toFixed(0)} mean=${mean.toFixed(0)} build=${commit}`
  console.log(line)
  test.info().annotations.push({ type: 'nav', description: line })
}

async function timeCase(
  page: Page,
  name: string,
  start: string,
  open: (page: Page, run: number) => Promise<[Locator, string]>,
) {
  const times: number[] = []
  let commit = ''
  for (let run = 0; run < RUNS; run++) {
    // A full load each time, so no run reuses what an earlier one fetched
    await page.goto(start)
    await hydrated(page)
    commit ||= await build(page)
    const [link, path] = await open(page, run)
    times.push(await navigate(page, link, path))
  }
  const after = await build(page)
  expect(after, 'the deployed commit changed during the run').toBe(commit)
  report(name, times, commit)
}

// The Resources menu of the header, opened by the pointer, and one of its links.
async function menuLink(page: Page, name: RegExp) {
  await page
    .getByRole('navigation', { name: 'Main' })
    .getByRole('button', { name: /^Resources/ })
    .hover()
  const link = page.getByRole('navigation', { name: 'Main' }).getByRole('link', { name })
  await link.waitFor()
  return link
}

test('card to detail page', async ({ page }) => {
  await timeCase(page, 'card→detail', '/resources/mushaf-layout', async (page, run) => {
    const cards = page.getByTestId('resource-card').getByRole('link')
    const link = cards.nth(run % (await cards.count()))
    return [link, new URL((await link.getAttribute('href'))!, page.url()).pathname]
  })
})

test('home to a type page through the header menu', async ({ page }) => {
  await timeCase(page, 'home→type (mushaf layouts)', '/', async (page) => [
    await menuLink(page, /^Mushaf layouts/),
    '/resources/mushaf-layout',
  ])
})

test('home to the translations type page through the header menu', async ({ page }) => {
  await timeCase(page, 'home→type (translations, searched)', '/', async (page) => [
    await menuLink(page, /^Translations/),
    '/resources/translation',
  ])
})

test('footer link to a docs page', async ({ page }) => {
  await timeCase(page, 'footer→docs', '/resources/mushaf-layout', async (page) => [
    page.getByRole('contentinfo').getByRole('link', { name: 'Getting started' }),
    '/docs/getting-started',
  ])
})

// A browse of the catalog's first page: the pointer rests on each of `cards` cards for `rest`
// ms, then clicks the last. Counts the requests the page makes from the first hover on: the
// prefetches (Purpose: prefetch), the other Inertia visits, and their Rails time (x-runtime).
for (const [cards, rest] of [
  [24, 300],
  [24, 50],
  [6, 300],
] as const) {
  test(`server load: rest ${rest} ms on ${cards} cards of the catalog, click the last`, async ({ page }) => {
    await page.goto('/resources')
    await hydrated(page)
    const commit = await build(page)
    const seen = { prefetch: 0, visit: 0, prefetchMs: 0 }
    page.on('response', async (response) => {
      const headers = response.request().headers()
      if (!headers['x-inertia']) return
      const kind = headers['purpose'] === 'prefetch' ? 'prefetch' : 'visit'
      seen[kind]++
      if (kind === 'prefetch') seen.prefetchMs += Number(response.headers()['x-runtime'] ?? 0) * 1000
    })
    const links = page.getByTestId('resource-card').getByRole('link')
    await expect(links.first()).toBeVisible()
    const total = Math.min(cards, await links.count())
    for (let i = 0; i < total; i++) {
      await links.nth(i).scrollIntoViewIfNeeded()
      await links.nth(i).hover()
      await page.waitForTimeout(rest)
    }
    const path = new URL((await links.nth(total - 1).getAttribute('href'))!, page.url()).pathname
    await links.nth(total - 1).click()
    await page.waitForURL((url) => url.pathname === path)
    await page.waitForLoadState('networkidle')
    const line = `[load] ${cards} cards, rest ${rest} ms: ${seen.prefetch} prefetches (Rails ${seen.prefetchMs.toFixed(0)} ms in all), ${seen.visit} other Inertia requests, build=${commit}`
    console.log(line)
    test.info().annotations.push({ type: 'load', description: line })
  })
}
