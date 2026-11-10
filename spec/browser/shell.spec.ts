import type { Locator, Page, Response } from '@playwright/test'

import { expect, test } from './support/test'

// The parts of the `nav` shared prop (SiteNavResource) the tests read.
type SiteNavLink = { label: string; href: string; external: boolean; inertia: boolean }
type SiteNavGroup = { heading: string; links: SiteNavLink[] }
type SiteNavMenu = SiteNavLink & { overview: string; groups: SiteNavGroup[]; aside: SiteNavGroup[] }
type SiteNav = { menus: SiteNavMenu[]; search: SiteNavLink; footer: SiteNavGroup[] }

const PAGE = '/resources/translation'
const READER = { email: 'reader@example.test', password: 'fake-account-password', initials: 'FR', name: 'Fake' }

// The site navigation the page received (the `nav` shared prop in the initial page data).
async function siteNav(page: Page): Promise<SiteNav> {
  const data = await page.locator('script[data-page="app"]').textContent()
  return JSON.parse(data!).props.nav
}

const isInternal = (link: SiteNavLink) => !link.external
const escapeRegExp = (text: string) => text.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')

// Marks the current document; a full page load drops the mark, an Inertia visit keeps it.
async function markDocument(page: Page) {
  await page.evaluate(() => Object.assign(window, { sameDocument: true }))
}

const sameDocument = (page: Page) => page.evaluate(() => 'sameDocument' in window)

// React has taken over the server-rendered page, so its handlers (menus, dialogs) respond.
async function hydrated(page: Page) {
  await page.waitForFunction(() =>
    Object.keys(document.getElementById('app') ?? {}).some((key) => key.startsWith('__reactContainer')),
  )
}

function header(page: Page) {
  return page.getByRole('banner')
}

