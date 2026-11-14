import { Link, useForm, usePage } from '@inertiajs/react'
import { ArrowUpRightIcon } from 'lucide-react'
import * as React from 'react'

import { Button } from '@/components/ui/button'
import { Input, Label, Textarea } from '@/components/ui/input'
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/overlays'
import { cn } from '@/lib/utils'
import { requestsPage, resourceRequests } from '@/routes'
import type { SiteNavLink } from '@/types/serializers'

import { FilterChip } from './catalog'
import { GatedForm } from './gated-form'
import { QulIcon } from './icons'

/** The query parameter that opens the request dialog on any new page (sign-in returns with it). */
const OPEN_PARAM = 'request'

type Fields = { title: string; description: string; resource_type: string; language: string }

const RequestDialogContext = React.createContext<(() => void) | null>(null)

/** Opens the request dialog of the page's shell; null outside a shell that has one. */
function useRequestDialog() {
  return React.useContext(RequestDialogContext)
}

// The current URL with `?request=new`: the page with the dialog open.
function openUrl(url: string) {
  const [path, query] = url.split('?')
  const params = new URLSearchParams(query)
  params.set(OPEN_PARAM, 'new')
  return `${path}?${params}`
}

/**
 * The request dialog of every new page while the `requests` group is on (`nav.request` is then an
 * in-app link). `?request=new` in the URL opens it, so the Contribute menu's link and the return
 * from sign-in show it open. Without the group, children render alone.
 */
function RequestDialogProvider({ children }: { children: React.ReactNode }) {
  const { url, props } = usePage()
  const enabled = props.nav.request.inertia
  const [open, setOpen] = React.useState(
    () => enabled && new URLSearchParams(url.split('?')[1]).get(OPEN_PARAM) === 'new',
  )
  const show = React.useCallback(() => setOpen(true), [])

  if (!enabled) return children
  return (
    <RequestDialogContext value={show}>
      {children}
      <RequestDialog open={open} onOpenChange={setOpen} />
    </RequestDialogContext>
  )
}

/**
 * "Request a resource", from the v8 design (ds/src/app/shell.tsx) without "email me": a gated
 * form that posts to POST /requests (Requests::RequestsController) as an Inertia visit. The
 * server answers with the page it came from; its validation errors show beside the fields.
 */
