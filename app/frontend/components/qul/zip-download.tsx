import { DownloadIcon, LoaderCircleIcon, XIcon } from 'lucide-react'
import { Popover } from 'radix-ui'
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
}) => Promise<SavedFile>
// remove() is newer than the dialog: Chromium 110.
type SavedFile = { createWritable: () => Promise<WritableStream<Uint8Array>>; remove?: () => Promise<void> }

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
  /** Classes for the component's box in its parent's layout; they never reach the button */
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
 * A button that downloads resources as one zip built in the browser (lib/zip-download.ts). While
 * the zip runs, its progress and a cancel button take the button's place in the same box, so
 * nothing around it moves; once every file is fetched it says the zip is being finished until the
 * save is done (Chromium closing the picked file can take seconds for a large zip). Files that
 * cannot be fetched are left out and named in the zip's README. Only the cancel button stops a
 * zip: one started in the bundle tray goes on when the tray closes, and ends in the same toast.
 */
export function ZipDownload({ title, items, formats = null, label, signInHref, tooBig, className }: ZipDownloadProps) {
  const [status, setStatus] = React.useState<State>({ state: 'idle' })
  const controller = React.useRef<AbortController | null>(null)
  const root = React.useRef<HTMLDivElement>(null)
  const button = React.useRef<HTMLButtonElement>(null)
  const cancel = React.useRef<HTMLButtonElement>(null)
  const progressBox = React.useRef<HTMLDivElement>(null)

  const running = status.state === 'running'
  // Every file is fetched: what is left is the README and saving the zip.
  const finishing = running && status.progress.files >= status.files
  let phase: 'idle' | 'running' | 'finishing' = 'idle'
  if (finishing) phase = 'finishing'
  else if (running) phase = 'running'

  // The control that had the focus is hidden or removed when the phase changes; its successor
  // takes it, unless the visitor has moved the focus elsewhere.
  const lastPhase = React.useRef(phase)
  React.useEffect(() => {
    if (lastPhase.current === phase) return
    lastPhase.current = phase
    const active = document.activeElement
    if (active && active !== document.body && !root.current?.contains(active)) return
    const next = { idle: button, running: cancel, finishing: progressBox }[phase]
    next.current?.focus({ preventScroll: true })
  }, [phase])

  // The caller's classes place this box; the button inside always fills it.
  const box = cn('relative grid min-w-44', className)

  if (signInHref)
    return (
      <div className={box}>
        <Button asChild>
          <a href={signInHref}>
            <DownloadIcon /> Sign in to download
          </a>
        </Button>
      </div>
    )

  async function start() {
    // The button is inert only once the zip runs: a click during the save dialog or the lookup
    // would start a second zip and leave this one without a cancel button.
    if (controller.current) return
    const abort = new AbortController()
    controller.current = abort
    const name = zipName(title)
    // Chromium makes the picked file when the dialog closes; one that gets no zip is removed.
    let handle: SavedFile | null = null
    const discard = () => handle?.remove?.().catch(() => {})
    try {
      // The save dialog first: it needs the click that started it.
      const picker = canStream()
        ? (window as unknown as { showSaveFilePicker: SaveFilePicker }).showSaveFilePicker
        : null
      handle = picker
        ? await picker({
            suggestedName: name,
            types: [{ description: 'Zip', accept: { 'application/zip': ['.zip'] } }],
          })
        : null
      const resolved = typeof items === 'function' ? await items() : items
      const entries = zipEntries(resolved, formats)
      const bytes = totalBytes(entries)
      if (entries.length === 0) {
        await discard()
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
      await discard()
      if (isAbort(error)) return
      console.warn(error)
      toast.error('The zip could not be made. Try again later.', { id: 'zip-download' })
    } finally {
      if (controller.current === abort) controller.current = null
    }
  }

  const percent = running ? Math.min(100, (status.progress.bytes / Math.max(status.bytes, 1)) * 100) : 0

  return (
    <Popover.Root open={status.state === 'too-big'} onOpenChange={(open) => !open && setStatus({ state: 'idle' })}>
      <Popover.Anchor asChild>
        <div ref={root} className={cn(box, '@container')}>
          <Button ref={button} onClick={start} inert={running} className={cn(running && 'invisible')}>
            <DownloadIcon /> {label}
          </Button>
          {running && (
            <div
              ref={progressBox}
              tabIndex={-1}
              className="absolute inset-0 flex items-center gap-2 overflow-hidden rounded-lg border bg-card ps-3 pe-1 text-xs outline-none"
            >
              <span className="sr-only" role="status">
                {finishing ? 'Finishing the zip…' : 'Making the zip…'}
              </span>
              {finishing ? (
                <>
                  <LoaderCircleIcon
                    aria-hidden="true"
                    className="size-3.5 shrink-0 animate-spin text-muted-foreground"
                  />
                  <span aria-hidden="true" className="min-w-0 flex-1 truncate">
                    Finishing the zip…
                  </span>
                </>
              ) : (
                <>
                  <span aria-hidden="true" className="min-w-0 flex-1 truncate tabular-nums">
                    {Math.min(status.progress.files + 1, status.files)} of {status.files} files
                    <span className="hidden text-muted-foreground @3xs:inline">
                      {' '}
                      · {formatBytes(status.progress.bytes)} of {formatBytes(status.bytes)}
                    </span>
                  </span>
                  <button
                    ref={cancel}
                    type="button"
                    onClick={() => controller.current?.abort()}
                    aria-label="Cancel the zip"
                    className="flex size-8 shrink-0 cursor-pointer items-center justify-center rounded-md text-muted-foreground outline-none hover:bg-secondary hover:text-foreground focus-visible:ring-[3px] focus-visible:ring-ring/50"
                  >
                    <XIcon className="size-4" />
                  </button>
                </>
              )}
              <div
                role="progressbar"
                aria-label="Zip progress"
                aria-valuemin={0}
                aria-valuemax={status.bytes}
                aria-valuenow={status.progress.bytes}
                aria-valuetext={`${Math.min(status.progress.files, status.files)} of ${status.files} files, ${formatBytes(status.progress.bytes)} of ${formatBytes(status.bytes)}`}
                className="absolute inset-x-0 bottom-0 h-1 bg-secondary"
              >
                <div className="h-full bg-brand transition-[width]" style={{ width: `${percent}%` }} />
              </div>
            </div>
          )}
        </div>
      </Popover.Anchor>
      <Popover.Portal>
        <Popover.Content
          side="bottom"
          align="end"
          sideOffset={8}
          collisionPadding={16}
          className="z-50 flex w-72 max-w-[calc(100vw-2rem)] flex-col items-start gap-3 rounded-lg border bg-card p-4 text-sm text-muted-foreground shadow-md outline-none"
        >
          {status.state === 'too-big' && (
            <p>
              This is {formatBytes(status.bytes)}, more than this browser can zip. Chrome and Edge can, or download each
              file on its own.
            </p>
          )}
          {tooBig}
        </Popover.Content>
      </Popover.Portal>
    </Popover.Root>
  )
}
