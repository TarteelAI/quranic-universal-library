import { execSync } from 'node:child_process'
import { mkdirSync, rmSync, writeFileSync } from 'node:fs'
import { randomUUID } from 'node:crypto'

import type { Page } from '@playwright/test'

import { expect, test } from './support/test'

// The resource detail page (/resources/:type/:slug) on the development clone: downloads in both
// download modes, a restricted resource, the tabs and the changelog.
//
// Download mode is the server's QUL_DOWNLOAD_MODE, so each mode's tests run only against a
// server in that mode (the rest skip): run the file once as is, and once against Rails started
// with QUL_DOWNLOAD_MODE=public.
//
// Some checks read the database through `bin/rails runner`. QUL_BROWSER_RAILS_RUNNER replaces
// that command, for example `docker exec qul-dev bin/rails runner` when Rails runs in Docker.
// The script goes through tmp/, which the container sees at the same relative path.

const RUNNER = process.env.QUL_BROWSER_RAILS_RUNNER ?? 'bin/rails runner'
const READER = { email: 'reader@example.test', password: 'fake-account-password' }
const ADMIN = { email: 'admin@example.test', password: 'fake-account-password' }

// Runs Ruby in the development environment and parses the JSON its last line prints.
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

type Fixture = { path: string; fileId: number }
type Fixtures = { plain: Fixture; changelog: string; restricted: string }

let fixtures: Fixtures

test.beforeAll(() => {
  test.setTimeout(120_000)
  fixtures = rails<Fixtures>(`
    published = DownloadableResource.published.order(:id).includes(downloadable_files: { file_attachment: :blob })
    changed = ChangeLog.published.distinct.pluck(:resource_content_id)
    path = ->(r) { "/resources/#{r.resource_type}/#{r.to_param}" }
    file = ->(r) { r.downloadable_files.sort_by { |f| [f.position, f.id] }.find { |f| f.published && f.file.attached? } }
    plain = published.where(resource_type: 'translation').find do |r|
      !r.restrict_download? && file.(r) && !changed.include?(r.resource_content_id)
    end
    puts({ plain: { path: path.(plain), fileId: file.(plain).id },
           changelog: path.(published.find { |r| changed.include?(r.resource_content_id) }),
           restricted: path.(published.find(&:restrict_download?)) }.to_json)
  `)
})

async function hydrated(page: Page) {
  await page.waitForFunction(() =>
    Object.keys(document.getElementById('app') ?? {}).some((key) => key.startsWith('__reactContainer')),
  )
}

async function downloadMode(page: Page) {
  return page.evaluate(() => {
    const data = document.querySelector('script[data-page="app"]')?.textContent ?? '{}'
    return (JSON.parse(data) as { props?: { downloadMode?: string } }).props?.downloadMode
  })
}

async function signIn(page: Page, account: { email: string; password: string }) {
  await page.locator('#user_email').fill(account.email)
  await page.locator('#user_password').fill(account.password)
  await page.getByRole('button', { name: /sign in|log in/i }).click()
}

function panel(page: Page) {
  return page.getByRole('complementary', { name: 'Download' })
}

// The browser's request for the file in storage, reached through the download route's redirect.
// (A frame's requests reach page.on('request') but not page.waitForRequest.) The storage host
// does not resolve locally, and page.route does not see a redirect's target, so the file request
// itself fails; the request is what shows the download started.
function fileRequest(page: Page, fileId: number) {
  return new Promise<string>((resolve) => {
    page.on('request', (request) => {
      if (request.redirectedFrom()?.url().endsWith(`/download/${fileId}`)) resolve(request.url())
    })
  })
}

test.describe('sign-in mode', () => {
  test('an anonymous Download signs in and comes back to the page with the download started', async ({
    page,
  }, testInfo) => {
    test.skip(testInfo.project.name !== 'desktop', 'one width is enough for the sign-in chain')
    // Each `rails` call boots Rails.
    test.setTimeout(120_000)
    const { path, fileId } = fixtures.plain
    const rows = `UserDownload.where(user: User.find_by!(email: '${READER.email}'), downloadable_file_id: ${fileId})`
    rails(`${rows}.delete_all; puts 0`)

    await page.goto(path)
    test.skip((await downloadMode(page)) !== 'sign_in', 'the server is in public mode')
    await hydrated(page)

    await panel(page).locator(`a[href$="/download/${fileId}"]`).click()
    await expect(page).toHaveURL(/\/users\/sign_in\?user_return_to=/)

    const file = fileRequest(page, fileId)
    await signIn(page, READER)

    expect(await file).toMatch(/\.(zip|bz2)$/)
    await expect(page).toHaveURL(new RegExp(`${path}$`))
    await expect(page.getByRole('status').filter({ hasText: 'has started' })).toBeVisible()
    expect(rails<number>(`puts ${rows}.count`)).toBe(1)
  })
})

