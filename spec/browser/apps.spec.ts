import type { Page } from '@playwright/test'
import { readFileSync } from 'node:fs'

import { expect, test } from './support/test'

const TEMPLATE = '.github/ISSUE_TEMPLATE/app_submission.yml'

async function hydrated(page: Page) {
  await page.waitForFunction(() =>
    Object.keys(document.getElementById('app') ?? {}).some((key) => key.startsWith('__reactContainer')),
  )
}

const apps = (page: Page) => page.getByRole('list', { name: 'Apps' }).locator('> li')
const chip = (page: Page, group: string, name: string) =>
  page.getByRole('group', { name: group }).getByRole('button', { name, exact: true })

// The ids of config/apps.yml, read without a YAML parser: each entry starts with `- id:`.
function dataFileIds() {
  return [...readFileSync('config/apps.yml', 'utf8').matchAll(/^ {2}- id: (\S+)$/gm)].map((match) => match[1])
}

test.describe('apps directory', () => {
  test('lists every app of the data file, featured first', async ({ page }) => {
    await page.goto('/apps')

    const ids = dataFileIds()
    expect(ids.length).toBeGreaterThan(20)
    await expect(apps(page)).toHaveCount(ids.length)
    await expect(page.getByRole('heading', { level: 1 })).toContainText(String(ids.length))
  })

  test('platform and resource type filters narrow the list and are in the URL', async ({ page }) => {
    await page.goto('/apps')
    await hydrated(page)
    const all = await apps(page).count()

    await chip(page, 'Platform', 'Android').click()
    await expect(page).toHaveURL(/\/apps\?platform=android$/)
    await expect(chip(page, 'Platform', 'Android')).toHaveAttribute('aria-pressed', 'true')
    const android = await apps(page).count()
    expect(android).toBeLessThan(all)
    for (const row of await apps(page).all()) await expect(row).toContainText('Android')

    await chip(page, 'Uses', 'Mushaf layout').click()
    await expect(page).toHaveURL(/\/apps\?platform=android&type=mushaf-layout$/)
    await expect.poll(() => apps(page).count()).toBeLessThan(android)
    for (const row of await apps(page).all())
      await expect(row.getByRole('link', { name: 'Mushaf layout', exact: true })).toBeVisible()

    // The URL alone gives the same view.
    const count = await apps(page).count()
    await page.goto('/apps?platform=android&type=mushaf-layout')
    await expect(apps(page)).toHaveCount(count)
    await expect(chip(page, 'Uses', 'Mushaf layout')).toHaveAttribute('aria-pressed', 'true')
  })

  test("each resource type chip links to that type's page", async ({ page }) => {
    await page.goto('/apps')
    await hydrated(page)

    const chips = page.getByRole('list', { name: /^QUL resources .* uses$/ }).getByRole('link')
    const hrefs = new Set(await chips.evaluateAll((links) => links.map((link) => link.getAttribute('href'))))
    expect(hrefs.size).toBeGreaterThan(5)
    for (const href of hrefs) expect(href).toMatch(/^\/resources\/[a-z-]+$/)

    const link = page
      .getByRole('list', { name: 'QUL resources Nimaz uses' })
      .getByRole('link', { name: 'Mushaf layout' })
    await link.click()
    await expect(page).toHaveURL(/\/resources\/mushaf-layout$/)
    await expect(page.getByRole('heading', { level: 1 })).toContainText('Mushaf layouts')
  })

  test('the submit control opens the app submission issue form', async ({ page }) => {
    // The form exists in the repo, so GitHub serves it at that URL.
    expect(readFileSync(TEMPLATE, 'utf8')).toMatch(/^name: "Submit your app"$/m)
    await page.goto('/apps')

    const submit = page.getByRole('main').getByRole('link', { name: 'Submit your app' }).first()
    await expect(submit).toHaveAttribute(
      'href',
      'https://github.com/TarteelAI/quranic-universal-library/issues/new?template=app_submission.yml',
    )
    await expect(submit).toHaveAttribute('target', '_blank')
  })
})
