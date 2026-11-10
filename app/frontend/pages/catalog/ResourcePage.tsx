import { Deferred, router, usePage } from '@inertiajs/react'
import { FlagIcon } from 'lucide-react'
import * as React from 'react'

import { Container, SiteShell } from '@/components/layout'
import type { PreviewNavigation, PreviewQuery } from '@/components/previews/navigation'
import { Preview } from '@/components/previews/preview'
import { DownloadPanel, WorksWith } from '@/components/qul/download-panel'
import { ResourceIcon } from '@/components/qul/icons'
import { PageHeader } from '@/components/qul/page-header'
import { RecommendedBadge, StatusBadge } from '@/components/qul/status-badge'
import { Skeleton } from '@/components/ui/misc'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { catalogDownload, catalogResource, catalogType, newUserSession, resources as catalog } from '@/routes'
import type { CatalogResourcesShow } from '@/types/serializers'

type Tab = CatalogResourcesShow['tab']

const TAB_LABELS: Record<Tab, string> = { preview: 'Preview', data: 'Data', licence: 'Licence', changelog: 'Changelog' }

function NotYetReviewed() {
  return <span className="text-xs text-muted-foreground">(not yet reviewed)</span>
}

// The preview's keys in the query string (Previews::QUERY_KEYS).
const PREVIEW_KEYS = ['page', 'surah', 'from', 'to', 'view'] as const

function previewQuery(url: string): PreviewQuery {
  const params = new URL(url, 'http://localhost').searchParams
  return Object.fromEntries(PREVIEW_KEYS.flatMap((key) => (params.has(key) ? [[key, params.get(key) ?? '']] : [])))
}

// The URL of the page with a tab open (Preview has no `?tab=`) and the preview's own keys.
function pageUrl(resource: CatalogResourcesShow['resource'], tab: Tab, query: PreviewQuery) {
  return catalogResource(
    { type: resource.type, slug: resource.toParam },
    { query: tab === 'preview' ? query : { tab, ...query } },
  ).url
}

