import { usePage } from '@inertiajs/react'
import { CheckIcon, DownloadIcon, PackagePlusIcon, PlusIcon, XIcon } from 'lucide-react'
import * as React from 'react'

import { CopyButton } from '@/components/qul/copy-button'
import { Button } from '@/components/ui/button'
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from '@/components/ui/overlays'
import { addToBundle, removeFromBundle, toggleInBundle, useBundle } from '@/lib/bundle'
import { formatBytes } from '@/lib/format'
import { cn } from '@/lib/utils'
import { catalogBundle, catalogDownload, detailResources, newUserSession } from '@/routes'
import type { CatalogBundle, CatalogBundleItem, CatalogResourceRef } from '@/types/serializers'

import { QulIcon, ResourceIcon } from './icons'
import { NavAnchor } from './nav'

// The bundle tray, from the v8 design (ds/src/components/qul/chrome.tsx, BundleTray, and
// ds/src/app/shell.tsx): a visitor collects resources from cards, kit pages and detail pages, and
// the tray lists each file with its own download link. The links are the download route every
// page uses, so the download rules and the counting are the same; there is no zip. The bundle
// is browser state (lib/bundle.ts) and exists while the catalog pages are new pages (nav.bundle).

function useBundleEnabled() {
  return usePage().props.nav.bundle
}

/** The + / check on a resource card that adds the resource to the bundle or takes it out. */
export function BundleToggle({ id, name }: { id: number; name: string }) {
  const bundle = useBundle()
  const enabled = useBundleEnabled()
  if (!enabled) return null
  const inBundle = bundle.includes(id)

  return (
    <Button
      size="icon-sm"
      variant={inBundle ? 'default' : 'outline'}
      onClick={() => toggleInBundle(id)}
      aria-pressed={inBundle}
      aria-label={inBundle ? `Remove ${name} from bundle` : `Add ${name} to bundle`}
      className="relative z-10 shrink-0"
    >
      {inBundle ? <CheckIcon /> : <PlusIcon />}
    </Button>
  )
}

export interface AddToBundleProps {
  /** The resources the button adds: one on a detail page, every item on a kit page */
  ids: number[]
  /** Its label while some are not in the bundle */
  label?: string
  /** Its label once all are in the bundle; a press then takes them out */
  addedLabel?: string
  className?: string
}

/** A full-width button for a detail page or a kit: adds the resources, or takes them out again. */
export function AddToBundle({
  ids,
  label = 'Add to bundle',
  addedLabel = 'In your bundle',
  className,
}: AddToBundleProps) {
  const bundle = useBundle()
  const enabled = useBundleEnabled()
  if (!enabled || ids.length === 0) return null
  const allIn = ids.every((id) => bundle.includes(id))

  return (
    <Button
      variant="outline"
      aria-pressed={allIn}
      className={className}
      onClick={() => (allIn ? ids.forEach(removeFromBundle) : addToBundle(ids))}
    >
      {allIn ? <CheckIcon /> : <PackagePlusIcon />}
      {allIn ? addedLabel : label}
    </Button>
  )
}

type Lookup = { state: 'loading' } | { state: 'failed' } | { state: 'loaded'; bundle: CatalogBundle }

// Asks the server what the ids are now, again whenever an id is added that the last answer did
// not hold. A removed id is only hidden.
function useLookup(ids: number[], open: boolean): Lookup {
  const [answer, setAnswer] = React.useState<{ bundle: CatalogBundle | null; failed: string | null }>({
    bundle: null,
    failed: null,
  })
  const known = answer.bundle?.items.map((item) => item.id) ?? []
  const stale = ids.some((id) => !known.includes(id))
  const query = ids.join(',')

  React.useEffect(() => {
    if (!open || !stale || !query) return
    const controller = new AbortController()
    fetch(catalogBundle({ query: { ids: query } }).url, {
      headers: { Accept: 'application/json' },
      signal: controller.signal,
    })
      .then((response) => {
        if (!response.ok) throw new Error(`Bundle lookup failed: ${response.status}`)
        return response.json() as Promise<CatalogBundle>
      })
      .then((bundle) => setAnswer({ bundle, failed: null }))
      .catch((error: unknown) => {
        if (controller.signal.aborted) return
        console.warn(error)
        setAnswer((current) => ({ ...current, failed: query }))
      })
    return () => controller.abort()
  }, [open, stale, query])

  if (answer.failed === query) return { state: 'failed' }
  if (answer.bundle && !stale) return { state: 'loaded', bundle: answer.bundle }
  return { state: 'loading' }
}

function downloadPath(resource: CatalogResourceRef, fileId: number) {
  return catalogDownload({ type: resource.type, slug: resource.toParam, fileId }).url
}

/** The bundle as text to paste somewhere: each resource's name, then the URL of each of its files. */
export function bundleText(items: CatalogBundleItem[], origin: string) {
  return items
    .flatMap(({ resource, files }) =>
      resource && files.length > 0
        ? [[resource.name, ...files.map((file) => `${origin}${downloadPath(resource, file.id)}`)].join('\n')]
        : [],
    )
    .join('\n\n')
}

function RemoveButton({ id, name }: { id: number; name: string }) {
  return (
    <button
      type="button"
      aria-label={`Remove ${name} from bundle`}
      onClick={() => removeFromBundle(id)}
      className="flex size-7 shrink-0 cursor-pointer items-center justify-center rounded-full text-muted-foreground hover:bg-secondary hover:text-foreground"
    >
      <XIcon className="size-3.5" />
    </button>
  )
}

