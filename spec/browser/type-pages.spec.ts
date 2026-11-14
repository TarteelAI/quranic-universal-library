import type { Page } from '@playwright/test'

import { expect, test } from './support/test'

const TYPES = [
  'recitation',
  'mushaf-layout',
  'quran-script',
  'font',
  'translation',
  'transliteration',
  'tafsir',
  'surah-info',
  'morphology',
  'mutashabihat',
  'similar-ayah',
  'ayah-topics',
  'ayah-theme',
  'quran-metadata',
]

async function pageProps(page: Page) {
  const data = await page.locator('script[data-page="app"]').textContent()
  return JSON.parse(data ?? '{}').props
}

test.describe('type pages', () => {
  test('every type page has one card per published resource (on its first page), each with a title', async ({
    page,
  }, testInfo) => {
    test.skip(testInfo.project.name !== 'desktop', 'one width is enough for the sweep')
    test.setTimeout(120_000)

    for (const type of TYPES) {
      // The catalog search counts the published resources of the type on its own query.
      await page.goto(`/resources?type=${type}`)
      const published: number = (await pageProps(page)).total

      await page.goto(`/resources/${type}`)
      const count = Number(await page.getByRole('heading', { level: 1 }).locator('span').textContent())
      expect(count, type).toBe(published)
      // A type with more than 48 resources shows them 24 to a page (002-11).
      const cards = page.locator('main article')
      await expect(cards, type).toHaveCount(published > 48 ? 24 : published)
      const titles = await cards.locator('h3').allTextContents()
      expect(
        titles.filter((title) => title.trim() === ''),
        type,
      ).toEqual([])
    }
  })

  test('a superseded resource is in the collapsed group and links to its replacement', async ({ page }) => {
    await page.goto('/resources/transliteration')

    await expect(page.getByRole('heading', { level: 2, name: 'Which one should I pick?' })).toBeVisible()
    const older = page.locator('details')
    await expect(older).not.toHaveAttribute('open')
    const superseded = page.getByRole('list', { name: 'Older versions' }).getByRole('article').filter({
      hasText: 'Superseded',
    })
    await expect(superseded).toBeHidden()

    await older.locator('summary').click()
    await expect(superseded).toBeVisible()
    const replacement = superseded.getByRole('link', { name: /^Replaced by / })
    const name = (await replacement.textContent())?.trim()
    const href = await replacement.getAttribute('href')
    expect(href).toMatch(/^\/resources\/transliteration\/[^/]+$/)

    await replacement.click()
    await expect(page).toHaveURL(new RegExp(`${href}$`))
    expect(name).toBeTruthy()
  })

  test('a card opens its detail page with an in-app visit, not a full page load', async ({ page }) => {
    await page.goto('/resources/mushaf-layout')
    // React must have taken over the server-rendered page, or the click is a plain link.
    await page.waitForFunction(() =>
      Object.keys(document.getElementById('app') ?? {}).some((key) => key.startsWith('__reactContainer')),
    )
    // A full page load would reset this marker; an Inertia visit keeps the same document.
    await page.evaluate(() => Object.assign(window, { sameDocument: true }))

    const card = page.getByRole('list', { name: 'Mushaf layouts' }).getByRole('article').first()
    const link = card.getByRole('heading').getByRole('link')
    const href = await link.getAttribute('href')
    const name = (await link.textContent())?.trim() ?? ''
    expect(href).toMatch(/^\/resources\/mushaf-layout\/[^/]+$/)
    await link.click()

    await expect(page).toHaveURL(new RegExp(`${href}$`))
    await expect(page.getByRole('heading', { level: 1 })).toContainText(name)
    expect(await page.evaluate(() => 'sameDocument' in window)).toBe(true)
  })

  test("the header links to the type's format docs", async ({ page }) => {
    await page.goto('/resources/mushaf-layout')

    const docs = page.getByRole('link', { name: 'Mushaf layout format docs' })
    await expect(docs).toHaveAttribute('href', '/docs/resource-mushaf-layouts')
    await docs.click()
    await expect(page).toHaveURL(/\/docs\/resource-mushaf-layouts$/)
  })

  test('a type without status data shows no "Which one should I pick?" block', async ({ page }) => {
    await page.goto('/resources/translation')

    await expect(page.getByRole('heading', { level: 1 })).toContainText('Translations')
    expect((await pageProps(page)).pick).toBeNull()
    await expect(page.getByRole('heading', { name: 'Which one should I pick?' })).toHaveCount(0)
    await expect(page.locator('details')).toHaveCount(0)
  })

  test('the layout comparison table is readable at phone width', async ({ page }, testInfo) => {
    test.skip(testInfo.project.name !== 'phone', 'phone layout')

    await page.goto('/resources/mushaf-layout')

    const table = page.getByRole('table', { name: 'Comparison' })
    await expect(table).toBeVisible()
    const rows = (await pageProps(page)).comparison.rows.length
    await expect(table.locator('tbody tr')).toHaveCount(rows)

    // The page itself never scrolls sideways; the table scrolls inside its own container.
    const overflow = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth)
    expect(overflow).toBeLessThanOrEqual(0)
    const box = await table.evaluate((element) => {
      const container = element.parentElement as HTMLElement
      const before = container.scrollLeft
      container.scrollLeft = container.scrollWidth
      const bounds = container.getBoundingClientRect()
      const name = element.querySelector('tbody tr td') as HTMLElement
      const last = element.querySelector('tbody tr td:last-child') as HTMLElement
      return {
        overflowX: getComputedStyle(container).overflowX,
        scrollable: container.scrollWidth > container.clientWidth,
        moved: container.scrollLeft > before,
        width: bounds.width,
        // Scrolled to the end: the name column is still at the left edge, the last column is in view.
        nameLeft: name.getBoundingClientRect().left - bounds.left,
        lastRight: last.getBoundingClientRect().right - bounds.right,
      }
    })
    expect(box.overflowX).toBe('auto')
    expect(box.width).toBeLessThanOrEqual(390)
    expect(box.moved).toBe(box.scrollable)
    expect(Math.abs(box.nameLeft)).toBeLessThanOrEqual(1)
    expect(box.lastRight).toBeLessThanOrEqual(1)
    // The name cell covers the cells that scroll under it.
    const name = table.locator('tbody tr').first().locator('td').first()
    await expect(name).toHaveCSS('position', 'sticky')
    await name.getByRole('link').click({ trial: true })

    await testInfo.attach('layout-comparison-phone', {
      body: await page.getByRole('region', { name: 'Comparison' }).screenshot(),
      contentType: 'image/png',
    })
  })
})
