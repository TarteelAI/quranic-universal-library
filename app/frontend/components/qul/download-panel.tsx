import { Link } from '@inertiajs/react'
import { DownloadIcon } from 'lucide-react'
import * as React from 'react'

import { Button } from '@/components/ui/button'
import { formatBytes } from '@/lib/format'
import { cn } from '@/lib/utils'
import { catalogDownload, catalogResource } from '@/routes'
import type { CatalogResourceFile, CatalogWorksWithGroup } from '@/types/serializers'

export interface DownloadPanelProps {
  /** The resource's type key and slug, for the download URLs */
  type: string
  slug: string
  files: CatalogResourceFile[]
  /** False for a restricted resource, unless the viewer is an admin */
  canDownload: boolean
  /** Why the resource is restricted, as sanitized HTML */
  restriction: string | null
  downloadMode: 'sign_in' | 'public'
  /** The sign-in link that returns to this page; null when the viewer is signed in */
  signInHref: string | null
  facts?: { label: string; value: string }[]
  className?: string
}

// The side panel of a resource detail page, from the v7 DownloadPanel
// (ds/src/components/qul/data.tsx): pick a format, then download one of its files. Each download
// is a plain link to the download route, which counts it and sends the file (or, in sign-in
// mode, sends an anonymous visitor to sign in first).
export function DownloadPanel({
  type,
  slug,
  files,
  canDownload,
  restriction,
  downloadMode,
  signInHref,
  facts = [],
  className,
}: DownloadPanelProps) {
  const formats = [...new Map(files.map((file) => [file.format, file.formatLabel])).entries()]
  const [format, setFormat] = React.useState(formats[0]?.[0])
  const shown = files.filter((file) => file.format === format)

  return (
    <aside aria-label="Download" className={cn('flex flex-col gap-5 rounded-xl bg-card p-5 shadow-xs', className)}>
      {files.length === 0 ? (
        <p className="text-sm text-muted-foreground">This resource has no files to download yet.</p>
      ) : (
        <>
          {formats.length > 1 && (
            <div role="group" aria-label="Format">
              <p className="mb-2 text-sm text-muted-foreground">Format</p>
              <div className="flex flex-wrap gap-1.5">
                {formats.map(([key, label]) => (
                  <button
                    key={key}
                    type="button"
                    aria-pressed={key === format}
                    onClick={() => setFormat(key)}
                    className={cn(
                      'inline-flex h-9 cursor-pointer items-center rounded-lg border bg-card px-3.5 font-mono text-xs font-medium tracking-wide text-muted-foreground uppercase transition-colors hover:border-foreground/30 hover:text-foreground',
                      key === format && 'border-foreground text-foreground ring-1 ring-foreground',
                    )}
                  >
                    {label}
                  </button>
                ))}
              </div>
            </div>
          )}

          {restriction && (
            <div
              className="rounded-lg bg-warning-subtle p-4 text-sm text-warning [&_a]:underline [&_h5]:font-medium"
              dangerouslySetInnerHTML={{ __html: restriction }}
            />
          )}

          <ul aria-label="Files" className="flex flex-col divide-y">
            {shown.map((file) => (
              <li key={file.id} className="flex flex-col gap-2 py-3 first:pt-0 last:pb-0">
                <div className="flex items-baseline justify-between gap-3">
                  <span className="min-w-0 font-medium break-words">{file.name}</span>
                  <span
                    className="shrink-0 text-sm text-muted-foreground tabular-nums"
                    title={`${file.byteSize} bytes`}
                  >
                    {formatBytes(file.byteSize)}
                  </span>
                </div>
                <p className="font-mono text-[11px] break-all text-muted-foreground">
                  <span className="font-sans">{file.formatLabel} · MD5 (hex)</span> {file.md5}
                </p>
                {canDownload && (
                  <Button asChild size="sm" className="w-full">
                    <a
                      href={catalogDownload({ type, slug, fileId: file.id }).url}
                      rel="nofollow"
                      aria-label={`Download ${file.name}, ${formatBytes(file.byteSize)}`}
                    >
                      <DownloadIcon aria-hidden="true" /> Download
                    </a>
                  </Button>
                )}
              </li>
            ))}
          </ul>

          {canDownload && signInHref && (
            <p className="text-sm text-muted-foreground">
              {downloadMode === 'sign_in' ? (
                'Downloads need a free account. After you sign in, you come back here and the download starts.'
              ) : (
                <>
                  <a href={signInHref} className="text-foreground underline underline-offset-2">
                    Sign in
                  </a>{' '}
                  to get an email when this resource is updated.
                </>
              )}
            </p>
          )}
        </>
      )}

      {facts.length > 0 && (
        <dl className="grid grid-cols-[auto_1fr] gap-x-4 gap-y-2 border-t pt-4 text-sm">
          {facts.map((fact) => (
            <React.Fragment key={fact.label}>
              <dt className="text-muted-foreground">{fact.label}</dt>
              <dd className="text-right">{fact.value}</dd>
            </React.Fragment>
          ))}
        </dl>
      )}
    </aside>
  )
}

export interface WorksWithProps {
  groups: CatalogWorksWithGroup[]
  className?: string
}

// The resources a resource is linked with, by relation: what it requires first, then what it
// pairs with. A link a backfill drafted is marked as not yet reviewed.
export function WorksWith({ groups, className }: WorksWithProps) {
  if (groups.length === 0) return null

  return (
    <section
      aria-labelledby="works-with"
      className={cn('flex flex-col gap-4 rounded-xl bg-card p-5 shadow-xs', className)}
    >
      <h2 id="works-with" className="text-sm text-muted-foreground">
        Works with
      </h2>
      {groups.map((group) => (
        <div key={group.key} className="flex flex-col gap-1.5">
          <h3 className="text-xs font-medium tracking-wide text-muted-foreground uppercase">{group.label}</h3>
          <ul aria-label={group.label} className="flex flex-col gap-1.5">
            {group.links.map((link) => (
              <li key={link.resource.id}>
                <Link
                  href={catalogResource({ type: link.resource.type, slug: link.resource.toParam }).url}
                  className="flex flex-col rounded-lg bg-surface p-2.5 text-sm hover:bg-secondary"
                >
                  <span className="font-medium">{link.resource.name}</span>
                  <span className="text-xs text-muted-foreground">
                    {link.typeLabel}
                    {!link.reviewed && ' · not yet reviewed'}
                  </span>
                </Link>
              </li>
            ))}
          </ul>
        </div>
      ))}
    </section>
  )
}
