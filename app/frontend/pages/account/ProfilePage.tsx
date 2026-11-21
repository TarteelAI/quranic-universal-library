import { Link, router, usePage } from '@inertiajs/react'
import { ChevronLeftIcon, ChevronRightIcon, SettingsIcon } from 'lucide-react'
import type { ReactNode } from 'react'

import { Container, SiteShell } from '@/components/layout'
import { EmptyState } from '@/components/qul/catalog'
import { NavAnchor } from '@/components/qul/nav'
import { RequestButton, RequestStatusBadge } from '@/components/qul/request-dialog'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { cn } from '@/lib/utils'
import { accountProfile, requestsPage, resources, toolsPage } from '@/routes'
import type { AccountProfilesShow } from '@/types/serializers'

type Tab = AccountProfilesShow['tab']

const TABS: { key: Tab; label: string }[] = [
  { key: 'downloads', label: 'Downloads' },
  { key: 'contributions', label: 'Contributions' },
  { key: 'resources', label: 'Edit access' },
  { key: 'requests', label: 'Requests' },
]

// The profile URL: the first tab and page 1 are the defaults, so they stay out of it.
function profileUrl(tab: Tab, query: Record<string, string | number> = {}) {
  const all = { ...(tab === 'downloads' ? {} : { tab }), ...query }
  return accountProfile(Object.keys(all).length ? { query: all } : undefined).url
}

/** One row of a tab's list: a small type line, the title, a muted line and what sits at the end. */
function Row({
  type,
  title,
  href,
  inertia,
  meta,
  children,
}: {
  type?: string | null
  title: ReactNode
  /** Where the title goes, when the row has a page */
  href?: string | null
  /** The page is a new page: an Inertia visit */
  inertia?: boolean
  meta?: ReactNode
  children?: ReactNode
}) {
  const link = 'underline-offset-4 hover:underline'
  return (
    <li className="flex flex-wrap items-center gap-x-4 gap-y-2 py-4">
      <div className="flex min-w-0 flex-1 flex-col gap-1">
        {type && <p className="text-xs font-medium text-muted-foreground">{type}</p>}
        <p className="font-medium break-words">
          {href && inertia && (
            <Link href={href} className={link}>
              {title}
            </Link>
          )}
          {href && !inertia && (
            <a href={href} className={link}>
              {title}
            </a>
          )}
          {!href && title}
        </p>
        {meta && <p className="text-sm text-muted-foreground">{meta}</p>}
      </div>
      {children && <div className="flex shrink-0 items-center gap-3">{children}</div>}
    </li>
  )
}

