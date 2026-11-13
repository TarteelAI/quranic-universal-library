import type { Page } from '@playwright/test'

import { expect, test } from './support/test'

async function isInertiaPage(page: Page) {
  return (await page.locator('script[data-page="app"]').count()) === 1
}

test.describe('type pages', () => {
  test('a type page shows the type and one card per resource, without sideways scrolling', async ({ page }) => {
    await page.goto('/resources/translation')

    const heading = page.getByRole('heading', { level: 1 })
    await expect(heading).toContainText('Translations')
    const count = Number(await heading.locator('span').textContent())
    expect(count).toBeGreaterThan(0)
    await expect(page.getByRole('list', { name: 'Translations' }).getByRole('article')).toHaveCount(count)
    await expect(page.locator('#app[data-server-rendered="true"]')).toHaveCount(1)

    const overflow = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth)
    expect(overflow).toBeLessThanOrEqual(0)
  })

  test('a new page links out to an old page, and the old page links back in', async ({ page }) => {
    await page.goto('/resources/tafsir')
    expect(await isInertiaPage(page)).toBe(true)

    await page.getByRole('list', { name: 'Tafsirs' }).getByRole('link').first().click()
    await expect(page).toHaveURL(/\/resources\/tafsir\/[^/]+$/)
    // The card link is a full page load: the URL changes before the new document has loaded.
    await page.waitForLoadState()
    expect(await isInertiaPage(page)).toBe(true)

    // The resource guide is a new docs page while the content group is on.
    await page.goto(`${new URL(page.url()).pathname}?tab=data`)
    await page.getByRole('link', { name: 'the tafsir guide' }).click()
    await expect(page).toHaveURL(/\/docs\/resource-tafsirs$/)
    await page.waitForLoadState()
    expect(await isInertiaPage(page)).toBe(true)

    // Sign-in stays an old page. At phone width its link is in the closed menu.
    await page.locator('a[href^="/users/sign_in"]').first().dispatchEvent('click')
    await expect(page).toHaveURL(/\/users\/sign_in/)
    await page.waitForLoadState()
    expect(await isInertiaPage(page)).toBe(false)
    // The old page's own bundle (Turbo) loads and runs there.
    await page.waitForFunction(() => 'Turbo' in window)

    await page.locator('a[href="/resources"]').first().dispatchEvent('click')
    await expect(page).toHaveURL(/\/resources$/)
    await expect(page.getByRole('heading', { level: 1 })).toContainText('Resources')
    expect(await isInertiaPage(page)).toBe(true)
  })

  test('sends one GA4 page view on the first load and one after an Inertia visit', async ({
    page,
    analytics: views,
  }) => {
    await page.goto('/resources/translation')
    await expect.poll(() => views.length, { timeout: 15_000 }).toBe(1)
    expect(views[0].title).toBe('Translations - QUL')

    await page.evaluate(() => Object.assign(window, { sameDocument: true }))
    await page.getByRole('navigation', { name: 'Other resource types' }).getByRole('link', { name: 'Tafsirs' }).click()
    await expect(page).toHaveURL(/\/resources\/tafsir$/)
    await expect(page.getByRole('heading', { level: 1 })).toContainText('Tafsirs')
    expect(await page.evaluate(() => 'sameDocument' in window)).toBe(true)

    await expect.poll(() => views.length, { timeout: 15_000 }).toBe(2)
    expect(views[1]).toEqual({ location: expect.stringMatching(/\/resources\/tafsir$/), title: 'Tafsirs - QUL' })

    // No late duplicate of either view.
    await page.waitForTimeout(1500)
    expect(views).toHaveLength(2)
  })

  test('an unknown type is a 404 with the error page', async ({ page }) => {
    const response = await page.goto('/resources/no-such-type')

    expect(response?.status()).toBe(404)
    await expect(page.getByRole('heading', { level: 1, name: 'Page not found' })).toBeVisible()
    expect(await isInertiaPage(page)).toBe(true)
  })
})