function RequestDialog({ open, onOpenChange }: { open: boolean; onOpenChange: (open: boolean) => void }) {
  const { url, props } = usePage()
  const types = props.nav.requestTypes
  const [sent, setSent] = React.useState(false)
  const form = useForm<Fields>({ title: '', description: '', resource_type: '', language: '' })
  const { data, errors } = form
  // An error about the request as a whole (the daily limit), which no field shows.
  const [refusal, setRefusal] = React.useState<string[]>()

  const changeOpen = (next: boolean) => {
    if (next) setSent(false)
    onOpenChange(next)
  }

  const submit = (event: React.FormEvent) => {
    event.preventDefault()
    form.transform((fields) => ({ request: fields }))
    setRefusal(undefined)
    form.post(resourceRequests().url, {
      preserveScroll: true,
      onError: (errors) => setRefusal(errors.base),
      onSuccess: () => {
        form.reset()
        setSent(true)
      },
    })
  }

  // Props for a field's input: its error, and the description that names it.
  const field = (name: keyof Fields) => ({
    id: `request-${name}`,
    'aria-invalid': errors[name] ? true : undefined,
    'aria-describedby': errors[name] ? `request-${name}-error` : undefined,
  })

  return (
    <Dialog open={open} onOpenChange={changeOpen}>
      <DialogContent className="max-h-[calc(100dvh-2rem)] overflow-y-auto">
        {sent ? (
          <div role="status" className="flex flex-col items-center gap-2 py-6 text-center">
            <DialogTitle className="text-2xl">Request received</DialogTitle>
            <DialogDescription className="max-w-sm text-pretty">
              It is on the requests page now, where others can vote for it. Requests with more votes get picked up
              first.
            </DialogDescription>
            <div className="mt-3 flex flex-wrap justify-center gap-2">
              <Button variant="outline" asChild>
                <Link href={requestsPage({ query: { sort: 'date' } }).url} onClick={() => changeOpen(false)}>
                  See all requests
                </Link>
              </Button>
              <Button onClick={() => changeOpen(false)}>Done</Button>
            </div>
          </div>
        ) : (
          <>
            <DialogHeader>
              <DialogTitle>Request a resource</DialogTitle>
              <DialogDescription>
                Tell us what you need. Requests with more votes get picked up first.
              </DialogDescription>
            </DialogHeader>
            <GatedForm returnTo={openUrl(url)} purpose="request a resource" onSubmit={submit}>
              <div className="flex flex-col gap-2">
                <span id="request-resource_type-label" className="text-sm leading-none font-medium">
                  What kind of resource?
                </span>
                <div
                  role="group"
                  aria-labelledby="request-resource_type-label"
                  aria-describedby={errors.resource_type ? 'request-resource_type-error' : undefined}
                  className="flex flex-wrap gap-1.5"
                >
                  {types.map((type) => (
                    <FilterChip
                      key={type.key}
                      option={type}
                      selected={data.resource_type === type.key}
                      onClick={() => form.setData('resource_type', type.key)}
                    />
                  ))}
                </div>
                <FieldError name="resource_type" error={errors.resource_type} />
              </div>
              <div className="grid gap-4 sm:grid-cols-2">
                <div className="flex flex-col gap-2">
                  <Label htmlFor="request-title">What is missing?</Label>
                  <Input
                    {...field('title')}
                    required
                    maxLength={120}
                    placeholder="e.g. Tafsir Ahsanul Bayan"
                    value={data.title}
                    onChange={(event) => form.setData('title', event.target.value)}
                  />
                  <FieldError name="title" error={errors.title} />
                </div>
                <div className="flex flex-col gap-2">
                  <Label htmlFor="request-language">Language or script (optional)</Label>
                  <Input
                    {...field('language')}
                    maxLength={60}
                    placeholder="e.g. Bengali"
                    value={data.language}
                    onChange={(event) => form.setData('language', event.target.value)}
                  />
                  <FieldError name="language" error={errors.language} />
                </div>
              </div>
              <div className="flex flex-col gap-2">
                <Label htmlFor="request-description">What are you building?</Label>
                <Textarea
                  {...field('description')}
                  required
                  maxLength={2000}
                  placeholder="Helps us decide what to add first"
                  value={data.description}
                  onChange={(event) => form.setData('description', event.target.value)}
                />
                <FieldError name="description" error={errors.description} />
              </div>
              {refusal && (
                <p role="alert" className="rounded-lg bg-destructive/10 p-4 text-sm text-destructive">
                  {refusal.join(' ')}
                </p>
              )}
              <DialogFooter>
                <Button type="button" variant="ghost" onClick={() => changeOpen(false)}>
                  Cancel
                </Button>
                <Button type="submit" disabled={form.processing}>
                  Send request
                </Button>
              </DialogFooter>
            </GatedForm>
          </>
        )}
      </DialogContent>
    </Dialog>
  )
}

function FieldError({ name, error }: { name: keyof Fields; error?: string[] }) {
  if (!error) return null
  return (
    <p id={`request-${name}-error`} className="text-sm text-destructive">
      {error.join(' ')}
    </p>
  )
}

type RequestLink = Pick<SiteNavLink, 'href' | 'label' | 'inertia'>

/**
 * The request form's button (the `nav.request` shared prop): opens the shell's request dialog in
 * place while the `requests` group is on, else the GitHub issue form in a new tab.
 */
function RequestButton({ link, variant = 'outline' }: { link: RequestLink; variant?: 'outline' | 'default' }) {
  const openRequest = useRequestDialog()
  if (!link.inertia)
    return (
      <Button variant={variant} asChild>
        <a href={link.href} target="_blank" rel="noreferrer">
          {link.label} <ArrowUpRightIcon />
        </a>
      </Button>
    )

  const open = (event: React.MouseEvent) => {
    if (!openRequest) return
    event.preventDefault()
    openRequest()
  }
  return (
    <Button variant={variant} asChild>
      <Link href={link.href} onClick={open}>
        {link.label}
      </Link>
    </Button>
  )
}

/** "Can't find it? Request it." at the end of a list and in empty states. */
function RequestCard({ link, className }: { link: RequestLink; className?: string }) {
  return (
    <div
      className={cn(
        'flex flex-col items-start gap-4 rounded-xl bg-card p-5 shadow-xs sm:flex-row sm:items-center sm:p-6',
        className,
      )}
    >
      <span className="flex size-10 shrink-0 items-center justify-center rounded-lg bg-secondary">
        <QulIcon name="request" size={20} />
      </span>
      <div className="flex-1">
        <p className="font-medium">Can't find what you need?</p>
        <p className="text-sm text-muted-foreground">
          {link.inertia
            ? 'Tell us what is missing, or vote for what others asked for.'
            : "Tell us what's missing on GitHub."}
        </p>
      </div>
      <RequestButton link={link} />
    </div>
  )
}

export { RequestButton, RequestCard, RequestDialogProvider, useRequestDialog }
