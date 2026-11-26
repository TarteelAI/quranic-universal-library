import { Link, useForm, usePage } from '@inertiajs/react'
import { ArrowUpRightIcon, ChevronDownIcon } from 'lucide-react'
import * as React from 'react'

import { Badge, type BadgeProps } from '@/components/ui/badge'
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
import type { RequestsListItem, RequestsType, SiteNavLink } from '@/types/serializers'

import { FilterChip } from './catalog'
import { FileDrop } from './file-drop'
import { GatedForm } from './gated-form'
import { QulIcon } from './icons'

/** The query parameter that opens the request dialog on any new page (sign-in returns with it). */
const OPEN_PARAM = 'request'

type Fields = {
  title: string
  description: string
  resource_type: string
  language: string
  author: string
  book_name: string
  publisher: string
  publishing_year: string
  license_details: string
  source_url: string
  source_files: File[]
}
type TextField = Exclude<keyof Fields, 'source_files'>

const EMPTY: Fields = {
  title: '',
  description: '',
  resource_type: '',
  language: '',
  author: '',
  book_name: '',
  publisher: '',
  publishing_year: '',
  license_details: '',
  source_url: '',
  source_files: [],
}

// The book details fold; with the author, the fields of a written work, sent only for a type
// that asks for an author.
const BOOK_FIELDS = ['book_name', 'publisher', 'publishing_year'] as const
const WORK_FIELDS = ['author', ...BOOK_FIELDS] as const
const SOURCE_FIELDS = ['license_details', 'source_url'] as const
// As ResourceRequest::SOURCE_TYPES, SOURCE_MAX_FILES and SOURCE_MAX_SIZE; the server checks the bytes.
const SOURCE_ACCEPT = '.pdf,.doc,.docx,.txt,.ttf,.otf,.woff,.woff2'
const SOURCE_MAX_FILES = 5
const SOURCE_MAX_SIZE = 10 * 1024 * 1024

// What the form sends: the core fields, the filled optional ones the type asks for, and the files.
function payload(fields: Fields, type: RequestsType | undefined) {
  const { title, description, resource_type, language } = fields
  const optional = [...(type?.author ? WORK_FIELDS : []), ...SOURCE_FIELDS].filter((name) => fields[name].trim())
  return {
    title,
    description,
    resource_type,
    language,
    ...Object.fromEntries(optional.map((name) => [name, fields[name]])),
    ...(fields.source_files.length > 0 && { source_files: fields.source_files }),
  }
}

const STATUS_BADGE: Record<RequestsListItem['status'], BadgeProps['variant']> = {
  open: 'secondary',
  planned: 'info',
  in_progress: 'warning',
  added: 'success',
  declined: 'outline',
}

