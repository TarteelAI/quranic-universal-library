import type { Page } from '@playwright/test'

import { expect, test } from './support/test'

// The changelog (/changelog, /changelog/:id) on the development clone, with the `catalog` and
// `content` page groups on: paging through the list, and an entry opened from a resource's
// Changelog tab.

async function hydrated(page: Page) {
  await page.waitForFunction(() =>
    Object.keys(document.getElementById('app') ?? {}).some((key) => key.startsWith('__reactContainer')),
  )
}

const entries = (page: Page) => page.getByRole('list', { name: 'Changelog' }).getByRole('listitem')

test('the changelog pages through its entries, older and newer', async ({ page }) => {
  await page.goto('/changelog')
  await hydrated(page)

  await expect(page.getByRole('heading', { level: 1 })).toHaveText('Changelog')
  const pager = page.getByRole('navigation', { name: 'Pages' })
  const total = Number((await pager.getByText(/^Page 1 of \d+$/).textContent())!.match(/\d+$/)![0])
  expect(total).toBeGreaterThan(1)
  const firstTitle = await entries(page).first().getByRole('link').first().textContent()

  await pager.getByRole('link', { name: /Older/ }).click()
  await expect(page).toHaveURL(/\/changelog\?page=2$/)
  await expect(pager.getByText(`Page 2 of ${total}`)).toBeVisible()
  await expect(entries(page).first().getByRole('link').first()).not.toHaveText(firstTitle!)

  await pager.getByRole('link', { name: /Newer/ }).click()
  await expect(page).toHaveURL(/\/changelog$/)
  await expect(entries(page).first().getByRole('link').first()).toHaveText(firstTitle!)
  expect(await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth)).toBeLessThanOrEqual(0)
})

test("an entry opens from its resource's Changelog tab and links back", async ({ page }) => {
  await page.goto('/changelog')
  const entry = entries(page)
    .filter({ has: page.getByRole('link', { name: /./ }).and(page.locator('a[href^="/resources/"]')) })
    .first()
  const title = (await entry.getByRole('link').first().textContent())!
  const resourcePath = (await entry.locator('a[href^="/resources/"]').getAttribute('href'))!

  await page.goto(resourcePath)
  await hydrated(page)
  await page.getByRole('tab', { name: 'Changelog' }).click()
  await page.getByRole('list', { name: 'Changelog' }).getByRole('link', { name: title, exact: true }).click()

  await expect(page).toHaveURL(/\/changelog\/\d+$/)
  await expect(page.getByRole('heading', { level: 1 })).toHaveText(title)
  await expect(page.locator('article.docs-prose')).not.toBeEmpty()
  await expect(page.getByRole('main').locator(`a[href="${resourcePath}"]`)).toBeVisible()
  await expect(
    page.getByRole('navigation', { name: 'Breadcrumb' }).getByRole('link', { name: 'Changelog' }),
  ).toHaveAttribute('href', '/changelog')
})
