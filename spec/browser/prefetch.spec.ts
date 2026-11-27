import type { Page, Request } from '@playwright/test'

import { expect, test } from './support/test'

// The Inertia visits the page sends to `path` (not the partial reloads of its deferred props),
// and which of them are prefetches.
function inertiaRequests(page: Page, path: string) {
  const sent: Request[] = []
  page.on('request', (request) => {
    const headers = request.headers()
    if (headers['x-inertia'] && !headers['x-inertia-partial-data'] && new URL(request.url()).pathname === path)
      sent.push(request)
  })
  return {
    prefetches: () => sent.filter((request) => request.headers()['purpose'] === 'prefetch').length,
    all: () => sent.length,
  }
}

// React has taken over the server-rendered page, so its links listen to the pointer.
async function hydrated(page: Page) {
  await page.waitForFunction(() =>
    Object.keys(document.getElementById('app') ?? {}).some((key) => key.startsWith('__reactContainer')),
  )
}

test.describe('prefetch', () => {
  test.skip(({ isMobile }) => isMobile, 'a phone has no hover')

  test('resting on a card fetches its detail page once, and the click shows it without another request', async ({
    page,
  }) => {
    await page.goto('/resources/mushaf-layout')
    await hydrated(page)
    const card = page.getByTestId('resource-card').first().getByRole('link').first()
    const path = new URL((await card.getAttribute('href'))!, page.url()).pathname
    const requests = inertiaRequests(page, path)

    await card.hover()
    await expect.poll(requests.prefetches).toBe(1)
    await page.mouse.move(0, 0)
    await card.hover()
    await page.waitForTimeout(300)
    expect(requests.all()).toBe(1)

    await card.click()
    await page.waitForURL((url) => url.pathname === path)
    await expect(page.getByRole('heading', { level: 1 })).toBeVisible()
    await expect(page.getByRole('navigation', { name: 'Main' })).toBeVisible()
    expect(requests.all()).toBe(1)
  })

  test('a header menu link and a footer link are fetched ahead; the catalog is not', async ({ page }) => {
    await page.goto('/')
    await hydrated(page)
    const types = inertiaRequests(page, '/resources/mushaf-layout')
    const catalog = inertiaRequests(page, '/resources')
    const docs = inertiaRequests(page, '/docs/getting-started')

    await page
      .getByRole('navigation', { name: 'Main' })
      .getByRole('button', { name: /^Resources/ })
      .hover()
    const menu = page.getByRole('navigation', { name: 'Main' })
    await menu.getByRole('link', { name: /^Mushaf layouts/ }).hover()
    await expect.poll(types.prefetches).toBe(1)
    // The panel stays open: a prefetch is not a visit
    await menu.getByRole('link', { name: /^Browse all resources/ }).hover()

    const footer = page.getByRole('contentinfo')
    await footer.getByRole('link', { name: 'All resources' }).hover()
    await footer.getByRole('link', { name: 'Getting started' }).hover()
    await expect.poll(docs.prefetches).toBe(1)
    await page.waitForTimeout(300)
    expect(catalog.all()).toBe(0)

    await footer.getByRole('link', { name: 'Getting started' }).click()
    await page.waitForURL('**/docs/getting-started')
    await expect(page.getByRole('heading', { level: 1 })).toBeVisible()
    expect(docs.all()).toBe(1)
  })

  test('a page fetched ahead while signed in is not shown after sign-out', async ({ page }) => {
    await page.goto('/users/sign_in?user_return_to=%2Fresources%2Fmushaf-layout')
    await page.locator('#user_email').fill('reader@example.test')
    await page.locator('#user_password').fill('fake-account-password')
    await page.getByRole('button', { name: 'Sign in' }).click()
    await expect(page).toHaveURL(/\/resources\/mushaf-layout$/)
    await hydrated(page)
    const card = page.getByTestId('resource-card').first().getByRole('link').first()
    const path = new URL((await card.getAttribute('href'))!, page.url()).pathname
    const requests = inertiaRequests(page, path)
    await card.hover()
    await expect.poll(requests.prefetches).toBe(1)

    // Sign-out is a form post that loads the next page in full, so nothing kept survives it
    const header = page.getByRole('banner')
    await header.getByRole('button', { name: /^Account menu/ }).click()
    await page.getByRole('menuitem', { name: 'Sign out' }).click()
    await expect(header.getByRole('link', { name: 'Sign in' })).toBeVisible()
    await page.goto('/resources/mushaf-layout')
    await hydrated(page)
    await page.getByTestId('resource-card').first().getByRole('link').first().click()
    await page.waitForURL((url) => url.pathname === path)
    await expect(header.getByRole('link', { name: 'Sign in' })).toBeVisible()
    expect(requests.all() - requests.prefetches()).toBe(1)
  })
})
