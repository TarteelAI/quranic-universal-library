import type { Locator, Page, Request } from '@playwright/test'

import { expect, test } from './support/test'

// The shard renderer's module: the source file under Vite dev, a hashed chunk in a build.
const RENDERER = /\/renderer(-[\w-]+)?\.js(\?|$)/
const isRenderer = (request: Request) => RENDERER.test(new URL(request.url()).pathname)

async function hydrated(page: Page) {
  await page.waitForFunction(() =>
    Object.keys(document.getElementById('app') ?? {}).some((key) => key.startsWith('__reactContainer')),
  )
}

const ring = (page: Page) => page.locator('[data-motion]')
// The dark hero panel the ring sits in.
const hero = (page: Page) => ring(page).locator('..')

// Whether two pictures of the ring's canvas, a second apart, are the same.
async function sameFrameAfterASecond(canvas: Locator) {
  const first = (await canvas.screenshot()).toString('base64')
  await canvas.page().waitForTimeout(1000)
  return (await canvas.screenshot()).toString('base64') === first
}

test.describe('home page', () => {
  test('hydrates without warnings and shows the catalog counts', async ({ page, stubs }) => {
    // The star count comes from GitHub's API, which rate-limits unauthenticated test runs.
    await stubs.route('https://api.github.com/repos/TarteelAI/quranic-universal-library', (route) =>
      route.fulfill({ json: { stargazers_count: 1234 } }),
    )
    const messages: string[] = []
    page.on('pageerror', (error) => messages.push(error.message))
    page.on('console', (message) => {
      if (!['error', 'warning'].includes(message.type())) return
      // GA4's tag (an external script) can fail to load in a test run; it is not the page's.
      if (message.location().url.includes('googletagmanager.com')) return
      // Chromium's GPU driver notes (the renderer reads one pixel back to test Display P3).
      if (message.text().startsWith('[.WebGL-')) return
      messages.push(`${message.type()}: ${message.text()}`)
    })

    await page.goto('/')
    await hydrated(page)
    await expect(ring(page)).toHaveAttribute('data-motion', /running|still/)

    const terms = await page.locator('main dl dt').allTextContents()
    expect(terms).toEqual(['resources', 'languages', 'recitations'])
    const props = JSON.parse((await page.locator('script[data-page="app"]').textContent())!).props
    const values = await page.locator('main dl dd').allTextContents()
    expect(values).toEqual([props.resources, props.languages, props.recitations].map((n) => n.toLocaleString('en')))
    await expect(page.getByText('1,234 stars on GitHub')).toBeVisible()
    expect(messages).toEqual([])
  })

  test('loads the shard renderer only once the hero is on screen', async ({ page }) => {
    // Hold back IntersectionObserver reports until the test releases them.
    await page.addInitScript(() => {
      const held: (() => void)[] = []
      Object.assign(window, { releaseIntersections: () => held.forEach((report) => report()) })
      window.IntersectionObserver = class {
        constructor(private callback: IntersectionObserverCallback) {}
        observe(target: Element) {
          held.push(() =>
            this.callback(
              [{ isIntersecting: true, target } as IntersectionObserverEntry],
              this as unknown as IntersectionObserver,
            ),
          )
        }
        unobserve() {}
        disconnect() {}
        takeRecords() {
          return []
        }
      } as unknown as typeof IntersectionObserver
    })
    const requests: string[] = []
    page.on('request', (request) => {
      if (isRenderer(request)) requests.push(request.url())
    })

    const response = await page.goto('/')
    expect(await response!.text()).not.toMatch(/renderer[-.]/)
    await hydrated(page)
    await page.waitForLoadState('networkidle')
    expect(requests).toEqual([])
    await expect(ring(page)).toHaveAttribute('data-motion', 'pending')

    const loaded = page.waitForRequest(isRenderer)
    await page.evaluate(() => (window as unknown as { releaseIntersections: () => void }).releaseIntersections())
    await loaded
    await expect(ring(page)).toHaveAttribute('data-motion', /running|still/)
  })

  test('animates the ring, and draws one still frame under reduced motion', async ({ page }) => {
    await page.goto('/')
    await expect(ring(page)).toHaveAttribute('data-motion', 'running')
    // Under heavy load a software-rendered frame can take longer than a second.
    await expect.poll(() => sameFrameAfterASecond(ring(page).locator('canvas')), { timeout: 15_000 }).toBe(false)

    await page.emulateMedia({ reducedMotion: 'reduce' })
    await page.goto('/')
    await expect(ring(page)).toHaveAttribute('data-motion', 'still')
    expect(await sameFrameAfterASecond(ring(page).locator('canvas'))).toBe(true)
  })

  test('at 390 px the hero fits the viewport and its heading overlays the ring', async ({ page }, testInfo) => {
    await page.setViewportSize({ width: 390, height: 844 })
    await page.goto('/')
    await expect(ring(page)).toHaveAttribute('data-motion', 'running')

    const heroBox = (await hero(page).boundingBox())!
    const ringBox = (await ring(page).boundingBox())!
    const heading = (await page.getByRole('heading', { level: 1 }).boundingBox())!
    expect(heroBox.height).toBeLessThanOrEqual(844)
    expect(heading.y).toBeLessThan(ringBox.y + ringBox.height)
    expect(heading.y + heading.height).toBeGreaterThan(ringBox.y)
    expect(heading.x).toBeLessThan(ringBox.x + ringBox.width)
    const shot = testInfo.outputPath('hero-390.png')
    await page.screenshot({ path: shot })
    await testInfo.attach('hero-390', { path: shot, contentType: 'image/png' })
  })
})
