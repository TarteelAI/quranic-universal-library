import { Link, router, usePage } from '@inertiajs/react'
import { ChevronLeftIcon, ChevronRightIcon, ChevronUpIcon } from 'lucide-react'
import * as React from 'react'

import { Container, SiteShell } from '@/components/layout'
import { EmptyState } from '@/components/qul/catalog'
import { PageHeader } from '@/components/qul/page-header'
import { RequestButton } from '@/components/qul/request-dialog'
import { Badge, type BadgeProps } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { cn } from '@/lib/utils'
import { newUserSession, requestsPage, resourceRequestVote, requestsRequests } from '@/routes'
import type { RequestsListItem, RequestsRequestsIndex } from '@/types/serializers'

type Sort = RequestsRequestsIndex['sort']

const SORTS: { key: Sort; label: string }[] = [
  { key: 'votes', label: 'Most votes' },
  { key: 'date', label: 'Newest' },
]

const STATUS_BADGE: Record<RequestsListItem['status'], BadgeProps['variant']> = {
  open: 'secondary',
  planned: 'info',
  in_progress: 'warning',
  added: 'success',
  declined: 'outline',
}

// The list URL: votes and page 1 are the defaults, so they stay out of it.
const listUrl = (sort: Sort, page = 1) => {
  const query = { ...(sort === 'date' ? { sort } : {}), ...(page > 1 ? { page } : {}) }
  return requestsPage(Object.keys(query).length ? { query } : undefined).url
}

/**
 * Votes for a request or takes the vote back, then reloads only the list, so the count changes in
 * place. A signed-out visitor gets a link to sign-in that comes back to this page.
 */
function VoteButton({ request }: { request: RequestsListItem }) {
  const { url, props } = usePage()
  const [sending, setSending] = React.useState(false)
  const label = `${request.votes} ${request.votes === 1 ? 'vote' : 'votes'}`
  const className =
    'flex w-14 shrink-0 flex-col items-center gap-0.5 rounded-lg border bg-card py-2 text-sm font-medium tabular-nums transition-colors hover:border-foreground/30 disabled:opacity-50'

  if (!props.auth.user)
    return (
      <a
        href={newUserSession({ query: { user_return_to: url } }).url}
        aria-label={`Sign in to vote for ${request.title} (${label})`}
        className={className}
      >
        <ChevronUpIcon className="size-4" aria-hidden="true" />
        {request.votes}
      </a>
    )

  const options = { only: ['requests'], preserveScroll: true, onFinish: () => setSending(false) }
  const toggle = () => {
    setSending(true)
    if (request.voted) router.delete(requestsRequests.unvote(request.id).url, options)
    else router.post(resourceRequestVote(request.id).url, {}, options)
  }

  return (
    <button
      type="button"
      aria-pressed={request.voted}
      aria-label={`Vote for ${request.title} (${label})`}
      disabled={sending}
      onClick={toggle}
      className={cn(
        className,
        request.voted && 'border-primary bg-primary text-primary-foreground hover:border-primary',
      )}
    >
      <ChevronUpIcon className="size-4" aria-hidden="true" />
      {request.votes}
    </button>
  )
}

// /requests: the visible resource requests with their status and votes, by votes or newest first,
// 20 to a page. Composed from existing components; it has no prototype design.
export default function RequestsPage({ requests, sort, page, pages, total }: RequestsRequestsIndex) {
  const { nav } = usePage().props

  return (
    <SiteShell>
      <Container className="max-w-4xl pt-12 pb-16">
        <PageHeader
          title="Resource requests"
          count={total}
          description="Resources people have asked QUL to add. Vote for the ones you need: requests with more votes get picked up first."
          actions={<RequestButton link={nav.request} variant="default" />}
        />

        <nav aria-label="Sort" className="mt-8 flex items-center gap-1.5 text-sm">
          {SORTS.map((option) => (
            <Link
              key={option.key}
              href={listUrl(option.key)}
              aria-current={option.key === sort ? 'true' : undefined}
              className={cn(
                'inline-flex h-8 items-center rounded-full border bg-card px-3 transition-colors hover:border-foreground/30',
                option.key === sort && 'border-primary bg-primary text-primary-foreground hover:border-primary',
              )}
            >
              {option.label}
            </Link>
          ))}
        </nav>

        {requests.length > 0 ? (
          <ol aria-label="Requests" className="mt-6 divide-y border-y">
            {requests.map((request) => (
              <li key={request.id} className="flex gap-4 py-5">
                <VoteButton request={request} />
                <div className="flex min-w-0 flex-1 flex-col gap-1.5">
                  <div className="flex flex-wrap items-center gap-x-3 gap-y-1">
                    <h2 className="text-lg font-medium tracking-tight break-words">{request.title}</h2>
                    <Badge variant={STATUS_BADGE[request.status]}>{request.statusLabel}</Badge>
                  </div>
                  <p className="text-sm text-muted-foreground">
                    {[request.type, request.language, request.date].filter(Boolean).join(' · ')}
                  </p>
                  <p className="break-words whitespace-pre-line">{request.description}</p>
                </div>
              </li>
            ))}
          </ol>
        ) : (
          <EmptyState
            className="mt-6"
            icon="request"
            title="No requests yet"
            description="Ask for a resource QUL does not have, and others can vote for it."
          />
        )}

        {pages > 1 && (
          <nav aria-label="Pages" className="mt-8 flex items-center justify-between gap-3 text-sm">
            {page > 1 ? (
              <Button variant="outline" size="sm" asChild>
                <Link href={listUrl(sort, page - 1)} rel="prev">
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
                <Link href={listUrl(sort, page + 1)} rel="next">
                  Next <ChevronRightIcon />
                </Link>
              </Button>
            ) : (
              <span />
            )}
          </nav>
        )}
      </Container>
    </SiteShell>
  )
}
