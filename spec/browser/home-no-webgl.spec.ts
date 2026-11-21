import type { Page, Request } from '@playwright/test'

import { expect, test } from './support/test'

// A browser with WebGL turned off; a launch option, so it needs a file of its own.
test.use({ launchOptions: { args: ['--disable-webgl', '--disable-3d-apis'] } })

const RENDERER = /\/renderer(-[\w-]+)?\.js(\?|$)/
const isRenderer = (request: Request) => RENDERER.test(new URL(request.url()).pathname)
const ring = (page: Page) => page.locator('[data-motion]')

async function hydrated(page: Page) {
  await page.waitForFunction(() =>
    Object.keys(document.getElementById('app') ?? {}).some((key) => key.startsWith('__reactContainer')),
  )
}

test.describe('home page without WebGL', () => {
  test('shows the still image and never loads the renderer', async ({ page }) => {
    const requests: string[] = []
    page.on('request', (request) => {
      if (isRenderer(request)) requests.push(request.url())
    })

    await page.goto('/')
    await hydrated(page)
    await expect(ring(page)).toHaveAttribute('data-motion', 'fallback')
    const image = ring(page).locator('img')
    await expect(image).toHaveAttribute('src', '/shards.webp')
    await expect.poll(() => image.evaluate((img: HTMLImageElement) => img.naturalWidth)).toBeGreaterThan(0)
    await expect(ring(page).locator('canvas')).toHaveCount(0)
    await page.waitForLoadState('networkidle')
    expect(requests).toEqual([])
  })
})