test.describe('site header and footer', () => {
  test('desktop header: icon-only logo, menus with the contributor tools, search icon and account control', async ({
    page,
  }, testInfo) => {
    test.skip(testInfo.project.name !== 'desktop', 'desktop layout')
    await page.goto(PAGE)
    await hydrated(page)

    const logo = header(page).getByRole('link', { name: 'QUL home' })
    await expect(logo.locator('svg')).toHaveCount(1)
    expect((await logo.textContent())?.trim()).toBe('')
    const main = page.getByRole('navigation', { name: 'Main' })
    for (const label of ['Resources', 'Docs', 'Developers', 'Contribute'])
      await expect(main.getByRole('button', { name: label })).toBeVisible()
    await expect(header(page).getByRole('link', { name: 'Search resources' })).toBeVisible()
    await expect(header(page).getByRole('link', { name: 'Sign in' })).toBeVisible()
    await expect(header(page).getByRole('searchbox')).toHaveCount(0)
    await expect(header(page).getByRole('button', { name: /theme/ })).toHaveCount(0)
    await expect(page.getByRole('contentinfo').getByRole('button', { name: /theme/ })).toBeVisible()

    await main.getByRole('button', { name: 'Contribute' }).focus()
    await page.keyboard.press('Enter')
    const tools = (await siteNav(page)).menus.find((menu) => menu.label === 'Contribute')!.groups[0].links
    expect(tools.length).toBeGreaterThan(10)
    for (const tool of tools) await expect(main.getByRole('link', { name: tool.label, exact: true })).toBeVisible()
    await testInfo.attach('header-contribute-menu', {
      body: await page.screenshot({ clip: { x: 0, y: 0, width: 1280, height: 640 } }),
      contentType: 'image/png',
    })
    await page.keyboard.press('Escape')

    await page.getByRole('contentinfo').scrollIntoViewIfNeeded()
    await testInfo.attach('footer', {
      body: await page.getByRole('contentinfo').screenshot(),
      contentType: 'image/png',
    })
  })

  test('phone: the menu sheet lists the same destinations and closes after a visit', async ({ page }, testInfo) => {
    test.skip(testInfo.project.name !== 'phone', 'phone layout')
    await page.setViewportSize({ width: 390, height: 844 })
    await page.goto(PAGE)
    await hydrated(page)
    const nav = await siteNav(page)
    await markDocument(page)

    await header(page).getByRole('button', { name: 'Menu' }).click()
    const sheet = page.getByRole('dialog', { name: 'Menu' })
    await expect(sheet).toBeVisible()
    const listed: string[] = []
    for (const menu of nav.menus) {
      await sheet.getByRole('button', { name: menu.label }).click()
      const section = sheet.getByRole('region', { name: menu.label })
      await expect(section).toBeVisible()
      listed.push(
        ...(await section.getByRole('link').evaluateAll((links) => links.map((a) => a.getAttribute('href')!))),
      )
    }
    const expected = nav.menus.flatMap((menu) => [
      menu.href,
      ...[...menu.groups, ...menu.aside].flatMap((group) => group.links.map((link) => link.href)),
    ])
    expect(new Set(listed)).toEqual(new Set(expected))
    await testInfo.attach('menu-sheet', { body: await page.screenshot(), contentType: 'image/png' })

    await sheet.getByRole('button', { name: 'Resources' }).click()
    await sheet.getByRole('region', { name: 'Resources' }).getByRole('link', { name: 'Tafsirs' }).click()
    await expect(page).toHaveURL(/\/resources\/tafsir$/)
    await expect(page.getByRole('heading', { level: 1 })).toContainText('Tafsirs')
    await expect(sheet).toBeHidden()
    expect(await sameDocument(page)).toBe(true)
  })

  test('every header and footer link: old pages load in full with 200, new pages are Inertia visits', async ({
    page,
  }, testInfo) => {
    test.skip(testInfo.project.name !== 'desktop', 'one width is enough for the link list')
    test.setTimeout(600_000)
    await page.goto(PAGE)
    const nav = await siteNav(page)
    const origin = new URL(page.url()).origin

    const targets: { where: string; link: SiteNavLink; open: () => Locator | Promise<Locator> }[] = []
    for (const menu of nav.menus) {
      const panelLinks = [...menu.groups, ...menu.aside].flatMap((group) => group.links)
      for (const link of [...panelLinks, { ...menu, label: menu.overview }]) {
        if (!isInternal(link)) continue
        targets.push({
          where: `menu ${menu.label}`,
          link,
          open: async () => {
            const main = page.getByRole('navigation', { name: 'Main' })
            await main.getByRole('button', { name: menu.label }).focus()
            await page.keyboard.press('Enter')
            return main
              .locator(`a[href="${link.href}"]`)
              .filter({ hasText: new RegExp(`^${escapeRegExp(link.label)}`) })
              .first()
          },
        })
      }
    }
    for (const group of nav.footer)
      for (const link of group.links.filter(isInternal))
        targets.push({
          where: `footer ${group.heading}`,
          link,
          open: () => page.getByRole('contentinfo').getByRole('link', { name: link.label, exact: true }),
        })
    targets.push({
      where: 'header',
      link: nav.search,
      open: () => header(page).getByRole('link', { name: 'Search resources' }),
    })
    expect(targets.length).toBeGreaterThan(40)

    const results: string[] = []
    for (const { where, link, open } of targets) {
      await page.goto(PAGE)
      await hydrated(page)
      await markDocument(page)
      const target = await open()
      const url = `${origin}${link.href}`
      const response: Promise<Response> = page.waitForResponse(
        (r) => r.url() === url && r.request().method() === 'GET',
        { timeout: 60_000 },
      )
      await target.click()
      const status = (await response).status()
      await page.waitForURL(url, { timeout: 60_000 })
      if (link.inertia) await expect(page.getByRole('heading', { level: 1 })).toBeVisible()
      const kept = await sameDocument(page)
      results.push(`${where}: ${link.href} ${status} ${kept ? 'inertia visit' : 'full page load'}`)

      expect(status, `${where} ${link.href}`).toBe(200)
      expect(kept, `${where} ${link.href} is ${link.inertia ? 'an Inertia visit' : 'a full page load'}`).toBe(
        link.inertia,
      )
    }
    await testInfo.attach('links', { body: results.join('\n'), contentType: 'text/plain' })
    console.log(
      `[links] ${results.length} links, ${results.filter((line) => line.endsWith('inertia visit')).length} Inertia visits, all 200`,
    )
  })
})

