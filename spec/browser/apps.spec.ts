import type { Page } from '@playwright/test'
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
})

// The submission form writes unpublished rows to the development clone: one per passing test.
test.describe('app submission form', () => {
  const READER = { email: 'reader@example.test', password: 'fake-account-password' }
  const ICON = 'public/app-icons/bayaan.png'
  const form = (page: Page) => page.getByRole('dialog', { name: 'Submit your app' })

  async function signIn(page: Page) {
    await page.locator('#user_email').fill(READER.email)
    await page.locator('#user_password').fill(READER.password)
    await page.getByRole('button', { name: 'Sign in' }).click()
    await expect(page).toHaveURL(/\/apps\?submit=1$/)
    await hydrated(page)
  }

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
    await form(page).getByLabel('App name', { exact: true }).fill(`Browser spec app ${Date.now()}`)
    await form(page).getByLabel('Link', { exact: true }).fill('https://example.test/browser-spec-app')
    await chip(page, 'Platforms', 'iOS').click()
    await chip(page, 'Which QUL resources does it use?', 'Translation').click()
    await form(page).getByLabel('Icon (optional)', { exact: true }).setInputFiles(ICON)
    await form(page).getByLabel('Contact email', { exact: true }).fill('maker@example.test')
    await form(page).getByRole('checkbox').click()
    await form(page).getByRole('button', { name: 'Submit app' }).click()

    await expect(page.getByRole('dialog', { name: 'Thanks, we have your app' })).toBeVisible()
    await expect(page).toHaveURL(/\/apps$/)
  })

  test('bad input shows the server errors beside the fields and keeps the other fields', async ({ page }) => {
    await page.goto('/users/sign_in?user_return_to=%2Fapps%3Fsubmit%3D1')
    await signIn(page)

    const name = `Browser spec app ${Date.now()}`
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
