import { fireEvent, render, screen, waitFor } from '@testing-library/react'
import { toast } from 'sonner'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import * as zip from '@/lib/zip-download'
import type { CatalogBundleItem } from '@/types/serializers'

import { ZipDownload } from './zip-download'

const item = (byteSize: number): CatalogBundleItem => ({
  id: 1,
  restricted: false,
  resource: { id: 1, name: 'Surah names', type: 'quran-metadata', toParam: 'surah-names' },
  category: 'metadata',
  files: [
    { id: 11, name: 'json', filename: 'surah-name.json.zip', format: 'json', formatLabel: 'JSON', byteSize, md5: 'a' },
  ],
  licence: null,
})

// The zip itself is lib/zip-download.test.ts's; here it is a stream the test ends when it likes.
function stubZip(failed: zip.Failure[] = []) {
  let finish: () => void = () => {}
  let report: zip.ZipOptions['onProgress'] = () => {}
  const stream = new ReadableStream<Uint8Array>({
    start(controller) {
      finish = () => {
        controller.enqueue(new Uint8Array([80, 75]))
        controller.close()
      }
    },
  })
  vi.spyOn(zip, 'zipStream').mockImplementation(async (options) => {
    report = options.onProgress
    return { stream, failed }
  })
  return { finish: () => finish(), progress: (progress: zip.Progress) => report(progress) }
}

let saved: string[]
beforeEach(() => {
  saved = []
  vi.stubGlobal('URL', Object.assign(URL, { createObjectURL: () => 'blob:zip', revokeObjectURL: () => {} }))
  vi.spyOn(HTMLAnchorElement.prototype, 'click').mockImplementation(function (this: HTMLAnchorElement) {
    saved.push(this.download)
  })
})
afterEach(() => {
  vi.unstubAllGlobals()
  vi.restoreAllMocks()
})

describe('ZipDownload', () => {
  it('links to sign-in while downloads need an account', () => {
    render(<ZipDownload title="Kit" items={[item(10)]} label="Download kit" signInHref="/users/sign_in?x=1" />)

    expect(screen.getByRole('link', { name: 'Sign in to download' }).getAttribute('href')).toBe('/users/sign_in?x=1')
  })

  it('looks the items up, shows the progress and saves the zip under the title', async () => {
    const { finish, progress } = stubZip()
    const success = vi.spyOn(toast, 'success')
    const lookup = vi.fn(() => Promise.resolve([item(2048)]))
    render(<ZipDownload title="Recitation kit" items={lookup} label="Download kit" signInHref={null} />)

    fireEvent.click(screen.getByRole('button', { name: 'Download kit' }))
    await screen.findByRole('progressbar', { name: 'Zip progress' })
    expect(lookup).toHaveBeenCalledTimes(1)
    expect(screen.getByRole('button', { name: 'Making the zip…' })).toHaveProperty('disabled', true)
    progress({ files: 0, bytes: 1024 })
    await screen.findByText('1 of 1 files · 1 KB of 2 KB')

    finish()
    await waitFor(() => expect(saved).toEqual(['recitation-kit.zip']))
    expect(success).toHaveBeenCalledWith('recitation-kit.zip is downloaded.', expect.anything())
    expect(screen.queryByRole('progressbar')).toBeNull()
  })

  it('says how many files are in the zip when some failed', async () => {
    const { finish } = stubZip([{ path: 'a', reason: 'no longer available' }])
    const warning = vi.spyOn(toast, 'warning')
    render(
      <ZipDownload
        title="QUL bundle"
        items={[item(10), { ...item(10), id: 2 }]}
        label="Download bundle"
        signInHref={null}
      />,
    )

    fireEvent.click(screen.getByRole('button', { name: 'Download bundle' }))
    await screen.findByRole('progressbar')
    finish()
    await waitFor(() =>
      expect(warning).toHaveBeenCalledWith(
        '1 of 2 files are in qul-bundle.zip. Its README.md lists the others.',
        expect.anything(),
      ),
    )
  })

  it('cancels', async () => {
    let signal: AbortSignal | undefined
    vi.spyOn(zip, 'zipStream').mockImplementation(async (options) => {
      signal = options.signal
      const stream = new ReadableStream<Uint8Array>({
        start(controller) {
          options.signal.addEventListener('abort', () => controller.error(new DOMException('Aborted', 'AbortError')))
        },
      })
      return { stream, failed: [] }
    })
    const error = vi.spyOn(toast, 'error')
    render(<ZipDownload title="Kit" items={[item(10)]} label="Download kit" signInHref={null} />)

    fireEvent.click(screen.getByRole('button', { name: 'Download kit' }))
    fireEvent.click(await screen.findByRole('button', { name: 'Cancel the zip' }))

    await waitFor(() => expect(screen.getByRole('button', { name: 'Download kit' })).toHaveProperty('disabled', false))
    expect(signal?.aborted).toBe(true)
    expect(saved).toEqual([])
    expect(error).not.toHaveBeenCalled()
  })

  it('offers the other way when the zip is too big for this browser to hold', async () => {
    const zipStream = vi.spyOn(zip, 'zipStream')
    render(
      <ZipDownload
        title="Kit"
        items={[item(zip.MEMORY_LIMIT + 1)]}
        label="Download kit"
        signInHref={null}
        tooBig={<button type="button">Add kit to bundle</button>}
      />,
    )

    fireEvent.click(screen.getByRole('button', { name: 'Download kit' }))

    expect((await screen.findByRole('status')).textContent).toMatch(/^This is 500 MB, more than this browser can zip/)
    expect(screen.getByRole('button', { name: 'Add kit to bundle' })).toBeDefined()
    expect(zipStream).not.toHaveBeenCalled()
  })
})
