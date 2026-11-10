import { execSync } from 'node:child_process'
import { randomUUID } from 'node:crypto'
import { mkdirSync, rmSync, writeFileSync } from 'node:fs'

import type { Page, Request } from '@playwright/test'
import * as fontkit from 'fontkit'

import { expect, test } from './support/test'

// The Preview tab of mushaf layouts, fonts and Quran scripts on the development clone: a sweep
// over every published one, page navigation that reloads only the preview prop and loads only
// the shown page's fonts, and the font Ligatures and Glyphs views.
//
// The resources come from the database through `bin/rails runner`; QUL_BROWSER_RAILS_RUNNER
// replaces that command (for example `docker exec qul-dev bin/rails runner`). The sweeps print a
// result table and run at desktop width only.

const RUNNER = process.env.QUL_BROWSER_RAILS_RUNNER ?? 'bin/rails runner'

function rails<T>(code: string): T {
  mkdirSync('tmp/playwright', { recursive: true })
  const script = `tmp/playwright/runner-${randomUUID()}.rb`
  writeFileSync(script, code)
  try {
    const out = execSync(`${RUNNER} ${script}`, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] })
    return JSON.parse(out.trim().split('\n').at(-1)!) as T
  } finally {
    rmSync(script, { force: true })
  }
}

type Row = { id: number; name: string; path: string }
type Fixtures = {
  layouts: (Row & { pages: number | null })[]
  fonts: (Row & { ligatures: number })[]
  scripts: Row[]
}

let fixtures: Fixtures

test.beforeAll(() => {
  test.setTimeout(120_000)
  fixtures = rails<Fixtures>(`
    rows = ->(type) { DownloadableResource.published.where(resource_type: type).order(:id).preload(:resource_content) }
    row = ->(r) { { id: r.id, name: r.name.strip, path: "/resources/#{r.resource_type}/#{r.to_param}" } }
    puts({
      layouts: rows.('mushaf-layout').map { |r| row.(r).merge(pages: MushafLayouts::Page.mushaf_for(r)&.pages_count) },
      fonts: rows.('font').map { |r| row.(r).merge(ligatures: JSON.parse(r.resource_content.meta_value('ligatures') || '{}').size) },
      scripts: rows.('quran-script').map(&row)
    }.to_json)
  `)
})

const FONT_FILE = /\/qul\/fonts\//

// Waits for the deferred preview, then for its font to load or fail.
async function settled(page: Page, selector: string) {
  await page.locator(`${selector}, [data-testid="no-preview"]`).first().waitFor({ timeout: 30_000 })
  if (await page.getByTestId('no-preview').isVisible()) return null
  const target = page.locator(selector).first()
  await expect(target).not.toHaveAttribute('data-font-status', 'loading', { timeout: 30_000 })
  return target
}

// document.fonts.check for every element that names its own font, in the page.
async function fontsCheck(page: Page, root: string) {
  return page.evaluate((root) => {
    const elements = Array.from(document.querySelectorAll<HTMLElement>(`${root}, ${root} [style*="font-family"]`))
    const named = elements.filter((element) => element.style.fontFamily && element.textContent?.trim())
    const failed = named.filter(
      (element) => !document.fonts.check(`30px ${element.style.fontFamily}`, element.textContent!.trim()),
    )
    const families = [...new Set(named.map((element) => element.style.fontFamily))]
    return { checked: named.length, families, failed: failed.map((element) => element.style.fontFamily) }
  }, root)
}

function table(title: string, rows: string[]) {
  console.log(`\n[${title}]\n${rows.join('\n')}`)
}

