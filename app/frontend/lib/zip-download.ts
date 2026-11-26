import { catalogDownload, detailResources } from '@/routes'
import type { CatalogBundleItem } from '@/types/serializers'

import { shownFiles } from './bundle'
import { formatBytes } from './format'

// One zip of a kit or of the visitor's bundle, built in the browser. Each file is fetched through
// its own download URL (Catalog::DownloadsController), so the server applies the same rules and
// counts each file once, as a click on its link does; the redirect to storage is followed by
// fetch (the CDN allows any origin). The storage URL is never fetched directly. Files go in one
// at a time, uncompressed (they are zips already): client-zip, loaded only when a zip starts.
//
// Chromium writes the zip straight to the file the visitor picks (showSaveFilePicker), so it has
// no size limit. Other browsers hold the whole zip in memory until it is saved, so they zip at
// most MEMORY_LIMIT bytes; above that the visitor downloads the files one by one.

export const MEMORY_LIMIT = 500 * 1024 * 1024

export interface ZipEntry {
  /** The path inside the zip: <type>/<resource slug>/<file name> */
  path: string
  url: string
  byteSize: number
  item: CatalogBundleItem
}

export interface Failure {
  path: string
  reason: string
}

export interface Progress {
  files: number
  bytes: number
}

/** The files of the items that can be downloaded, in the items' order, each under its own path. */
export function zipEntries(items: CatalogBundleItem[], formats: string[] | null = null): ZipEntry[] {
  const taken = new Set<string>()
  return items.flatMap((item) => {
    const { resource } = item
    if (!resource || item.restricted) return []
    return shownFiles(item, formats).map((file) => {
      let path = `${resource.type}/${resource.toParam}/${file.filename}`
      if (taken.has(path)) path = `${resource.type}/${resource.toParam}/${file.id}-${file.filename}`
      taken.add(path)
      const url = catalogDownload({ type: resource.type, slug: resource.toParam, fileId: file.id }).url
      return { path, url, byteSize: file.byteSize, item }
    })
  })
}

/** The sum of the entries' sizes, about the zip's size (no compression). */
export function totalBytes(entries: ZipEntry[]) {
  return entries.reduce((sum, entry) => sum + entry.byteSize, 0)
}

/** "recitation-kit.zip" for "Recitation kit". */
export function zipName(title: string) {
  const slug = title
    .toLowerCase()
    .replace(/[^\p{L}\p{N}]+/gu, '-')
    .replace(/^-|-$/g, '')
  return `${slug || 'qul'}.zip`
}

function unavailable(item: CatalogBundleItem) {
  if (!item.resource) return `Resource ${item.id}: no longer in the library.`
  if (item.restricted) return `${item.resource.name}: the publisher does not allow downloads.`
  if (item.files.length === 0) return `${item.resource.name}: no files to download now.`
  return null
}

/** The zip's README.md: each resource with its licence, its page and its files, and what is missing. */
export function readme(
  title: string,
  origin: string,
  items: CatalogBundleItem[],
  entries: ZipEntry[],
  failed: Failure[],
) {
  const lines = [`# ${title}`, '', `Downloaded from the Quranic Universal Library (QUL), ${origin}.`, '']
  for (const item of items) {
    const { resource } = item
    const files = entries.filter((entry) => entry.item === item && !failed.some((f) => f.path === entry.path))
    if (!resource || files.length === 0) continue
    lines.push(`## ${resource.name}`, '')
    lines.push(`- Page: ${origin}${detailResources({ type: resource.type, id: resource.toParam }).url}`)
    if (item.licence) lines.push(`- Licence: ${item.licence.name}${item.licence.url ? ` (${item.licence.url})` : ''}`)
    lines.push(...files.map((entry) => `- \`${entry.path}\` (${formatBytes(entry.byteSize)})`), '')
  }
  const missing = [
    ...items.map(unavailable).filter((note): note is string => note !== null),
    ...failed.map((failure) => `\`${failure.path}\`: ${failure.reason}`),
  ]
  if (missing.length > 0) lines.push('## Not included', '', ...missing.map((note) => `- ${note}`), '')
  return lines.join('\n')
}

/** Whether this browser can write the zip to disk as it is built (Chromium). */
export function canStream() {
  return typeof window !== 'undefined' && 'showSaveFilePicker' in window
}

// Why a file's response is not the file: a status the download route answers with, or the
// sign-in page that an anonymous request is sent to in sign-in mode.
function problem(response: Response) {
  if (response.status === 403) return 'the publisher does not allow downloads'
  if (response.status === 404) return 'no longer available'
  if (!response.ok) return `the server answered ${response.status}`
  if (response.headers.get('content-type')?.includes('text/html')) return 'sign in to download'
  return null
}

export interface ZipOptions {
  title: string
  /** The site's origin, for the README's links */
  origin: string
  items: CatalogBundleItem[]
  entries: ZipEntry[]
  signal: AbortSignal
  onProgress: (progress: Progress) => void
}

/**
 * The zip as a stream: each entry fetched in turn, then the README. A file that cannot be fetched
 * is left out and named in the README; `failed` lists them once the stream has ended.
 */
export async function zipStream({ title, origin, items, entries, signal, onProgress }: ZipOptions) {
  const { makeZip } = await import('client-zip')
  const failed: Failure[] = []
  const progress: Progress = { files: 0, bytes: 0 }

  // Passes the bytes on, counting them.
  function counter() {
    return new TransformStream<Uint8Array, Uint8Array>({
      transform(chunk, controller) {
        progress.bytes += chunk.byteLength
        onProgress({ ...progress })
        controller.enqueue(chunk)
      },
    })
  }

  async function* files() {
    for (const entry of entries) {
      let response: Response | null = null
      try {
        response = await fetch(entry.url, { signal })
      } catch (error) {
        if (signal.aborted) throw error
      }
      const reason = response ? problem(response) : 'the download failed'
      if (!response?.body || reason) {
        failed.push({ path: entry.path, reason: reason ?? 'the download failed' })
        await response?.body?.cancel()
      } else {
        yield { name: entry.path, input: response.body.pipeThrough(counter()) }
      }
      progress.files += 1
      onProgress({ ...progress })
    }
    yield { name: 'README.md', input: readme(title, origin, items, entries, failed) }
  }

  return { stream: makeZip(files()), failed }
}
