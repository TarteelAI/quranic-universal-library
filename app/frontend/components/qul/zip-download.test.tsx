import { fireEvent, render, screen, waitFor } from '@testing-library/react'
import { toast } from 'sonner'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import { Dialog, DialogContent, DialogDescription, DialogTitle } from '@/components/ui/overlays'
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

  it("keeps the caller's layout classes off the button", () => {
    const { rerender } = render(
      <ZipDownload
        title="Kit"
        items={[item(10)]}
        label="Download kit"
        signInHref="/users/sign_in"
        className="items-start sm:items-end"
      />,
    )
    const link = screen.getByRole('link', { name: 'Sign in to download' })
    expect(link.className).toContain('items-center')
    expect(link.className).not.toMatch(/items-(start|end)/)
    expect(link.parentElement?.className).toContain('sm:items-end')

    rerender(
      <ZipDownload title="Kit" items={[item(10)]} label="Download kit" signInHref={null} className="sm:items-end" />,
    )
    expect(screen.getByRole('button', { name: 'Download kit' }).className).not.toContain('items-end')
  })

  it('looks the items up, shows the progress and saves the zip under the title', async () => {
    const { finish, progress } = stubZip()
    const success = vi.spyOn(toast, 'success')
    const lookup = vi.fn(() => Promise.resolve([item(2048)]))
    render(<ZipDownload title="Recitation kit" items={lookup} label="Download kit" signInHref={null} />)

    fireEvent.click(screen.getByRole('button', { name: 'Download kit' }))
    await screen.findByRole('progressbar', { name: 'Zip progress' })
    expect(lookup).toHaveBeenCalledTimes(1)
    expect(screen.getByRole('status').textContent).toBe('Making the zip…')
    // The progress covers the button, which keeps its box and can be neither reached nor clicked.
    expect(screen.getByText('Download kit').closest('button')?.hasAttribute('inert')).toBe(true)
    progress({ files: 0, bytes: 1024 })
    await waitFor(() =>
      expect(screen.getByRole('progressbar').getAttribute('aria-valuetext')).toBe('0 of 1 files, 1 KB of 2 KB'),
    )
    expect(screen.getByText(/^1 of 1 files/).textContent).toBe('1 of 1 files · 1 KB of 2 KB')

    // Every file is fetched: the zip is being finished until the save is done, and cannot be cancelled.
    progress({ files: 1, bytes: 2048 })
    await screen.findByText('Finishing the zip…', { selector: '[aria-hidden]' })
    expect(screen.getByRole('status').textContent).toBe('Finishing the zip…')
    expect(screen.queryByRole('button', { name: 'Cancel the zip' })).toBeNull()
    expect(success).not.toHaveBeenCalled()

    finish()
    await waitFor(() => expect(saved).toEqual(['recitation-kit.zip']))
    expect(success).toHaveBeenCalledWith('recitation-kit.zip is downloaded.', expect.anything())
    expect(screen.queryByRole('progressbar')).toBeNull()
  })

  it('starts one zip when the button is clicked again during the lookup', async () => {
    const { finish } = stubZip()
    let resolve: (items: CatalogBundleItem[]) => void = () => {}
    const lookup = vi.fn(() => new Promise<CatalogBundleItem[]>((r) => (resolve = r)))
    render(<ZipDownload title="Kit" items={lookup} label="Download kit" signInHref={null} />)

    fireEvent.click(screen.getByRole('button', { name: 'Download kit' }))
    fireEvent.click(screen.getByRole('button', { name: 'Download kit' }))
    resolve([item(10)])
    await screen.findByRole('progressbar', { name: 'Zip progress' })
    finish()
    await waitFor(() => expect(saved).toEqual(['kit.zip']))
    expect(lookup).toHaveBeenCalledTimes(1)
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

  it('goes on and saves the zip when it leaves the page (the tray closes)', async () => {
    const { finish } = stubZip()
    const { unmount } = render(
      <ZipDownload title="QUL bundle" items={[item(10)]} label="Download bundle" signInHref={null} />,
    )

    fireEvent.click(screen.getByRole('button', { name: 'Download bundle' }))
    await screen.findByRole('progressbar')
    unmount()
    finish()

    await waitFor(() => expect(saved).toEqual(['qul-bundle.zip']))
  })

  it("removes the file Chromium's save dialog made when there is nothing to zip", async () => {
    const remove = vi.fn(() => Promise.resolve())
    const picker = vi.fn(() => Promise.resolve({ createWritable: vi.fn(), remove }))
    vi.stubGlobal('showSaveFilePicker', picker)
    const error = vi.spyOn(toast, 'error')
    const restricted = { ...item(10), restricted: true, files: [] }
    render(
      <ZipDownload title="Kit" items={() => Promise.resolve([restricted])} label="Download kit" signInHref={null} />,
    )

    fireEvent.click(screen.getByRole('button', { name: 'Download kit' }))

    await waitFor(() => expect(error).toHaveBeenCalledWith('There are no files to download.'))
    expect(picker).toHaveBeenCalledWith(expect.objectContaining({ suggestedName: 'kit.zip' }))
    expect(remove).toHaveBeenCalledTimes(1)
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
    const cancel = await screen.findByRole('button', { name: 'Cancel the zip' })
    await waitFor(() => expect(document.activeElement).toBe(cancel))
    fireEvent.click(cancel)

    await waitFor(() => expect(screen.queryByRole('progressbar')).toBeNull())
    expect(screen.getByRole('button', { name: 'Download kit' }).hasAttribute('inert')).toBe(false)
    expect(document.activeElement).toBe(screen.getByRole('button', { name: 'Download kit' }))
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

    // Beside the button, not in the page's flow.
    const note = await screen.findByRole('dialog', { name: /^This is 500 MB, more than this browser can zip/ })
    expect(screen.getByRole('status').textContent).toMatch(/^This is 500 MB/)
    expect(screen.getByRole('button', { name: 'Add kit to bundle' })).toBeDefined()
    expect(zipStream).not.toHaveBeenCalled()

    fireEvent.keyDown(note, { key: 'Escape' })
    await waitFor(() => expect(screen.queryByRole('dialog')).toBeNull())
    expect(document.activeElement).toBe(screen.getByRole('button', { name: 'Download kit' }))
  })

  describe('inside a modal dialog (the bundle tray)', () => {
    function Tray({ items }: { items: CatalogBundleItem[] }) {
      return (
        <Dialog open>
          <DialogContent side="right">
            <DialogTitle>Bundle</DialogTitle>
            <DialogDescription>Your bundle</DialogDescription>
            <ZipDownload title="QUL bundle" items={items} label="Download bundle" signInHref={null} />
          </DialogContent>
        </Dialog>
      )
    }

    it('hands the focus on from cancel to the finishing state and back to the button', async () => {
      const { finish, progress } = stubZip()
      render(<Tray items={[item(10)]} />)
      const download = screen.getByRole('button', { name: 'Download bundle' })
      download.focus()
      fireEvent.click(download)
      const cancel = await screen.findByRole('button', { name: 'Cancel the zip' })
      await waitFor(() => expect(document.activeElement).toBe(cancel))

      progress({ files: 1, bytes: 10 })
      await screen.findByText('Finishing the zip…', { selector: '[aria-hidden]' })
      await new Promise((resolve) => setTimeout(resolve, 0))
      expect(document.activeElement).toBe(screen.getByRole('status').parentElement)

      finish()
      await waitFor(() => expect(screen.queryByRole('progressbar')).toBeNull())
      await new Promise((resolve) => setTimeout(resolve, 0))
      expect(document.activeElement).toBe(screen.getByRole('button', { name: 'Download bundle' }))
    })

    it('gives the focus back to the button when the zip is cancelled', async () => {
      vi.spyOn(zip, 'zipStream').mockImplementation(async (options) => {
        const stream = new ReadableStream<Uint8Array>({
          start(controller) {
            options.signal.addEventListener('abort', () => controller.error(new DOMException('Aborted', 'AbortError')))
          },
        })
        return { stream, failed: [] }
      })
      render(<Tray items={[item(10)]} />)
      const download = screen.getByRole('button', { name: 'Download bundle' })
      download.focus()
      fireEvent.click(download)
      const cancel = await screen.findByRole('button', { name: 'Cancel the zip' })
      await waitFor(() => expect(document.activeElement).toBe(cancel))

      fireEvent.click(cancel)
      await waitFor(() => expect(screen.queryByRole('progressbar')).toBeNull())
      await new Promise((resolve) => setTimeout(resolve, 0))
      expect(document.activeElement).toBe(screen.getByRole('button', { name: 'Download bundle' }))
    })

    it('gives the focus back to the button when the too-big note closes', async () => {
      render(<Tray items={[item(zip.MEMORY_LIMIT + 1)]} />)
      const download = screen.getByRole('button', { name: 'Download bundle' })
      download.focus()
      fireEvent.click(download)
      const note = await screen.findByRole('dialog', { name: /more than this browser can zip/ })

      fireEvent.keyDown(note, { key: 'Escape' })
      await waitFor(() => expect(screen.queryByRole('dialog', { name: /more than this browser/ })).toBeNull())
      await new Promise((resolve) => setTimeout(resolve, 0))
      expect(document.activeElement).toBe(screen.getByRole('button', { name: 'Download bundle' }))
      expect(screen.getByRole('dialog', { name: 'Bundle' })).toBeDefined()
    })
  })
})