test.describe('sweeps', () => {
  test.skip(({ isMobile }) => isMobile, 'The sweeps run at desktop width.')
  test.setTimeout(600_000)

  test('every published layout draws page 1, a middle page and the last page, or says why not', async ({ page }) => {
    const rows: string[] = []
    for (const layout of fixtures.layouts) {
      const pages = layout.pages ? [1, Math.ceil(layout.pages / 2), layout.pages] : [1]
      const results: string[] = []
      for (const number of pages) {
        await page.goto(`${layout.path}?page=${number}`)
        const shown = await settled(page, '[data-testid="mushaf-page"]')
        if (!shown) {
          results.push(`no preview (${await page.getByTestId('no-preview').locator('p').last().textContent()})`)
          continue
        }
        await expect(page.getByTestId('mushaf-preview')).toHaveAttribute('data-page', String(number))
        const status = await shown.getAttribute('data-font-status')
        const check = await fontsCheck(page, '[data-testid="mushaf-page"]')
        const lines = await shown.locator('[data-line]').count()
        expect(status, `${layout.name} p${number}`).toBe('loaded')
        expect(check.failed, `${layout.name} p${number}`).toEqual([])
        results.push(`p${number}: ${lines} lines, font ${status}`)
      }
      rows.push(`${layout.id} ${layout.name} | ${results.join(' | ')}`)
    }
    table('layout sweep', rows)
    // The SVG layout has no font: it shows the explicit state, and is the only one that does.
    expect(rows.filter((row) => row.includes('no preview'))).toEqual([expect.stringContaining('SVG Mushaf')])
  })

  test('every published font shows its sample in the font once loaded, or why it cannot', async ({ page }) => {
    const rows: string[] = []
    for (const font of fixtures.fonts) {
      await page.goto(font.path)
      await page.getByTestId('font-preview').waitFor({ timeout: 30_000 })
      const pageFont = await page.getByTestId('mushaf-page').isVisible()
      const selector = pageFont ? '[data-testid="mushaf-page"]' : '[data-testid="font-sample"]'
      const shown = (await settled(page, selector))!
      const status = await shown.getAttribute('data-font-status')
      const family = await page.getByTestId('font-preview').getAttribute('data-family')
      if (status === 'loaded') {
        const check = await fontsCheck(page, selector)
        expect(check.failed, font.name).toEqual([])
        rows.push(`${font.id} ${font.name} | ${family} | ${pageFont ? 'mushaf page' : 'sample'} loaded`)
      } else {
        await expect(page.getByText(`The font ${family} could not be loaded`)).toBeVisible()
        rows.push(`${font.id} ${font.name} | ${family} | could not be loaded: explicit state shown`)
      }
    }
    table('font sweep', rows)
  })

  test('every published Quran script shows a surah in its font, word by word or ayah by ayah', async ({ page }) => {
    const rows: string[] = []
    for (const script of fixtures.scripts) {
      await page.goto(`${script.path}?surah=112`)
      const shown = await settled(page, '[data-testid="script-text"]')
      expect(shown, script.name).not.toBeNull()
      await expect(page.getByTestId('script-preview')).toHaveAttribute('data-surah', '112')
      const preview = page.getByTestId('script-preview')
      const granularity = await preview.getAttribute('data-granularity')
      const rendering = await preview.getAttribute('data-rendering')
      const ayahs = await page.locator('[data-ayah]').count()
      let result: string
      if (rendering === 'image') {
        const images = await page.evaluate(async () => {
          const all = Array.from(document.querySelectorAll<HTMLImageElement>('[data-testid="script-text"] img'))
          await Promise.all(all.map((image) => image.decode().catch(() => undefined)))
          return { total: all.length, loaded: all.filter((image) => image.naturalWidth > 0).length }
        })
        expect(images.loaded, script.name).toBe(images.total)
        result = `${images.loaded}/${images.total} word images loaded`
      } else {
        expect(await shown!.getAttribute('data-font-status'), script.name).toBe('loaded')
        const check = await fontsCheck(page, '[data-testid="script-text"]')
        expect(check.failed, script.name).toEqual([])
        result = `${check.checked} runs in ${check.families.join(', ')}`
      }
      expect(ayahs, script.name).toBe(4)
      rows.push(`${script.id} ${script.name} | ${granularity} | ${rendering} | ${result}`)
    }
    table('script sweep', rows)
  })
})

