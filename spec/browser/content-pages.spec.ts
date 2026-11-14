import type { Page } from '@playwright/test'

import { expect, test } from './support/test'

async function hydrated(page: Page) {
  await page.waitForFunction(() =>
    Object.keys(document.getElementById('app') ?? {}).some((key) => key.startsWith('__reactContainer')),
  )
}

// The page's own width fits the viewport: nothing makes the page scroll sideways.
async function expectNoSidewaysScroll(page: Page) {
  expect(await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth)).toBeLessThanOrEqual(0)
}

test.describe('FAQ, credits and the tools overview', () => {
  test('the FAQ opens a question and the question a link names', async ({ page }) => {
    await page.goto('/faq')
    await hydrated(page)

    await expect(page.getByRole('heading', { level: 1 })).toHaveText('Frequently asked questions')
    const first = page.locator('details').first()
    await expect(first).not.toHaveAttribute('open')
    await first.locator('summary').click()
    await expect(first).toHaveAttribute('open')
    await expect(first.locator('.docs-prose')).toBeVisible()
    await expectNoSidewaysScroll(page)

    const id = await page.locator('details').nth(1).getAttribute('id')
    await page.goto(`/faq#${id}`)
    await expect(page.locator(`#${id}`)).toHaveAttribute('open')
  })

  test('the credits list the organizations and the people thanked', async ({ page }) => {
    await page.goto('/credits')
    await hydrated(page)

    await expect(page.getByRole('heading', { level: 1 })).toHaveText('Credits')
    await expect(page.getByRole('region', { name: 'Organizations' }).getByRole('listitem').first()).toBeVisible()
    await expect(
      page.getByRole('region', { name: 'People and projects' }).getByRole('link', { name: 'Tanzil' }),
    ).toBeVisible()
    await expectNoSidewaysScroll(page)
  })

  test('a tool card opens its old tool page', async ({ page }) => {
    await page.goto('/tools')
    await hydrated(page)

    await expect(page.getByRole('heading', { level: 1 })).toHaveText('Contribution tools')
    const group = page.getByRole('region', { name: 'Translations & tafsir' })
    await expect(group.getByText('Read and fix translations, tafsirs and surah introductions.')).toBeVisible()
    await expectNoSidewaysScroll(page)

    await group.getByRole('link', { name: /Surah info/ }).click()
    await expect(page).toHaveURL(/\/surah_infos/)
    // An old page: the full page loaded, without the Inertia app.
    await expect(page.locator('[data-page="app"]')).toHaveCount(0)
  })
})
