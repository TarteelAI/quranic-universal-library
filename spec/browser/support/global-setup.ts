import type { FullConfig } from '@playwright/test'

// A reused Rails server may have been started without the page groups the specs need.
export default async function globalSetup(config: FullConfig) {
  const baseURL = config.projects[0].use.baseURL
  const response = await fetch(`${baseURL}/resources/translation`)
  const html = await response.text()
  if (!html.includes('data-page="app"')) {
    throw new Error(
      `${baseURL}/resources/translation is not an Inertia page. Start Rails with QUL_PAGE_GROUPS=home,catalog,apps.`,
    )
  }
}