test('page navigation changes the URL, reloads only the preview and loads only the new page fonts', async ({
  page,
}) => {
  const layout = fixtures.layouts.find((row) => row.name.startsWith('KFGQPC V2 layout'))!
  const fonts: string[] = []
  const inertia: Request[] = []
  page.on('request', (request) => {
    if (FONT_FILE.test(request.url())) fonts.push(request.url())
    if (request.headers()['x-inertia']) inertia.push(request)
  })

  await page.goto(`${layout.path}?page=2`)
  const shown = (await settled(page, '[data-testid="mushaf-page"]'))!
  await expect(shown).toHaveAttribute('data-font-status', 'loaded')
  expect(fonts.filter((url) => url.includes('quran_fonts/'))).toEqual([
    expect.stringMatching(/quran_fonts\/v2\/woff2\/p2\.woff2$/),
  ])
  expect(inertia.map((request) => request.headers()['x-inertia-partial-data'])).toEqual(['preview'])

  fonts.length = 0
  inertia.length = 0
  await page.getByRole('button', { name: /Next page/ }).click()
  await expect(page).toHaveURL(new RegExp(`${layout.path}\\?page=3$`))
  await expect(page.getByTestId('mushaf-preview')).toHaveAttribute('data-page', '3')
  await expect(page.getByTestId('mushaf-page')).toHaveAttribute('data-font-status', 'loaded')

  expect(inertia).toHaveLength(1)
  expect(inertia[0].url()).toMatch(/\?page=3$/)
  expect(inertia[0].headers()['x-inertia-partial-data']).toBe('preview')
  expect(fonts).toEqual([expect.stringMatching(/quran_fonts\/v2\/woff2\/p3\.woff2$/)])
  // The page's own font rules only: page 2's rule is gone.
  const rules = await page.evaluate(() =>
    Array.from(document.querySelectorAll('style'))
      .map((style) => style.innerHTML)
      .join(),
  )
  expect(rules).toContain("'v2-p3'")
  expect(rules).not.toContain("'v2-p2'")

  await page.getByRole('combobox', { name: 'Surah' }).selectOption('3')
  await expect(page).toHaveURL(/\?page=50$/)
  await expect(page.getByTestId('mushaf-preview')).toHaveAttribute('data-page', '50')

  await page.goBack()
  await expect(page).toHaveURL(/\?page=3$/)
  await expect(page.getByTestId('mushaf-preview')).toHaveAttribute('data-page', '3')
})

test.describe('font ligatures and glyphs', () => {
  // The glyphs the old Glyphs tab listed: every glyph but the reserved names, read with fontkit.
  async function glyphCount(url: string) {
    const font = fontkit.create(new Uint8Array(await (await fetch(url)).arrayBuffer()))
    let count = 0
    for (let id = 0; id < font.numGlyphs; id++) {
      const name = font.getGlyph(id)?.name ?? ''
      if (!['.notdef', '.null', 'nonmarkingreturn', 'NULL', 'CR'].includes(name)) count++
    }
    return count
  }

  test('the old Ligatures tab URL opens the same ligature list', async ({ page }) => {
    const font = fixtures.fonts.find((row) => row.name === 'Surah name fonts v4')!
    await page.goto(`/resources/font/${font.id}/ligatures`)

    await expect(page).toHaveURL(new RegExp(`${font.path}\\?view=ligatures$`))
    await expect(page.getByRole('tab', { name: 'Ligatures' })).toHaveAttribute('aria-selected', 'true')
    await expect(page.getByTestId('ligature-count')).toHaveText(`${font.ligatures} ligatures`)
    await expect(page.locator('[data-ligature]')).toHaveCount(font.ligatures)
  })

  test('the old Glyphs tab URL lists every glyph of the font file', async ({ page }) => {
    for (const name of ['Surah name fonts v4', 'QPC Hafs font']) {
      const font = fixtures.fonts.find((row) => row.name === name)!
      await page.goto(`/resources/font/${font.id}/glyphs`)

      await expect(page).toHaveURL(new RegExp(`${font.path}\\?view=glyphs$`))
      const grid = page.getByTestId('glyph-grid')
      await expect(grid).toHaveAttribute('data-status', 'ready', { timeout: 60_000 })
      const ttf = await page.evaluate(() =>
        Array.from(document.querySelectorAll('style'))
          .map((style) => style.innerHTML.match(/url\('([^']+\.ttf)'\)/)?.[1])
          .find(Boolean),
      )
      expect(await grid.getAttribute('data-count'), name).toBe(String(await glyphCount(ttf!)))
    }
  })

  test('switching views changes the URL without a request', async ({ page }) => {
    const font = fixtures.fonts.find((row) => row.name === 'Surah name fonts v4')!
    await page.goto(font.path)
    await page.getByTestId('font-sample').waitFor()
    const requests: string[] = []
    page.on('request', (request) => request.headers()['x-inertia'] && requests.push(request.url()))

    await page.getByRole('tab', { name: 'Ligatures' }).click()
    await expect(page).toHaveURL(new RegExp(`\\?view=ligatures$`))
    await page.getByRole('tab', { name: 'Sample' }).click()
    await expect(page).toHaveURL(new RegExp(`${font.path}$`))
    expect(requests).toEqual([])
  })
})