/** A request's status as a badge, on the requests page and the profile's requests. */
function RequestStatusBadge({ status, label }: { status: RequestsListItem['status']; label: string }) {
  return <Badge variant={STATUS_BADGE[status]}>{label}</Badge>
}

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
  const form = useForm<Fields>(EMPTY)
  const { data, errors } = form
  const type = types.find((option) => option.key === data.resource_type)
  // An error about the request as a whole (the daily limit), which no field shows.
  const [refusal, setRefusal] = React.useState<string[]>()
  // The folded groups, opened when the server finds an error in one.
  const [bookOpen, setBookOpen] = React.useState(false)
  const [sourceOpen, setSourceOpen] = React.useState(false)

  const changeOpen = (next: boolean) => {
    if (next) setSent(false)
    onOpenChange(next)
  }

  const submit = (event: React.FormEvent) => {
    event.preventDefault()
    form.transform((fields) => ({ request: payload(fields, type) }))
    setRefusal(undefined)
    form.post(resourceRequests().url, {
      preserveScroll: true,
      onError: (errors) => {
        setRefusal(errors.base)
        if (BOOK_FIELDS.some((name) => errors[name])) setBookOpen(true)
        if ([...SOURCE_FIELDS, 'source_files' as const].some((name) => errors[name])) setSourceOpen(true)
      },
      onSuccess: () => {
        form.reset()
        setBookOpen(false)
        setSourceOpen(false)
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
                  {types.map((option) => (
                    <FilterChip
                      key={option.key}
                      option={option}
                      selected={data.resource_type === option.key}
                      onClick={() => {
                        form.setData('resource_type', option.key)
                        if (option.sourceRequired) setSourceOpen(true)
                      }}
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
              {type?.author && (
                <>
                  <TextInput
                    form={form}
                    name="author"
                    label={type.author === 'required' ? 'Author or translator' : 'Author (optional)'}
                    required={type.author === 'required'}
                    maxLength={200}
                    placeholder="e.g. Salahuddin Yusuf"
                    field={field}
                    error={errors.author}
                  />
                  <Fold title="Book details (optional)" open={bookOpen} onOpenChange={setBookOpen}>
                    <div className="grid gap-4 sm:grid-cols-2">
                      <TextInput
                        form={form}
                        name="book_name"
                        label="Book name"
                        maxLength={200}
                        field={field}
                        error={errors.book_name}
                      />
                      <TextInput
                        form={form}
                        name="publisher"
                        label="Publisher"
                        maxLength={200}
                        field={field}
                        error={errors.publisher}
                      />
                      <TextInput
                        form={form}
                        name="publishing_year"
                        label="Year published"
                        type="number"
                        inputMode="numeric"
                        min={1}
                        max={new Date().getFullYear()}
                        field={field}
                        error={errors.publishing_year}
                      />
                    </div>
                  </Fold>
                </>
              )}
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
              {type && (
                <Fold
                  title={
                    type.sourceRequired ? 'Source: the font file or a link to it' : 'Source and licence (optional)'
                  }
                  open={sourceOpen}
                  onOpenChange={setSourceOpen}
                >
                  <p className="text-sm text-muted-foreground">
                    {type.sourceRequired
                      ? 'Add the font file, or a link where we can get it.'
                      : 'Files or a link save us time finding it. Only the QUL team sees them.'}
                  </p>
                  <div className="flex flex-col gap-2">
                    <Label htmlFor="request-source_files">Source files</Label>
                    <FileDrop
                      {...field('source_files')}
                      files={data.source_files}
                      onChange={(files) => form.setData('source_files', files)}
                      accept={SOURCE_ACCEPT}
                      maxFiles={SOURCE_MAX_FILES}
                      maxSize={SOURCE_MAX_SIZE}
                      hint="PDF, Word, text or font files, up to 5 files of 10 MB"
                    />
                    <FieldError name="source_files" error={errors.source_files} />
                  </div>
                  <TextInput
                    form={form}
                    name="source_url"
                    label="Link to the source"
                    type="url"
                    maxLength={500}
                    placeholder="https://"
                    field={field}
                    error={errors.source_url}
                  />
                  <div className="flex flex-col gap-2">
                    <Label htmlFor="request-license_details">Licence</Label>
                    <Textarea
                      {...field('license_details')}
                      rows={2}
                      maxLength={1000}
                      placeholder="e.g. free to share with credit, or who to ask"
                      value={data.license_details}
                      onChange={(event) => form.setData('license_details', event.target.value)}
                    />
                    <FieldError name="license_details" error={errors.license_details} />
                  </div>
                </Fold>
              )}
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

type FieldProps = (name: keyof Fields) => {
  id: string
  'aria-invalid': boolean | undefined
  'aria-describedby': string | undefined
}

/** A labelled text input of the request form, with its server error. */
function TextInput({
  form,
  name,
  label,
  field,
  error,
  ...input
}: {
  form: { data: Fields; setData: (name: TextField, value: string) => void }
  name: TextField
  label: string
  field: FieldProps
  error?: string[]
} & Omit<React.ComponentProps<'input'>, 'form' | 'name' | 'value' | 'onChange'>) {
  return (
    <div className="flex flex-col gap-2">
      <Label htmlFor={`request-${name}`}>{label}</Label>
      <Input
        {...field(name)}
        {...input}
        value={form.data[name]}
        onChange={(event) => form.setData(name, event.target.value)}
      />
      <FieldError name={name} error={error} />
    </div>
  )
}

/** A folded group of the request form; its summary says what is inside. */
function Fold({
  title,
  open,
  onOpenChange,
  children,
}: {
  title: string
  open: boolean
  onOpenChange: (open: boolean) => void
  children: React.ReactNode
}) {
  return (
    <details
      open={open}
      onToggle={(event) => onOpenChange(event.currentTarget.open)}
      className="group rounded-lg border px-4 py-3"
    >
      <summary className="flex cursor-pointer list-none items-center justify-between gap-2 text-sm font-medium [&::-webkit-details-marker]:hidden">
        {title}
        <ChevronDownIcon className="size-4 transition-transform group-open:rotate-180" aria-hidden="true" />
      </summary>
      <div className="mt-4 flex flex-col gap-4">{children}</div>
    </details>
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

export { RequestButton, RequestCard, RequestDialogProvider, RequestStatusBadge, useRequestDialog }
