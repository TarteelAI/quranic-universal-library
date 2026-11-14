import type { Browser, Page } from '@playwright/test'
import { readFileSync } from 'node:fs'

import { expect, test } from './support/test'

async function hydrated(page: Page) {
  await page.waitForFunction(() =>
    Object.keys(document.getElementById('app') ?? {}).some((key) => key.startsWith('__reactContainer')),
  )
}

const apps = (page: Page) => page.getByRole('list', { name: 'Apps' }).locator('> li')
const chip = (page: Page, group: string, name: string) =>
  page.getByRole('group', { name: group }).getByRole('button', { name, exact: true })

// The ids of config/apps.yml, read without a YAML parser: each entry starts with `- id:`. The
// development clone holds them as published apps once `bin/rails apps:import` has run.
function dataFileIds() {
  return [...readFileSync('config/apps.yml', 'utf8').matchAll(/^ {2}- id: (\S+)$/gm)].map((match) => match[1])
}

test.describe('apps directory', () => {
  test('lists the published apps, the imported entries of the data file', async ({ page }) => {
    await page.goto('/apps')

    const ids = dataFileIds()
    expect(ids.length).toBeGreaterThan(20)
    await expect(apps(page)).toHaveCount(ids.length)
    await expect(page.getByRole('heading', { level: 1 })).toContainText(String(ids.length))
  })

  test("the home page's apps band shows stored icons, and its Submit your app opens the form", async ({ page }) => {
    await page.goto('/')
    await hydrated(page)

    const band = page.getByRole('link', { name: /QuranWBW/ }).locator('xpath=ancestor::ul[1]')
    await expect(band.locator('> li')).toHaveCount(8)
    const icon = band.locator('img').first()
    await icon.scrollIntoViewIfNeeded()
    await expect.poll(() => icon.evaluate((img: HTMLImageElement) => img.naturalWidth)).toBeGreaterThan(0)
    expect(await icon.getAttribute('src')).toMatch(/^\/rails\/active_storage\/blobs\/redirect\//)

    await page.getByRole('main').getByRole('link', { name: 'Submit your app' }).click()
    await expect(page).toHaveURL(/\/apps\?submit=1$/)
    await expect(page.getByRole('dialog', { name: 'Submit your app' })).toBeVisible()
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
})

// The submission form writes unpublished rows to the development clone: one per passing test.
// The reader can send 3 apps a day (App::DAILY_LIMIT), so before each test the admin account
// removes the apps earlier runs sent, in the CMS. Serial, so one width sends at most one at a time.
test.describe('app submission form', () => {
  test.describe.configure({ mode: 'serial' })

  const PASSWORD = 'fake-account-password'
  const READER = 'reader@example.test'
  const ADMIN = 'admin@example.test'
  const NAME = 'Browser spec app'
  const ICON = 'public/app-icons/bayaan.png'
  const form = (page: Page) => page.getByRole('dialog', { name: 'Submit your app' })

  async function fillSignIn(page: Page, email: string) {
    await page.locator('#user_email').fill(email)
    await page.locator('#user_password').fill(PASSWORD)
    await page.getByRole('button', { name: 'Sign in' }).click()
  }

  async function signIn(page: Page) {
    await fillSignIn(page, READER)
    await expect(page).toHaveURL(/\/apps\?submit=1$/)
    await hydrated(page)
  }

  async function removeSentApps(browser: Browser, baseURL: string) {
    const context = await browser.newContext({ baseURL })
    const page = await context.newPage()
    await page.goto('/users/sign_in?user_return_to=%2Fcms%2Fapps')
    await fillSignIn(page, ADMIN)
    await expect(page).toHaveURL(/\/cms\/apps$/)
    const token = await page.locator('meta[name="csrf-token"]').getAttribute('content')

    // The rows are in the HTML; the CMS page's images and scripts are not needed.
    const sentApps = async () => {
      await page.goto(`/cms/apps?q[name_start]=${encodeURIComponent(NAME)}`, { waitUntil: 'domcontentloaded' })
      return page.locator('tr[id^="app_"]').evaluateAll((rows) => rows.map((row) => row.id.replace('app_', '')))
    }
    // Locally a removal answers 500 once the row is gone: an app with an icon enqueues
    // ActiveStorage::PurgeJob, and the development server has no Redis. The list says what is left.
    for (const id of await sentApps())
      await context.request.delete(`/cms/apps/${id}`, { headers: { 'X-CSRF-Token': token ?? '' }, maxRedirects: 0 })
    expect(await sentApps()).toEqual([])
    await context.close()
  }

  test.beforeEach(async ({ browser, baseURL }) => {
    // Signing in to the CMS and removing apps, on top of the test.
    test.setTimeout(90_000)
    await removeSentApps(browser, baseURL!)
  })

  test('a signed-out visitor sees it disabled, signs in, comes back to it and submits with an icon', async ({
    page,
  }) => {
    await page.goto('/apps')
    await hydrated(page)
    await page.getByRole('main').getByRole('button', { name: 'Submit your app' }).first().click()

    for (const field of ['App name', 'Link', 'Icon (optional)', 'Contact email'])
      await expect(form(page).getByLabel(field, { exact: true })).toBeDisabled()
    await expect(form(page).getByRole('button', { name: 'iOS' })).toBeDisabled()
    await expect(form(page).getByRole('button', { name: 'Submit app' })).toBeDisabled()
    await form(page).getByRole('link', { name: 'Sign in' }).click()
    await expect(page).toHaveURL(/\/users\/sign_in\?user_return_to=%2Fapps%3Fsubmit%3D1$/)
    await signIn(page)

    await expect(form(page).getByRole('link', { name: 'Sign in' })).toHaveCount(0)
    const name = `${NAME} ${Date.now()}`
    await form(page).getByLabel('App name', { exact: true }).fill(name)
    await form(page).getByLabel('Link', { exact: true }).fill('https://example.test/browser-spec-app')
    await chip(page, 'Platforms', 'iOS').click()
    await chip(page, 'Which QUL resources does it use?', 'Translation').click()
    await form(page).getByLabel('Icon (optional)', { exact: true }).setInputFiles(ICON)
    await form(page).getByLabel('Contact email', { exact: true }).fill('maker@example.test')
    await form(page).getByRole('checkbox').click()
    await form(page).getByRole('button', { name: 'Submit app' }).click()

    await expect(page.getByRole('dialog', { name: 'Thanks, we have your app' })).toBeVisible()
    await expect(page).toHaveURL(/\/apps$/)

    // Unpublished until an editor approves it.
    await page.getByRole('button', { name: 'Done' }).click()
    await expect(apps(page)).toHaveCount(dataFileIds().length)
    await expect(page.getByRole('main')).not.toContainText(name)
  })

  test('bad input shows the server errors beside the fields and keeps the other fields', async ({ page }) => {
    await page.goto('/users/sign_in?user_return_to=%2Fapps%3Fsubmit%3D1')
    await signIn(page)

    const name = `${NAME} ${Date.now()}`
    await form(page).getByLabel('App name', { exact: true }).fill(name)
    await form(page).getByLabel('Link', { exact: true }).fill('https://example.test/browser-spec-app')
    await form(page).getByLabel('Contact email', { exact: true }).fill('maker@example.test')
    await form(page)
      .getByLabel('Icon (optional)', { exact: true })
      .setInputFiles({ name: 'icon.png', mimeType: 'image/png', buffer: Buffer.from('not an image') })
    await form(page).getByRole('button', { name: 'Submit app' }).click()

    await expect(form(page).getByText('Platforms must include at least one platform')).toBeVisible()
    await expect(form(page).getByText('Resources used must include at least one resource type')).toBeVisible()
    await expect(form(page).getByText('Consent must be given to list the app')).toBeVisible()
    await expect(form(page).getByText('Icon must be a PNG, JPEG or WebP image')).toBeVisible()
    await expect(form(page).getByLabel('App name', { exact: true })).toHaveValue(name)
    await expect(form(page).getByLabel('Link', { exact: true })).toHaveValue('https://example.test/browser-spec-app')
    await expect(form(page).getByLabel('Contact email', { exact: true })).toHaveValue('maker@example.test')

    await chip(page, 'Platforms', 'Web').click()
    await chip(page, 'Which QUL resources does it use?', 'Mushaf layout').click()
    await form(page).getByLabel('Icon (optional)', { exact: true }).setInputFiles(ICON)
    await form(page).getByRole('checkbox').click()
    await form(page).getByRole('button', { name: 'Submit app' }).click()
    await expect(page.getByRole('dialog', { name: 'Thanks, we have your app' })).toBeVisible()
  })
})
