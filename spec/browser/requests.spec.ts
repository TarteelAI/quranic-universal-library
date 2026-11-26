import { execSync } from 'node:child_process'
import { randomUUID } from 'node:crypto'
import { mkdirSync, rmSync, writeFileSync } from 'node:fs'

import type { Locator, Page, TestInfo } from '@playwright/test'

import { expect, test } from './support/test'

// Needs the `requests` page group on the server (QUL_PAGE_GROUPS in playwright.config.ts).
// Writes go through `bin/rails runner`; QUL_BROWSER_RAILS_RUNNER replaces that command (for example
// `docker exec qul-dev bin/rails runner` when Rails runs in Docker).
const RUNNER = process.env.QUL_BROWSER_RAILS_RUNNER ?? 'bin/rails runner'

function rails(code: string) {
  mkdirSync('tmp/playwright', { recursive: true })
  const script = `tmp/playwright/runner-${randomUUID()}.rb`
  writeFileSync(script, code)
  try {
    execSync(`${RUNNER} ${script}`, { stdio: 'ignore' })
  } finally {
    rmSync(script, { force: true })
  }
}

async function hydrated(page: Page) {
  await page.waitForFunction(() =>
    Object.keys(document.getElementById('app') ?? {}).some((key) => key.startsWith('__reactContainer')),
  )
}

const dialog = (page: Page) => page.getByRole('dialog', { name: 'Request a resource' })
const FIELDS = ['What is missing?', 'Language or script (optional)', 'What are you building?']

// The dialog is open and, for a signed-out visitor, wholly disabled under a sign-in link that
// comes back to `returnTo` with the dialog open.
async function expectGated(page: Page, returnTo: string) {
  const form = dialog(page)
  await expect(form).toBeVisible()
  for (const field of FIELDS) await expect(form.getByLabel(field, { exact: true })).toBeDisabled()
  await expect(form.getByRole('button', { name: 'Tafsir', exact: true })).toBeDisabled()
  await expect(form.getByRole('button', { name: 'Send request' })).toBeDisabled()
  await expect(form.getByRole('link', { name: 'Sign in' })).toHaveAttribute(
    'href',
    `/users/sign_in?user_return_to=${encodeURIComponent(returnTo)}`,
  )
}

// Marks the current document; a full page load drops the mark, an Inertia visit keeps it.
async function markDocument(page: Page) {
  await page.evaluate(() => Object.assign(window, { sameDocument: true }))
}

const sameDocument = (page: Page) => page.evaluate(() => 'sameDocument' in window)

test.describe('request dialog for a signed-out visitor', () => {
  test('opens in place from the catalog, a type page and the empty search, disabled with a sign-in prompt', async ({
    page,
  }) => {
    for (const [path, returnTo] of [
      ['/resources', '/resources?request=new'],
      ['/resources/translation', '/resources/translation?request=new'],
      ['/resources?q=zzqqxx', '/resources?q=zzqqxx&request=new'],
    ]) {
      await page.goto(path)
      await hydrated(page)
      await markDocument(page)
      if (path.includes('q=')) await expect(page.getByText('Nothing matches this search')).toBeVisible()

      await page.getByRole('main').getByRole('link', { name: 'Request a resource' }).click()
      await expectGated(page, returnTo)
      expect(await sameDocument(page)).toBe(true)
      await page.keyboard.press('Escape')
      await expect(dialog(page)).toBeHidden()
    }
  })

  test('opens from the Contribute menu, over the requests page', async ({ page }, testInfo) => {
    await page.goto('/resources/translation')
    await hydrated(page)

    if (testInfo.project.name === 'desktop') {
      const main = page.getByRole('navigation', { name: 'Main' })
      await main.getByRole('button', { name: 'Contribute' }).focus()
      await page.keyboard.press('Enter')
      await main.getByRole('link', { name: /^Request a resource/ }).click()
    } else {
      await page.getByRole('banner').getByRole('button', { name: 'Menu' }).click()
      const sheet = page.getByRole('dialog', { name: 'Menu' })
      await sheet.getByRole('button', { name: /^Contribute\b/ }).click()
      await sheet
        .getByRole('region', { name: /^Contribute\b/ })
        .getByRole('link', { name: /^Request a resource/ })
        .click()
    }

    await expect(page).toHaveURL(/\/requests\?request=new$/, { timeout: 15_000 })
    await expectGated(page, '/requests?request=new')
    // The modal dialog hides the page from the accessibility tree.
    await expect(page.locator('h1')).toContainText('Resource requests')
  })
})