// /resources/:type/:slug: one resource with its files and download control, what it works with,
// and the Preview, Data, Licence and Changelog tabs. The open tab is `?tab=` (none for Preview).
export default function ResourcePage(props: CatalogResourcesShow) {
  const { resource, type, statuses, files, facts, worksWith, changelog, licence, tab } = props
  const { url, props: shared } = usePage()

  const tabs: Tab[] = ['preview', 'data', 'licence', ...(changelog.length > 0 ? (['changelog'] as const) : [])]
  const statusLabel = statuses.find((status) => status.key === resource.status)?.label ?? resource.status

  // The download sign-in returned for (`?download=<file id>`) runs in a hidden frame, so the
  // page stays. The frame lives in state for as long as the page stays mounted; the parameter
  // leaves the URL and the props (so the history entry), so neither a reload nor Back after
  // leaving the page downloads again.
  const [started] = React.useState(props.download)
  const startedFile = started === null ? undefined : files.find((file) => file.id === started)
  React.useEffect(() => {
    if (props.download === null) return
    router.replace({
      url: pageUrl(resource, tab, previewQuery(url)),
      props: (current) => ({ ...current, download: null }),
      preserveState: true,
      preserveScroll: true,
    })
  }, [props.download, resource, tab, url])
  const signInHref = shared.auth.user ? null : newUserSession({ query: { user_return_to: url } }).url

  function selectTab(value: string) {
    const next = value as Tab
    router.push({
      url: pageUrl(resource, next, previewQuery(url)),
      props: (current) => ({ ...current, tab: next }),
      preserveState: true,
      preserveScroll: true,
    })
  }

  // Preview pages and ranges reload the preview prop alone; the URL holds the page shown.
  const [previewLoading, setPreviewLoading] = React.useState(false)
  const navigation: PreviewNavigation = {
    navigate(query) {
      router.get(
        pageUrl(resource, 'preview', query),
        {},
        {
          only: ['preview'],
          preserveState: true,
          preserveScroll: true,
          onStart: () => setPreviewLoading(true),
          onFinish: () => setPreviewLoading(false),
        },
      )
    },
    showView(view, query) {
      router.push({
        url: pageUrl(resource, 'preview', query),
        props: (current) => ({
          ...current,
          preview: props.preview?.kind === 'font' ? { ...props.preview, view } : props.preview,
        }),
        preserveState: true,
        preserveScroll: true,
      })
    },
    loading: previewLoading,
  }

  return (
    <SiteShell>
      <Container className="pt-10 pb-2 sm:pt-12">
        <PageHeader
          breadcrumb={[
            { label: 'Resources', href: catalog.index().url },
            { label: type.title, href: catalogType(type.key).url },
            { label: resource.name },
          ]}
          eyebrow={
            <>
              <span className="inline-flex items-center gap-1.5 font-medium text-foreground">
                <ResourceIcon category={type.category.key} size="sm" />
                {type.label}
              </span>
              <span className="inline-flex items-center gap-1">
                <StatusBadge
                  status={resource.status}
                  label={statusLabel}
                  supersededBy={
                    resource.supersededBy && {
                      name: resource.supersededBy.name,
                      href: catalogResource({ type: resource.supersededBy.type, slug: resource.supersededBy.toParam })
                        .url,
                    }
                  }
                />
                {!resource.reviewed.status && <NotYetReviewed />}
              </span>
              {resource.recommendation && <RecommendedBadge reviewed={resource.recommendation === 'reviewed'} />}
              {resource.scriptFamily && (
                <span>
                  {resource.scriptFamily} {!resource.reviewed.scriptFamily && <NotYetReviewed />}
                </span>
              )}
              {resource.language && <span>{resource.language}</span>}
              <span>{licence ? licence.name : 'Licence not yet confirmed'}</span>
              {!props.canDownload && <span className="text-warning">View only</span>}
            </>
          }
          title={resource.name}
          description={
            resource.summary && (
              <>
                {resource.summary} {!resource.reviewed.summary && <NotYetReviewed />}
              </>
            )
          }
        />
      </Container>

      <Container className="grid gap-10 py-8 lg:grid-cols-[minmax(0,1fr)_320px]">
        <Tabs value={tab} onValueChange={selectTab} className="min-w-0">
          <TabsList variant="line" className="overflow-x-auto">
            {tabs.map((key) => (
              <TabsTrigger key={key} value={key}>
                {TAB_LABELS[key]}
              </TabsTrigger>
            ))}
          </TabsList>

          <TabsContent value="preview" className="flex flex-col gap-6 pt-6">
            {resource.info && (
              <div
                className="max-w-prose text-pretty [&_a]:underline [&_li]:ms-5 [&_ol]:list-decimal [&_p]:mb-3 [&_ul]:list-disc"
                dangerouslySetInnerHTML={{ __html: resource.info }}
              />
            )}
            <Deferred data="preview" fallback={<Skeleton className="h-64 rounded-xl" />}>
              <Preview preview={props.preview} navigation={navigation} />
            </Deferred>
          </TabsContent>

          <TabsContent value="data" className="flex flex-col gap-6 pt-6">
            <dl className="grid max-w-xl grid-cols-[auto_1fr] gap-x-6 gap-y-2 rounded-xl bg-card p-5 text-sm shadow-xs">
              {facts.map((fact) => (
                <React.Fragment key={fact.label}>
                  <dt className="text-muted-foreground">{fact.label}</dt>
                  <dd>{fact.value}</dd>
                </React.Fragment>
              ))}
            </dl>
            {props.guidePath && (
              <p className="text-sm">
                How the files are laid out and how to use them:{' '}
                <a href={props.guidePath} className="underline underline-offset-2">
                  the {type.label.toLowerCase()} guide
                </a>
                .
              </p>
            )}
          </TabsContent>

          <TabsContent value="licence" className="flex max-w-prose flex-col gap-3 pt-6">
            {licence ? (
              <>
                <h2 className="text-lg font-medium">{licence.name}</h2>
                {licence.summary && <p>{licence.summary}</p>}
                {licence.url && (
                  <a href={licence.url} target="_blank" rel="noopener" className="underline underline-offset-2">
                    Read the full licence
                  </a>
                )}
              </>
            ) : (
              <>
                <h2 className="text-lg font-medium">Licence not yet confirmed</h2>
                <p className="text-muted-foreground">
                  We have not confirmed the licence of this resource yet. Check the terms with its publisher before you
                  use it in a product.
                </p>
              </>
            )}
            {props.restriction && (
              <div
                className="rounded-lg bg-warning-subtle p-4 text-sm text-warning [&_a]:underline [&_h5]:font-medium"
                dangerouslySetInnerHTML={{ __html: props.restriction }}
              />
            )}
          </TabsContent>

          {changelog.length > 0 && (
            <TabsContent value="changelog" className="pt-6">
              <ol aria-label="Changelog" className="flex flex-col gap-5 border-s ps-5 text-sm">
                {changelog.map((change) => (
                  <li key={change.id} className="flex flex-col gap-1">
                    <span className="text-muted-foreground">{change.date}</span>
                    <a href={change.path} className="font-medium hover:underline">
                      {change.title}
                    </a>
                    <p className="text-muted-foreground">{change.excerpt}</p>
                  </li>
                ))}
              </ol>
            </TabsContent>
          )}
        </Tabs>

        <div className="flex min-w-0 flex-col gap-3 lg:sticky lg:top-20 lg:self-start">
          {startedFile && (
            <>
              <p role="status" className="rounded-lg bg-brand-subtle p-3 text-sm">
                Your download of {startedFile.name} has started.
              </p>
              <iframe
                hidden
                title={`Download of ${startedFile.name}`}
                src={catalogDownload({ type: resource.type, slug: resource.toParam, fileId: startedFile.id }).url}
              />
            </>
          )}
          <DownloadPanel
            type={resource.type}
            slug={resource.toParam}
            files={files}
            canDownload={props.canDownload}
            restriction={props.restriction}
            downloadMode={props.downloadMode}
            signInHref={signInHref}
            facts={[
              { label: 'Licence', value: licence ? licence.name : 'Not yet confirmed' },
              ...(props.updatedOn ? [{ label: 'Updated', value: props.updatedOn }] : []),
            ]}
          />
          <WorksWith groups={worksWith} />
          <a
            href={props.issueUrl}
            target="_blank"
            rel="noopener"
            className="inline-flex items-center gap-1.5 self-center text-xs text-muted-foreground hover:text-foreground"
          >
            <FlagIcon className="size-3.5" aria-hidden="true" /> Report an issue with this resource
          </a>
        </div>
      </Container>
    </SiteShell>
  )
}
