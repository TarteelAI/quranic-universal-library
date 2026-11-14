import type { BrowserContext, Page } from '@playwright/test'

import { expect as baseExpect, test } from './support/test'

// The bundle tray (002-17) on the development clone: adding and removing from a card, a kit page
// and a detail page, the header count across a reload and a second tab, and the tray's download
// links in the server's download mode. Download mode is the server's QUL_DOWNLOAD_MODE, so each
// mode's test runs only against a server in that mode: run the file once as is, and once against
// Rails started with QUL_DOWNLOAD_MODE=public.

// Kit and type pages run catalog searches; allow for a slow server.
const expect = baseExpect.configure({ timeout: 20_000 })

const KIT = '/kits/recitation'

// The lookup's answer (CatalogBundle in app/frontend/types/serializers), as far as these tests read it.
type CatalogBundleItem = {
  id: number
  restricted: boolean
  resource: { name: string; type: string; toParam: string } | null
  files: { id: number }[]
}
type CatalogBundle = { items: CatalogBundleItem[]; downloadMode: 'sign_in' | 'public' }

async function hydrated(page: Page) {
  await page.waitForFunction(() =>
    Object.keys(document.getElementById('app') ?? {}).some((key) => key.startsWith('__reactContainer')),
  )
}

async function pageProps<T>(page: Page): Promise<T> {
  return page.evaluate(() => JSON.parse(document.querySelector('script[data-page="app"]')?.textContent ?? '{}').props)
}

async function lookup(context: BrowserContext, ids: number[]) {
  const response = await context.request.get(`/bundle?ids=${ids.join(',')}`)
  expect(response.ok()).toBe(true)
  return (await response.json()) as CatalogBundle
}

const downloadable = (item: CatalogBundleItem) => item.resource !== null && !item.restricted && item.files.length > 0

// Two downloadable translations from the type page that are not in the kit.
async function translations(page: Page, exclude: number[]) {
  await page.goto('/resources/translation')
  const { resources } = await pageProps<{ resources: { id: number }[] }>(page)
  const ids = resources.map((resource) => resource.id).filter((id) => !exclude.includes(id))
  const { items } = await lookup(page.context(), ids.slice(0, 30))
  const picked = items.filter(downloadable)
  expect(picked.length).toBeGreaterThanOrEqual(2)
  return picked.slice(0, 2)
}

function bundleButton(page: Page) {
  return page.getByRole('banner').getByRole('button', { name: /^Bundle, / })
}

async function expectCount(page: Page, count: number) {
  await expect(bundleButton(page)).toHaveAttribute(
    'aria-label',
    `Bundle, ${count} ${count === 1 ? 'resource' : 'resources'}`,
  )
}

const stored = (page: Page) =>
  page.evaluate(() => JSON.parse(window.localStorage.getItem('qul-bundle') ?? '[]') as number[])

const detailPath = (item: CatalogBundleItem) => `/resources/${item.resource!.type}/${item.resource!.toParam}`

test('a card, a kit page and a detail page add and remove, and the count holds across a reload and tabs', async ({
  page,
  context,
}) => {
  test.setTimeout(180_000)
  await page.goto(KIT)
  const kitIds = (await pageProps<{ items: { resource: { id: number } }[] }>(page)).items.map(
    (item) => item.resource.id,
  )
  const [card, detail] = await translations(page, kitIds)
  await hydrated(page)
  await expectCount(page, 0)

  // A card on the type page.
  await page
    .getByRole('button', { name: `Add ${card.resource!.name} to bundle` })
    .first()
    .click()
  await expectCount(page, 1)

  // The kit page adds every item in one press.
  await page.goto(KIT)
  await hydrated(page)
  await page.getByRole('button', { name: 'Add kit to bundle' }).click()
  await expect(page.getByRole('button', { name: 'Kit is in your bundle' })).toBeVisible()
  await expectCount(page, 1 + kitIds.length)

  // The detail page's download panel.
  await page.goto(detailPath(detail))
  await hydrated(page)
  const panel = page.getByRole('complementary', { name: 'Download' })
  await panel.getByRole('button', { name: 'Add to bundle' }).click()
  const total = 2 + kitIds.length
  await expectCount(page, total)
  expect(await stored(page)).toEqual([card.id, ...kitIds, detail.id])

  // A reload and a second tab read the same list; a change in one tab shows in the other.
  await page.reload()
  await hydrated(page)
  await expectCount(page, total)
  const other = await context.newPage()
  await other.goto('/')
  await hydrated(other)
  await expectCount(other, total)

  await panel.getByRole('button', { name: 'In your bundle' }).click()
  await expectCount(page, total - 1)
  await expectCount(other, total - 1)

  await page.goto(KIT)
  await hydrated(page)
  await page.getByRole('button', { name: 'Kit is in your bundle' }).click()
  await expectCount(page, 1)
  await expectCount(other, 1)

  await page.goto('/resources/translation')
  await hydrated(page)
  await page
    .getByRole('button', { name: `Remove ${card.resource!.name} from bundle` })
    .first()
    .click()
  await expectCount(page, 0)
  await expectCount(other, 0)
  expect(await stored(page)).toEqual([])
})

// Opens the tray holding one downloadable resource and returns its first file's link.
async function trayWith(page: Page) {
  const [item] = await translations(page, [])
  await page.evaluate((id) => window.localStorage.setItem('qul-bundle', JSON.stringify([id])), item.id)
  await page.goto('/')
  await hydrated(page)
  await bundleButton(page).click()
  const tray = page.getByRole('dialog', { name: 'Bundle' })
  await expect(tray.getByRole('link', { name: item.resource!.name })).toBeVisible()
  const files = tray.getByRole('list', { name: `Files of ${item.resource!.name}` }).getByRole('link')
  await expect(files).toHaveCount(item.files.length)
  const file = item.files[0]
  const link = files.first()
  expect(await link.getAttribute('href')).toBe(`${detailPath(item)}/download/${file.id}`)
  return { item, file, link }
}

async function serverMode(page: Page) {
  return (await lookup(page.context(), [])).downloadMode
}

test('in sign-in mode a tray download sends an anonymous visitor to sign in', async ({ page }) => {
  test.setTimeout(120_000)
  await page.goto('/')
  test.skip((await serverMode(page)) !== 'sign_in', 'the server is in public mode')
  const { item, file, link } = await trayWith(page)

  await expect(page.getByRole('dialog', { name: 'Bundle' }).getByText('Downloads need a free account.')).toBeVisible()
  await link.click()
  await expect(page).toHaveURL(/\/users\/sign_in\?/)
  expect(new URL(page.url()).searchParams.get('user_return_to')).toBe(`${detailPath(item)}?download=${file.id}`)
})

test('in public mode a tray download sends the file', async ({ page }) => {
  test.setTimeout(120_000)
  await page.goto('/')
  test.skip((await serverMode(page)) !== 'public', 'the server is in sign-in mode')
  const { file, link } = await trayWith(page)

  // The redirect's target is the file in storage, which does not resolve locally; the request
  // is what shows the download started (resource-page.spec.ts does the same).
  const fileRequest = new Promise<string>((resolve) => {
    page.on('request', (request) => {
      if (request.redirectedFrom()?.url().endsWith(`/download/${file.id}`)) resolve(request.url())
    })
  })
  await link.click()
  expect(await fileRequest).toMatch(/\.(zip|bz2)$/)
})