test.describe('account control', () => {
  test('sign in returns to the page with a notice shown once; sign out works', async ({ page }, testInfo) => {
    test.skip(testInfo.project.name !== 'desktop', 'desktop layout')
    await page.goto(PAGE)

    await header(page).getByRole('link', { name: 'Sign in' }).click()
    await expect(page).toHaveURL(/\/users\/sign_in\?user_return_to=%2Fresources%2Ftranslation$/)
    await page.locator('#user_email').fill(READER.email)
    await page.locator('#user_password').fill(READER.password)
    await page.getByRole('button', { name: 'Sign in' }).click()

    await expect(page).toHaveURL(new RegExp(`${PAGE}$`))
    await expect(page.getByRole('status').filter({ hasText: 'Signed in successfully.' })).toBeVisible()
    const account = header(page).getByRole('button', { name: READER.name })
    await expect(account).toHaveText(`${READER.initials}${READER.name}`)
    await expect(header(page).getByRole('link', { name: 'Sign in' })).toHaveCount(0)

    await page.getByRole('navigation', { name: 'Other resource types' }).getByRole('link', { name: 'Tafsirs' }).click()
    await expect(page.getByRole('heading', { level: 1 })).toContainText('Tafsirs')
    await expect(page.getByText('Signed in successfully.')).toHaveCount(0)
    await page.reload()
    await hydrated(page)
    await expect(page.getByRole('heading', { level: 1 })).toContainText('Tafsirs')
    await expect(page.getByText('Signed in successfully.')).toHaveCount(0)

    await account.click()
    await page.getByRole('menuitem', { name: 'Sign out' }).click()
    await expect(page).toHaveURL(/\/$/)
    await page.goto(PAGE)
    await expect(header(page).getByRole('link', { name: 'Sign in' })).toBeVisible()
  })
})

test.describe('theme', () => {
  // The class on <html> when <body> starts, before any module script (and so React) runs.
  async function classBeforeHydration(page: Page) {
    await page.addInitScript(() => {
      new MutationObserver((_, observer) => {
        if (!document.body) return
        Object.assign(window, { darkBeforeHydration: document.documentElement.classList.contains('dark') })
        observer.disconnect()
      }).observe(document, { childList: true, subtree: true })
    })
  }

  test('follows the system setting on first paint, and a stored choice wins on reload', async ({ page }) => {
    await classBeforeHydration(page)
    await page.emulateMedia({ colorScheme: 'dark' })
    await page.goto(PAGE)
    expect(await page.evaluate(() => (window as unknown as { darkBeforeHydration: boolean }).darkBeforeHydration)).toBe(
      true,
    )

    await page.getByRole('contentinfo').getByRole('button', { name: 'Use the light theme' }).click()
    await expect(page.locator('html')).not.toHaveClass(/dark/)
    await page.reload()
    expect(await page.evaluate(() => (window as unknown as { darkBeforeHydration: boolean }).darkBeforeHydration)).toBe(
      false,
    )
    await expect(page.locator('html')).not.toHaveClass(/dark/)

    await page.emulateMedia({ colorScheme: 'light' })
    await page.evaluate(() => localStorage.removeItem('qul-theme'))
    await page.reload()
    await expect(page.locator('html')).not.toHaveClass(/dark/)
  })
})

test.describe('type page load', () => {
  test('hydrates with no warning and loads the interface fonts from this app', async ({ page }) => {
    const messages: string[] = []
    page.on('console', (message) => {
      if (['error', 'warning'].includes(message.type())) messages.push(message.text())
    })
    const requests: string[] = []
    const fonts: string[] = []
    page.on('request', (request) => {
      requests.push(request.url())
      if (request.resourceType() === 'font') fonts.push(request.url())
    })

    await page.goto(PAGE)
    await expect(page.locator('#app[data-server-rendered="true"]')).toHaveCount(1)
    await page.waitForLoadState('networkidle')
    expect(await page.evaluate(() => document.fonts.check('16px "Host Grotesk Variable"'))).toBe(true)

    expect(messages.filter((text) => /hydrat|did not match|mismatch/i.test(text))).toEqual([])
    const origin = new URL(page.url()).origin
    // This app's own host: in development Vite serves the bundled font files beside Rails.
    expect(fonts.length).toBeGreaterThan(0)
    expect(fonts.filter((url) => new URL(url).hostname !== new URL(origin).hostname)).toEqual([])
    expect(requests.filter((url) => /fonts\.(googleapis|gstatic)\.com|use\.fontawesome|cdnjs/.test(url))).toEqual([])
    console.log(`[fonts] ${fonts.map((url) => new URL(url).pathname).join(', ')}`)
  })
})