test.describe('public mode', () => {
  test('Download sends the file without sign-in, and the panel offers sign-in for update emails', async ({ page }) => {
    test.setTimeout(120_000)
    const { path, fileId } = fixtures.plain
    await page.goto(path)
    test.skip((await downloadMode(page)) !== 'public', 'the server is in sign-in mode')
    await hydrated(page)
    const counted = `DownloadableFile.find(${fileId}).anonymous_download_count`
    const before = rails<number>(`puts ${counted}`)

    await expect(panel(page).getByText('to get an email when this resource is updated')).toBeVisible()
    const signIn = panel(page).getByRole('link', { name: 'Sign in' })
    expect(await signIn.getAttribute('href')).toBe(`/users/sign_in?user_return_to=${encodeURIComponent(path)}`)

    const file = fileRequest(page, fileId)
    await panel(page).locator(`a[href$="/download/${fileId}"]`).click()

    expect(await file).toMatch(/\.(zip|bz2)$/)
    // The other width's run of this test may count the same file at the same time.
    expect(rails<number>(`puts ${counted}`)).toBeGreaterThanOrEqual(before + 1)
  })
})

test('a restricted resource shows its reason and no download to a reader, and the download to an admin', async ({
  page,
}) => {
  await page.goto(fixtures.restricted)
  await expect(page.getByText('View only')).toBeVisible()
  await expect(panel(page).getByRole('link', { name: /^Download/ })).toHaveCount(0)
  await expect(panel(page).getByText(/Permission is required|not downloaded/)).toBeVisible()

  await page.goto(`/users/sign_in?user_return_to=${encodeURIComponent(fixtures.restricted)}`)
  await signIn(page, READER)
  await expect(page).toHaveURL(new RegExp(`${fixtures.restricted}$`))
  await expect(panel(page).getByRole('link', { name: /^Download/ })).toHaveCount(0)

  await page.context().clearCookies()
  await page.goto(`/users/sign_in?user_return_to=${encodeURIComponent(fixtures.restricted)}`)
  await signIn(page, ADMIN)
  await expect(page).toHaveURL(new RegExp(`${fixtures.restricted}$`))
  await expect(
    panel(page)
      .getByRole('link', { name: /^Download/ })
      .first(),
  ).toBeVisible()
})

test('the open tab is in the URL, Back and Forward follow it, and a tab URL loads directly', async ({ page }) => {
  const { path } = fixtures.plain
  await page.goto(path)
  await hydrated(page)
  await expect(page.getByRole('tab', { name: 'Preview' })).toHaveAttribute('aria-selected', 'true')
  await expect(page.getByTestId('text-preview')).toBeVisible()
  await expect(page.getByRole('tab', { name: 'Changelog' })).toHaveCount(0)

  await page.getByRole('tab', { name: 'Data' }).click()
  await expect(page).toHaveURL(new RegExp(`${path}\\?tab=data$`))
  await expect(page.getByRole('tabpanel').getByText('Granularity')).toBeVisible()

  await page.goBack()
  await expect(page).toHaveURL(new RegExp(`${path}$`))
  await expect(page.getByRole('tab', { name: 'Preview' })).toHaveAttribute('aria-selected', 'true')
  await page.goForward()
  await expect(page.getByRole('tab', { name: 'Data' })).toHaveAttribute('aria-selected', 'true')

  await page.goto(`${path}?tab=data`)
  await expect(page.getByRole('tab', { name: 'Data' })).toHaveAttribute('aria-selected', 'true')
  await expect(page.getByRole('tabpanel').getByText('Granularity')).toBeVisible()

  await page.goto(`${path}?tab=licence`)
  await expect(page.getByRole('tab', { name: 'Licence' })).toHaveAttribute('aria-selected', 'true')
  await expect(page.getByRole('tabpanel').getByRole('heading', { name: 'Licence not yet confirmed' })).toBeVisible()
})

test('a resource with changelog entries has the Changelog tab with them', async ({ page }) => {
  await page.goto(fixtures.changelog)
  await hydrated(page)

  await page.getByRole('tab', { name: 'Changelog' }).click()
  await expect(page).toHaveURL(/\?tab=changelog$/)
  const entries = page.getByRole('list', { name: 'Changelog' }).getByRole('listitem')
  expect(await entries.count()).toBeGreaterThan(0)
  await expect(entries.first().getByRole('link')).toHaveAttribute('href', /^\/change_logs\/\d+$/)
})

test('the page fits the phone width and reports no hydration error', async ({ page }) => {
  const errors: string[] = []
  page.on('console', (message) => {
    if (message.type() === 'error' && /hydrat|did not match|mismatch/i.test(message.text())) errors.push(message.text())
  })
  await page.goto(fixtures.changelog)
  await hydrated(page)

  expect(await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth)).toBeLessThanOrEqual(0)
  expect(errors).toEqual([])
})
