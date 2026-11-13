import type { Page } from '@playwright/test'

import { expect as baseExpect, test } from './support/test'

// Each step waits on a server search; allow for a slow server.
const expect = baseExpect.configure({ timeout: 15_000 })

// React has taken over the server-rendered page, so its handlers respond.
async function hydrated(page: Page) {
  await page.waitForFunction(() =>
    Object.keys(document.getElementById('app') ?? {}).some((key) => key.startsWith('__reactContainer')),
  )
}

const cardNames = (page: Page) => page.locator('main article h3').allTextContents()

test.describe('catalog views and type page search (002-11)', () => {
  test('the catalog groups by category until a sort is chosen', async ({ page }) => {
    await page.goto('/resources')
    await hydrated(page)

    await expect(page.getByRole('combobox', { name: 'Sort' })).toHaveValue('')
    await expect(page.getByRole('heading', { level: 2, name: 'Audio' })).toBeVisible()
    await expect(page.getByRole('list', { name: 'Audio' }).getByRole('article')).toHaveCount(24)

    await page.getByRole('combobox', { name: 'Sort' }).selectOption('name')
    await expect(page).toHaveURL(/\/resources\?sort=name$/)
    await expect(page.getByRole('list', { name: 'Resources' }).getByRole('article')).toHaveCount(24)
    await expect(page.getByRole('heading', { level: 2, name: 'Audio' })).toHaveCount(0)
  })

  test('the list view survives a reload and Back, and a shared URL opens it', async ({ page }) => {
    await page.goto('/resources?type=tafsir')
    await hydrated(page)
    const list = page.getByRole('button', { name: 'List view' })
    const grid = page.getByRole('button', { name: 'Grid view' })
    await expect(grid).toHaveAttribute('aria-pressed', 'true')
    const names = await cardNames(page)

    await list.click()
    await expect(page).toHaveURL(/\/resources\?type=tafsir&view=list$/)
    await expect(list).toHaveAttribute('aria-pressed', 'true')
    await expect(page.locator('main [data-testid="card-preview"]')).toHaveCount(0)
    expect(await cardNames(page)).toEqual(names)

    await page.reload()
    await hydrated(page)
    await expect(list).toHaveAttribute('aria-pressed', 'true')
    await expect(page.locator('main [data-testid="card-preview"]')).toHaveCount(0)
    // Long titles are cut in a list row; no row is wider than the screen. (On a phone a wider page
    // widens the layout viewport too, so compare with the emulated screen.)
    const rights = await page
      .locator('main article')
      .evaluateAll((cards) => cards.map((card) => card.getBoundingClientRect().right))
    expect(Math.max(...rights)).toBeLessThanOrEqual(page.viewportSize()!.width)

    await page.goBack()
    await expect(page).toHaveURL(/\/resources\?type=tafsir$/)
    await expect(grid).toHaveAttribute('aria-pressed', 'true')
    await expect(page.locator('main [data-testid="card-preview"]').first()).toBeAttached()

    await page.goto('/resources?type=tafsir&q=noble&view=list')
    await hydrated(page)
    await expect(list).toHaveAttribute('aria-pressed', 'true')
    await expect(page.getByRole('searchbox', { name: 'Search resources' })).toHaveValue('noble')
    await expect(page.locator('main [data-testid="card-preview"]')).toHaveCount(0)
  })

  test("a type page's query, language and page survive a reload and Back", async ({ page }) => {
    await page.goto('/resources/translation')
    await hydrated(page)
    const search = page.getByRole('searchbox', { name: 'Search translations' })
    const language = page.getByRole('combobox', { name: 'Language' })
    const pages = page.getByRole('navigation', { name: 'Pages' })
    await expect(page.locator('main article')).toHaveCount(24)
    const first = await cardNames(page)

    await pages.getByRole('link', { name: 'Next' }).click()
    await expect(page).toHaveURL(/\/resources\/translation\?page=2$/)
    await expect(pages.getByText('Page 2 of')).toBeVisible()
    const second = await cardNames(page)
    expect(second.filter((name) => first.includes(name))).toEqual([])

    await page.goBack()
    await expect(page).toHaveURL(/\/resources\/translation$/)
    await expect(pages.getByText('Page 1 of')).toBeVisible()
    expect(await cardNames(page)).toEqual(first)

    await language.selectOption('ur')
    await expect(page).toHaveURL(/\/resources\/translation\?language=ur$/)
    await expect(
      page
        .locator('main article p')
        .filter({ hasText: /^Translation · / })
        .first(),
    ).toContainText('Urdu')
    await search.fill('maududi')
    await expect(page).toHaveURL(/\/resources\/translation\?q=maududi&language=ur$/)
    const found = await cardNames(page)
    expect(found.length).toBeGreaterThan(0)
    expect(found.length).toBeLessThan(24)

    await page.reload()
    await hydrated(page)
    await expect(search).toHaveValue('maududi')
    await expect(language).toHaveValue('ur')
    expect(await cardNames(page)).toEqual(found)

    // Typing replaced the language's history entry; Back goes to the page before the language.
    await page.goBack()
    await expect(page).toHaveURL(/\/resources\/translation$/)
    await expect(language).toHaveValue('')
    await expect(search).toHaveValue('')
  })
})
