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
  test('every type page has one card per published resource, each with a title', async ({ page }, testInfo) => {
    test.skip(testInfo.project.name !== 'desktop', 'one width is enough for the sweep')
    test.setTimeout(120_000)

    for (const type of TYPES) {
      // The catalog search counts the published resources of the type on its own query.
      await page.goto(`/resources?type=${type}`)
      const published: number = (await pageProps(page)).total

      await page.goto(`/resources/${type}`)
      const count = Number(await page.getByRole('heading', { level: 1 }).locator('span').textContent())
      expect(count, type).toBe(published)
      const cards = page.locator('main article')
      await expect(cards, type).toHaveCount(published)
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
      return {
        overflowX: getComputedStyle(container).overflowX,
        scrollable: container.scrollWidth > container.clientWidth,
        moved: container.scrollLeft > before,
        width: container.getBoundingClientRect().width,
      }
    })
    expect(box.overflowX).toBe('auto')
    expect(box.width).toBeLessThanOrEqual(390)
    expect(box.moved).toBe(box.scrollable)

    await testInfo.attach('layout-comparison-phone', {
      body: await page.getByRole('region', { name: 'Comparison' }).screenshot(),
      contentType: 'image/png',
    })
  })
})
