import type { FullConfig } from '@playwright/test'

// A reused Rails server may have been started without the page groups the specs need.
export default async function globalSetup(config: FullConfig) {
  const baseURL = config.projects[0].use.baseURL
  // A server behind Cloudflare Access (staging) takes the service token from the environment.
  const { CF_ACCESS_CLIENT_ID: id, CF_ACCESS_CLIENT_SECRET: secret } = process.env
  const headers = id && secret ? { 'CF-Access-Client-Id': id, 'CF-Access-Client-Secret': secret } : undefined
  const response = await fetch(`${baseURL}/resources/translation`, { headers })
  const html = await response.text()
  if (!html.includes('data-page="app"')) {
    throw new Error(
      `${baseURL}/resources/translation is not an Inertia page. Start Rails with QUL_PAGE_GROUPS=home,catalog,apps,content,start,requests,account.`,
    )
  }
}
