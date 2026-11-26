import { DownloadIcon, XIcon } from 'lucide-react'
import * as React from 'react'
import { toast } from 'sonner'

import { Button } from '@/components/ui/button'
import { formatBytes } from '@/lib/format'
import { cn } from '@/lib/utils'
import { canStream, MEMORY_LIMIT, type Progress, totalBytes, zipEntries, zipName, zipStream } from '@/lib/zip-download'
import type { CatalogBundleItem } from '@/types/serializers'

// The save dialog of Chromium (the File System Access API), which the DOM types do not include.
type SaveFilePicker = (options: {
  suggestedName: string
  types: { description: string; accept: Record<string, string[]> }[]
}) => Promise<{ createWritable: () => Promise<WritableStream<Uint8Array>> }>

type State =
  | { state: 'idle' }
  | { state: 'running'; progress: Progress; files: number; bytes: number }
  | { state: 'too-big'; bytes: number }

export interface ZipDownloadProps {
  /** The zip's title: its README heading and, as a slug, its file name */
  title: string
  /** The resources to zip, or a function that looks them up when the zip starts */
  items: CatalogBundleItem[] | (() => Promise<CatalogBundleItem[]>)
  /** Only these file formats of a resource that has some (the bundle tray's filter) */
  formats?: string[] | null
  label: string
  /** The sign-in link while downloads need an account the visitor is not signed in with */
  signInHref: string | null
  /** What else to offer when the zip is too big for this browser to hold in memory */
  tooBig?: React.ReactNode
  className?: string
}

const isAbort = (error: unknown) => error instanceof DOMException && error.name === 'AbortError'

function saveBlob(blob: Blob, name: string) {
  const url = URL.createObjectURL(blob)
  const link = document.createElement('a')
  link.href = url
  link.download = name
  link.click()
  setTimeout(() => URL.revokeObjectURL(url), 60_000)
}

/**
 * A button that downloads resources as one zip built in the browser (lib/zip-download.ts), with
 * its progress and a cancel button while it runs. Files that cannot be fetched are left out and
 * named in the zip's README.
 */
export function ZipDownload({ title, items, formats = null, label, signInHref, tooBig, className }: ZipDownloadProps) {
  const [status, setStatus] = React.useState<State>({ state: 'idle' })
  const controller = React.useRef<AbortController | null>(null)
  React.useEffect(() => () => controller.current?.abort(), [])

  if (signInHref)
    return (
      <Button asChild className={className}>
        <a href={signInHref}>
          <DownloadIcon /> Sign in to download
        </a>
      </Button>
    )

  async function start() {
    const abort = new AbortController()
    controller.current = abort
    const name = zipName(title)
    try {
      // The save dialog first: it needs the click that started it.
      const picker = canStream()
        ? (window as unknown as { showSaveFilePicker: SaveFilePicker }).showSaveFilePicker
        : null
      const handle = picker
        ? await picker({
            suggestedName: name,
            types: [{ description: 'Zip', accept: { 'application/zip': ['.zip'] } }],
          })
        : null
      const resolved = typeof items === 'function' ? await items() : items
      const entries = zipEntries(resolved, formats)
      const bytes = totalBytes(entries)
      if (entries.length === 0) {
        toast.error('There are no files to download.')
        return setStatus({ state: 'idle' })
      }
      if (!handle && bytes > MEMORY_LIMIT) return setStatus({ state: 'too-big', bytes })

      setStatus({ state: 'running', progress: { files: 0, bytes: 0 }, files: entries.length, bytes })
      const { stream, failed } = await zipStream({
        title,
        origin: window.location.origin,
        items: resolved,
        entries,
        signal: abort.signal,
        onProgress: (progress) =>
          setStatus((current) => (current.state === 'running' ? { ...current, progress } : current)),
      })
      if (handle) await stream.pipeTo(await handle.createWritable(), { signal: abort.signal })
      else saveBlob(await new Response(stream).blob(), name)

      if (failed.length === 0) toast.success(`${name} is downloaded.`, { id: 'zip-download' })
      else
        toast.warning(
          `${entries.length - failed.length} of ${entries.length} files are in ${name}. Its README.md lists the others.`,
          { id: 'zip-download' },
        )
      setStatus({ state: 'idle' })
    } catch (error) {
      setStatus({ state: 'idle' })
      if (isAbort(error)) return
      console.warn(error)
      toast.error('The zip could not be made. Try again later.', { id: 'zip-download' })
    } finally {
      if (controller.current === abort) controller.current = null
    }
  }

  const running = status.state === 'running'

  return (
    <div className={cn('flex flex-col gap-2', className)}>
      <Button onClick={start} disabled={running}>
        <DownloadIcon /> {running ? 'Making the zip…' : label}
      </Button>
      {running && (
        <div className="flex items-center gap-2 text-xs text-muted-foreground">
          <div
            role="progressbar"
            aria-label="Zip progress"
            aria-valuemin={0}
            aria-valuemax={status.bytes}
            aria-valuenow={status.progress.bytes}
            className="h-1.5 min-w-16 flex-1 overflow-hidden rounded-full bg-secondary"
          >
            <div
              className="h-full bg-brand transition-[width]"
              style={{ width: `${Math.min(100, (status.progress.bytes / Math.max(status.bytes, 1)) * 100)}%` }}
            />
          </div>
          <span className="shrink-0 tabular-nums">
            {Math.min(status.progress.files + 1, status.files)} of {status.files} files ·{' '}
            {formatBytes(status.progress.bytes)} of {formatBytes(status.bytes)}
          </span>
          <button
            type="button"
            onClick={() => controller.current?.abort()}
            aria-label="Cancel the zip"
            className="flex size-6 shrink-0 cursor-pointer items-center justify-center rounded-full hover:bg-secondary hover:text-foreground"
          >
            <XIcon className="size-3.5" />
          </button>
        </div>
      )}
      {status.state === 'too-big' && (
        <div className="flex max-w-sm flex-col gap-2 text-xs text-muted-foreground" role="status">
          <p>
            This is {formatBytes(status.bytes)}, more than this browser can zip. Chrome and Edge can, or download each
            file on its own.
          </p>
          {tooBig}
        </div>
      )}
    </div>
  )
}