// Sending writes requests to the development clone, one per run and width. A user can send 5 a
// day (ResourceRequest::DAILY_LIMIT), so each width signs in as its own fake account
// (`bin/rails dev:fake_accounts`): five runs a day.
test.describe('sending a request and voting', () => {
  test.describe.configure({ mode: 'serial' })

  // Each run sends requests from the fake accounts, and the daily limit counts the day's: the
  // requests earlier runs sent are dated a day back, so any number of runs fit in a day.
  test.beforeAll(() => {
    rails(`ResourceRequest.joins(:user).where(users: { email: %w[reader@example.test admin@example.test] })
      .where('resource_requests.title LIKE ?', 'Browser spec%').update_all(created_at: 1.day.ago)`)
  })

  const PASSWORD = 'fake-account-password'
  const account = (testInfo: TestInfo) =>
    testInfo.project.name === 'desktop' ? 'reader@example.test' : 'admin@example.test'

  async function signIn(page: Page, testInfo: TestInfo) {
    await page.locator('#user_email').fill(account(testInfo))
    await page.locator('#user_password').fill(PASSWORD)
    await page.getByRole('button', { name: 'Sign in' }).click()
  }

  const field = (page: Page, label: string) => dialog(page).getByLabel(label, { exact: true })

  test('a signed-out visitor signs in, comes back to the dialog open and sends a request that is then listed', async ({
    page,
  }, testInfo) => {
    await page.goto('/resources/tafsir')
    await hydrated(page)
    // A card preview's response sets the session cookie: one that lands after the sign-in page's
    // response would replace the session that holds the return path.
    await page.waitForLoadState('networkidle')
    await page.getByRole('main').getByRole('link', { name: 'Request a resource' }).click()
    await dialog(page).getByRole('link', { name: 'Sign in' }).click()
    await signIn(page, testInfo)

    await expect(page).toHaveURL(/\/resources\/tafsir\?request=new$/)
    await hydrated(page)
    await expect(dialog(page).getByRole('link', { name: 'Sign in' })).toHaveCount(0)
    const title = `Browser spec request ${testInfo.project.name} ${Date.now()}`
    await dialog(page).getByRole('button', { name: 'Tafsir', exact: true }).click()
    await field(page, 'What is missing?').fill(title)
    await field(page, 'Language or script (optional)').fill('Bengali')
    await field(page, 'Author or translator').fill('Salahuddin Yusuf')
    await field(page, 'What are you building?').fill('A study app, from the browser spec.')
    await dialog(page).getByRole('button', { name: 'Send request' }).click()

    const received = page.getByRole('dialog', { name: 'Request received' })
    await expect(received).toBeVisible()
    await received.getByRole('link', { name: 'See all requests' }).click()
    await expect(page).toHaveURL(/\/requests\?sort=date$/)
    const first = page.getByRole('list', { name: 'Requests' }).getByRole('listitem').first()
    await expect(first.getByRole('heading')).toHaveText(title)
    await expect(first).toContainText('Tafsir · Bengali')
    await expect(first).toContainText('Open')
  })

  test('a font request shows its source fields first, takes a file and sends it', async ({ page }, testInfo) => {
    await page.goto('/users/sign_in?user_return_to=%2Frequests%3Frequest%3Dnew')
    await signIn(page, testInfo)
    await expect(page).toHaveURL(/\/requests\?request=new$/)
    await hydrated(page)

    // A written work asks for its author, with the book details and the source folded.
    await dialog(page).getByRole('button', { name: 'Translation', exact: true }).click()
    await expect(field(page, 'Author or translator')).toHaveAttribute('required', '')
    await dialog(page).getByText('Book details (optional)').click()
    await dialog(page).getByText('Source and licence (optional)').click()
    await expect(field(page, 'Publisher')).toBeVisible()
    await dialog(page).getByText('Drop files here or choose them').scrollIntoViewIfNeeded()
    const work = testInfo.outputPath(`request-work-${testInfo.project.name}.png`)
    await page.screenshot({ path: work })
    await testInfo.attach('translation request', { path: work, contentType: 'image/png' })

    // A font asks for no author, and its source is open.
    await dialog(page).getByRole('button', { name: 'Font', exact: true }).click()
    await expect(dialog(page).getByLabel(/^Author/)).toHaveCount(0)
    await field(page, 'What is missing?').fill(`Browser spec font ${testInfo.project.name} ${Date.now()}`)
    await field(page, 'What are you building?').fill('A Nastaliq reader, from the browser spec.')
    await dialog(page)
      .getByLabel('Source files')
      .setInputFiles({ name: 'nastaliq.woff2', mimeType: 'font/woff2', buffer: Buffer.from('wOF2\0\x01\0\0') })
    await expect(dialog(page).getByRole('list', { name: 'Chosen files' })).toContainText('nastaliq.woff2')
    await dialog(page).getByRole('button', { name: 'Remove nastaliq.woff2' }).scrollIntoViewIfNeeded()
    const font = testInfo.outputPath(`request-font-${testInfo.project.name}.png`)
    await page.screenshot({ path: font })
    await testInfo.attach('font request', { path: font, contentType: 'image/png' })
    await dialog(page).getByRole('button', { name: 'Send request' }).click()

    await expect(page.getByRole('dialog', { name: 'Request received' })).toBeVisible()
  })

  test('invalid input shows the errors beside the fields and keeps what was typed', async ({ page }, testInfo) => {
    await page.goto('/users/sign_in?user_return_to=%2Frequests%3Frequest%3Dnew')
    await signIn(page, testInfo)
    await expect(page).toHaveURL(/\/requests\?request=new$/)
    await hydrated(page)

    // No kind chosen: the browser cannot catch that, the server does.
    await field(page, 'What is missing?').fill('Hausa translation')
    await field(page, 'What are you building?').fill('A reading app.')
    await dialog(page).getByRole('button', { name: 'Send request' }).click()

    await expect(dialog(page).getByText('Resource type must be chosen from the list')).toBeVisible()
    await expect(dialog(page).getByRole('group', { name: 'What kind of resource?' })).toHaveAttribute(
      'aria-describedby',
      'request-resource_type-error',
    )
    await expect(field(page, 'What is missing?')).toHaveValue('Hausa translation')
    await expect(field(page, 'What are you building?')).toHaveValue('A reading app.')
  })

  test('a signed-out vote asks for sign-in, back to the requests page', async ({ page }) => {
    await page.goto('/requests?sort=date')
    await hydrated(page)

    const vote = page.getByRole('list', { name: 'Requests' }).getByRole('link', { name: /^Sign in to vote for / })
    await vote.first().click()
    await expect(page).toHaveURL(/\/users\/sign_in\?user_return_to=%2Frequests%3Fsort%3Ddate$/)
  })

  test('a signed-in user votes and takes the vote back, in place', async ({ page }, testInfo) => {
    await page.goto('/users/sign_in?user_return_to=%2Frequests%3Fsort%3Ddate')
    await signIn(page, testInfo)
    await expect(page).toHaveURL(/\/requests\?sort=date$/)
    await hydrated(page)
    await markDocument(page)

    const vote: Locator = page.getByRole('list', { name: 'Requests' }).getByRole('button').first()
    const pressed = (await vote.getAttribute('aria-pressed')) === 'true'
    const count = Number(await vote.textContent())

    await vote.click()
    await expect(vote).toHaveAttribute('aria-pressed', String(!pressed))
    await expect(vote).toHaveText(String(count + (pressed ? -1 : 1)))
    await vote.click()
    await expect(vote).toHaveAttribute('aria-pressed', String(pressed))
    await expect(vote).toHaveText(String(count))
    expect(await sameDocument(page)).toBe(true)
  })
})