function BundleEntry({ item }: { item: CatalogBundleItem }) {
  const { resource } = item
  if (!resource)
    return (
      <li className="flex items-center gap-3 py-3" data-testid="bundle-item">
        <div className="min-w-0 flex-1">
          <p className="text-sm font-medium">Unavailable</p>
          <p className="text-xs text-muted-foreground">This resource is no longer in the library.</p>
        </div>
        <RemoveButton id={item.id} name="the unavailable resource" />
      </li>
    )

  const note = item.restricted
    ? 'Unavailable: the publisher does not allow downloads. See its page.'
    : item.files.length === 0 && 'Unavailable: this resource has no files to download now.'

  return (
    <li className="flex flex-col gap-2 py-3" data-testid="bundle-item">
      <div className="flex items-center gap-3">
        <ResourceIcon category={item.category ?? 'metadata'} size="sm" />
        <NavAnchor
          link={{ href: detailResources({ type: resource.type, id: resource.toParam }).url, inertia: true }}
          className="min-w-0 flex-1 truncate text-sm font-medium hover:underline"
        >
          {resource.name}
        </NavAnchor>
        <RemoveButton id={item.id} name={resource.name} />
      </div>
      {note ? (
        <p className="ps-9 text-xs text-muted-foreground">{note}</p>
      ) : (
        <ul aria-label={`Files of ${resource.name}`} className="flex flex-col gap-1 ps-9">
          {item.files.map((file) => (
            <li key={file.id}>
              <a
                href={downloadPath(resource, file.id)}
                rel="nofollow"
                aria-label={`Download ${file.name}, ${formatBytes(file.byteSize)}`}
                className="flex items-center gap-2 rounded-md py-1 text-xs text-muted-foreground hover:text-foreground"
              >
                <DownloadIcon className="size-3.5 shrink-0" aria-hidden="true" />
                <span className="min-w-0 flex-1 truncate font-mono">{file.name}</span>
                <span className="shrink-0 tabular-nums">{formatBytes(file.byteSize)}</span>
              </a>
            </li>
          ))}
        </ul>
      )}
    </li>
  )
}

/** What the tray shows for the ids it holds: the list, the copy button and the sign-in note. */
function BundleContents({ ids, lookup }: { ids: number[]; lookup: Lookup }) {
  const { url, props } = usePage()
  if (ids.length === 0)
    return (
      <p className="rounded-xl border border-dashed p-8 text-center text-sm text-muted-foreground">
        Nothing here yet. Use <span className="font-medium text-foreground">+</span> on any resource card.
      </p>
    )
  if (lookup.state === 'failed')
    return <p className="text-sm text-muted-foreground">The bundle could not be loaded. Try again later.</p>
  if (lookup.state === 'loading') return <p className="text-sm text-muted-foreground">Loading your bundle…</p>

  const items = lookup.bundle.items.filter((item) => ids.includes(item.id))
  const signIn = lookup.bundle.downloadMode === 'sign_in' && !props.auth.user

  return (
    <div className="flex min-h-0 flex-col gap-4">
      <ul aria-label="Resources in your bundle" className="flex min-h-0 flex-col divide-y overflow-y-auto">
        {items.map((item) => (
          <BundleEntry key={item.id} item={item} />
        ))}
      </ul>
      <div className="flex items-center justify-between gap-3 border-t pt-4">
        <p className="text-sm text-muted-foreground">Copy the list of names and download links.</p>
        <CopyButton text={() => bundleText(items, window.location.origin)} label="Copy list" />
      </div>
      {signIn && (
        <p className="text-sm text-muted-foreground">
          Downloads need a free account.{' '}
          <a
            href={newUserSession({ query: { user_return_to: url } }).url}
            className="text-foreground underline underline-offset-2"
          >
            Sign in
          </a>{' '}
          first, then download each file.
        </p>
      )}
    </div>
  )
}

/** The header's Bundle button with the count, and the tray it opens. */
export function BundleTray({ className }: { className?: string }) {
  const ids = useBundle()
  const [open, setOpen] = React.useState(false)
  const lookup = useLookup(ids, open)
  const enabled = useBundleEnabled()
  if (!enabled) return null

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button
          variant="ghost"
          size="sm"
          className={cn('relative', className)}
          aria-label={`Bundle, ${ids.length} ${ids.length === 1 ? 'resource' : 'resources'}`}
        >
          <QulIcon name="bundle" size={18} />
          <span className="hidden xl:inline">Bundle</span>
          {ids.length > 0 && (
            <span
              data-testid="bundle-count"
              className="flex h-5 min-w-5 items-center justify-center rounded-full bg-brand px-1.5 text-[11px] font-semibold text-foreground"
            >
              {ids.length}
            </span>
          )}
        </Button>
      </DialogTrigger>
      <DialogContent side="right" className="bg-background">
        <DialogHeader>
          <DialogTitle>Bundle</DialogTitle>
          <DialogDescription>
            Collect resources from anywhere on QUL, then download each file from this list.
          </DialogDescription>
        </DialogHeader>
        <BundleContents ids={ids} lookup={lookup} />
      </DialogContent>
    </Dialog>
  )
}