// /profile: the signed-in user's own page. Who they are, then a tab for each list the account
// has: the files they downloaded, the changes they made to the data, the resources they asked to
// edit and the resource requests they sent. The open tab, its filter and its page are in the URL.
export default function ProfilePage(props: AccountProfilesShow) {
  const { person, counts, tab, filter, page, pages, catalog } = props
  const { nav } = usePage().props
  const tabs = TABS.filter((item) => counts[item.key] !== null)
  const filtered = filter?.value ? { [filter.param]: filter.value } : {}

  return (
    <SiteShell>
      <Container className="max-w-4xl pt-12 pb-16">
        <header className="flex flex-col gap-5 sm:flex-row sm:items-center">
          <span
            aria-hidden="true"
            className="flex size-20 shrink-0 items-center justify-center rounded-full bg-secondary text-2xl font-semibold"
          >
            {person.initials}
          </span>
          <div className="flex min-w-0 flex-1 flex-col gap-1.5">
            <h1 className="headline text-3xl break-words sm:text-4xl">{person.name}</h1>
            <p className="text-muted-foreground">
              <span className="break-all">{person.email}</span> · Member since {person.memberSince}
            </p>
          </div>
          <Button variant="outline" asChild className="self-start sm:self-center">
            <NavAnchor link={nav.settings}>
              <SettingsIcon /> Edit profile
            </NavAnchor>
          </Button>
        </header>

        {person.about && (
          <section aria-label="About" className="mt-8 max-w-2xl">
            <div className="docs-prose" dangerouslySetInnerHTML={{ __html: person.about }} />
          </section>
        )}

        <Tabs
          value={tab}
          onValueChange={(next) => router.visit(profileUrl(next as Tab), { preserveScroll: true })}
          className="mt-10 gap-6"
        >
          <div className="overflow-x-auto">
            <TabsList variant="line">
              {tabs.map((item) => (
                <TabsTrigger key={item.key} value={item.key}>
                  {item.label}
                  <span className="font-mono text-xs font-normal text-muted-foreground tabular-nums">
                    {counts[item.key]}
                  </span>
                </TabsTrigger>
              ))}
            </TabsList>
          </div>

          <TabsContent value={tab} className="flex flex-col gap-5">
            {filter && (
              <nav aria-label="Filter" className="flex flex-wrap items-center gap-1.5 text-sm">
                {[{ key: null, label: 'All' }, ...filter.options].map((option) => (
                  <Link
                    key={option.key ?? ''}
                    href={profileUrl(tab, option.key ? { [filter.param]: option.key } : {})}
                    preserveScroll
                    aria-current={option.key === filter.value ? 'true' : undefined}
                    className={cn(
                      'inline-flex h-8 items-center rounded-full border bg-card px-3 transition-colors hover:border-foreground/30',
                      option.key === filter.value &&
                        'border-primary bg-primary text-primary-foreground hover:border-primary',
                    )}
                  >
                    {option.label}
                  </Link>
                ))}
              </nav>
            )}

            {props.downloads &&
              (props.downloads.length > 0 ? (
                <ul aria-label="Downloads" className="divide-y border-y">
                  {props.downloads.map((download) => (
                    <Row
                      key={download.id}
                      type={download.type}
                      title={download.name}
                      href={download.path}
                      inertia={catalog}
                      meta={download.date ? `Downloaded ${download.date}` : undefined}
                    >
                      {download.updateAvailable ? (
                        <Badge variant="warning">Update available</Badge>
                      ) : (
                        <Badge variant="success">Up to date</Badge>
                      )}
                    </Row>
                  ))}
                </ul>
              ) : (
                <EmptyState
                  icon="bundle"
                  title="No downloads yet"
                  description="Files you download are listed here, with a note when a newer version is out."
                  action={
                    <Button variant="outline" asChild>
                      <a href={resources.index().url}>Browse the resources</a>
                    </Button>
                  }
                />
              ))}

            {props.contributions &&
              (props.contributions.length > 0 ? (
                <ul aria-label="Contributions" className="divide-y border-y">
                  {props.contributions.map((contribution) => (
                    <Row
                      key={contribution.id}
                      type={contribution.type}
                      title={contribution.label}
                      href={contribution.path}
                      meta={[contribution.reference, contribution.date].filter(Boolean).join(' · ')}
                    />
                  ))}
                </ul>
              ) : (
                <EmptyState
                  icon="proofread"
                  title="No contributions yet"
                  description="Corrections and reviews you make with the contributor tools are listed here."
                  action={
                    <Button variant="outline" asChild>
                      <a href={toolsPage().url}>See the contributor tools</a>
                    </Button>
                  }
                />
              ))}

            {props.accesses &&
              (props.accesses.length > 0 ? (
                <ul aria-label="Edit access" className="divide-y border-y">
                  {props.accesses.map((access) => (
                    <Row
                      key={access.id}
                      type={access.tool}
                      title={access.name}
                      href={access.path}
                      meta={`${access.approved ? 'Access granted' : 'Requested'} ${access.date ?? ''}`.trim()}
                    >
                      {access.approved ? (
                        <Badge variant="success">Approved</Badge>
                      ) : (
                        <Badge variant="warning">Pending review</Badge>
                      )}
                      {access.path && (
                        <Button variant="outline" size="sm" asChild>
                          <a href={access.path}>Open tool</a>
                        </Button>
                      )}
                    </Row>
                  ))}
                </ul>
              ) : (
                <EmptyState
                  icon="proofread"
                  title="No edit access yet"
                  description="Resources you ask to edit with a contributor tool are listed here, with the state of each request."
                  action={
                    <Button variant="outline" asChild>
                      <a href={toolsPage().url}>See the contributor tools</a>
                    </Button>
                  }
                />
              ))}

            {props.requests &&
              (props.requests.length > 0 ? (
                <>
                  <ul aria-label="Requests" className="divide-y border-y">
                    {props.requests.map((request) => (
                      <Row
                        key={request.id}
                        title={request.title}
                        meta={`${request.votes} ${request.votes === 1 ? 'vote' : 'votes'} · ${request.date}`}
                      >
                        <RequestStatusBadge status={request.status} label={request.statusLabel} />
                      </Row>
                    ))}
                  </ul>
                  <p className="text-sm">
                    <Link href={requestsPage().url} className="underline underline-offset-4">
                      See all requests
                    </Link>
                  </p>
                </>
              ) : (
                <EmptyState
                  icon="request"
                  title="No requests yet"
                  description="Resources you ask QUL to add are listed here, with their status and votes."
                  action={<RequestButton link={nav.request} />}
                />
              ))}

            {pages > 1 && (
              <nav aria-label="Pages" className="flex items-center justify-between gap-3 text-sm">
                {page > 1 ? (
                  <Button variant="outline" size="sm" asChild>
                    <Link href={profileUrl(tab, { ...filtered, ...(page > 2 ? { page: page - 1 } : {}) })} rel="prev">
                      <ChevronLeftIcon /> Previous
                    </Link>
                  </Button>
                ) : (
                  <span />
                )}
                <span className="text-muted-foreground tabular-nums">
                  Page {page} of {pages}
                </span>
                {page < pages ? (
                  <Button variant="outline" size="sm" asChild>
                    <Link href={profileUrl(tab, { ...filtered, page: page + 1 })} rel="next">
                      Next <ChevronRightIcon />
                    </Link>
                  </Button>
                ) : (
                  <span />
                )}
              </nav>
            )}
          </TabsContent>
        </Tabs>
      </Container>
    </SiteShell>
  )
}
