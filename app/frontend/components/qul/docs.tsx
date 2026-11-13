import { Link, router } from '@inertiajs/react'
import { BookOpenIcon, CheckIcon, ChevronDownIcon, CopyIcon, MenuIcon, PlayIcon, RotateCcwIcon } from 'lucide-react'
import { type MouseEvent, type ReactNode, useCallback, useEffect, useState } from 'react'

import { Container } from '@/components/layout'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Dialog, DialogContent, DialogDescription, DialogTitle, DialogTrigger } from '@/components/ui/overlays'
import { cn } from '@/lib/utils'
import { docsIndexPage, docsPage } from '@/routes'
import type { ContentDocHeading, ContentDocNavCategory, ContentDocSegment } from '@/types/serializers'

// A link in a docs body to another docs page is an Inertia visit: every docs page the body can
// link to is a new page while the docs pages are. Any other link loads in full.
function visitDocsLink(event: MouseEvent<HTMLDivElement>) {
  if (event.defaultPrevented || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey)
    return
  const link = (event.target as Element).closest('a')
  const href = link?.getAttribute('href')
  if (!link || link.target || !href || !/^\/docs(\/[\w-]+)?(#[^/]*)?$/.test(href)) return
  event.preventDefault()
  router.visit(href)
}

// A docs body (Content::DocPage): prose HTML the server sanitized, code blocks and runnable examples.
export function DocBody({ segments, className }: { segments: ContentDocSegment[]; className?: string }) {
  return (
    <div className={cn('docs-prose', className)} onClick={visitDocsLink}>
      {segments.map((segment, index) => {
        if (segment.kind === 'code') return <CodeBlock key={index} label={segment.label} code={segment.code ?? ''} />
        if (segment.kind === 'playground') return <Playground key={index} code={segment.code ?? ''} />
        // display: contents keeps the prose children in the body's flow and spacing.
        return <div key={index} className="contents" dangerouslySetInnerHTML={{ __html: segment.html ?? '' }} />
      })}
    </div>
  )
}

function CopyButton({ text }: { text: () => string }) {
  const [copied, setCopied] = useState(false)
  useEffect(() => {
    if (!copied) return
    const timer = setTimeout(() => setCopied(false), 1500)
    return () => clearTimeout(timer)
  }, [copied])

  return (
    <Button
      variant="ghost"
      size="sm"
      onClick={() => navigator.clipboard.writeText(text()).then(() => setCopied(true))}
      aria-label={copied ? 'Copied' : 'Copy code'}
    >
      {copied ? <CheckIcon /> : <CopyIcon />}
      {copied ? 'Copied' : 'Copy'}
    </Button>
  )
}

function CodeHeader({ label, children }: { label: string | null; children: ReactNode }) {
  return (
    <div className="flex items-center justify-between gap-2 border-b border-border px-3 py-1">
      <span className="font-mono text-xs text-muted-foreground">{label ?? 'Code'}</span>
      <div className="flex items-center gap-1">{children}</div>
    </div>
  )
}

export function CodeBlock({ label, code }: { label: string | null; code: string }) {
  return (
    <figure className="overflow-hidden rounded-lg border border-border bg-card">
      <CodeHeader label={label}>
        <CopyButton text={() => code} />
      </CodeHeader>
      <pre className="overflow-x-auto p-4 font-mono text-[13px] leading-6">
        <code>{code}</code>
      </pre>
    </figure>
  )
}

// The example's document: its code in a script after an #app element, with errors shown under it.
function exampleDocument(code: string) {
  const script = code.replace(/<\/script/gi, '<\\/script')
  return `<!doctype html>
<html>
<head>
<meta charset="utf-8">
<style>
  body { margin: 0; padding: 16px; font-family: ui-sans-serif, system-ui, sans-serif; color: #0f172a; background: #fff; }
  [dir="rtl"] { font-family: "Noto Naskh Arabic", "Geeza Pro", "Arial Unicode MS", serif; }
  .example-error { margin-top: 12px; border: 1px solid #fecaca; border-radius: 8px; background: #fff1f2; color: #9f1239;
    padding: 12px; font-family: ui-monospace, monospace; white-space: pre-wrap; }
</style>
</head>
<body>
<div id="app"></div>
<script>
  const showError = (message) => {
    const error = document.createElement("pre");
    error.className = "example-error";
    error.textContent = String(message);
    document.body.appendChild(error);
  };
  window.addEventListener("error", (event) => showError(event.error?.stack || event.message));
  window.addEventListener("unhandledrejection", (event) => showError(event.reason?.stack || event.reason));
  try {
${script}
  } catch (error) {
    showError(error.stack || error.message || error);
  }
</script>
</body>
</html>`
}

// A runnable example from a tutorial: the code is editable and runs in a sandboxed frame with
// scripts allowed and nothing else, so it has no access to this page, its cookies or storage. The
// server renders the frame with the example in it, so it runs before hydration; Run and Reset
// load the frame again (`runs` is its key).
export function Playground({ code }: { code: string }) {
  const [source, setSource] = useState(code)
  const [output, setOutput] = useState(() => exampleDocument(code))
  const [runs, setRuns] = useState(0)
  const run = (text: string) => {
    setOutput(exampleDocument(text))
    setRuns((count) => count + 1)
  }

  return (
    <figure className="overflow-hidden rounded-lg border border-border bg-card">
      <CodeHeader label="JavaScript example">
        <Button variant="ghost" size="sm" onClick={() => run(source)}>
          <PlayIcon /> Run
        </Button>
        <Button
          variant="ghost"
          size="sm"
          onClick={() => {
            setSource(code)
            run(code)
          }}
        >
          <RotateCcwIcon /> Reset
        </Button>
        <CopyButton text={() => source} />
      </CodeHeader>
      <div className="grid lg:grid-cols-2">
        <textarea
          aria-label="Example code"
          value={source}
          onChange={(event) => setSource(event.target.value)}
          spellCheck={false}
          className="min-h-80 resize-y border-b border-border bg-transparent p-4 font-mono text-[13px] leading-6 outline-none lg:border-e lg:border-b-0"
        />
        <iframe
          key={runs}
          title="Example output"
          sandbox="allow-scripts"
          srcDoc={output}
          className="min-h-80 w-full bg-white"
        />
      </div>
      <figcaption className="border-t border-border px-3 py-2 text-xs text-muted-foreground">
        Edit the code and choose Run. Your changes are not saved.
      </figcaption>
    </figure>
  )
}

// The heading the reader is at: the last one above a line under the header, or the last heading
// once the page is scrolled to the bottom.
function useCurrentHeading(contents: ContentDocHeading[]) {
  const [current, setCurrent] = useState<string>()
  useEffect(() => {
    const update = () => {
      let id = contents[0]?.id
      for (const heading of contents) {
        const element = document.getElementById(heading.id)
        if (element && element.getBoundingClientRect().top < 120) id = heading.id
      }
      if (window.innerHeight + window.scrollY >= document.documentElement.scrollHeight - 4)
        id = contents[contents.length - 1]?.id
      setCurrent(id)
    }
    update()
    window.addEventListener('scroll', update, { passive: true })
    return () => window.removeEventListener('scroll', update)
  }, [contents])
  return current
}

// "On this page": the h2 and h3 headings of a docs body, h3 indented, the current one marked.
export function DocContents({ contents, className }: { contents: ContentDocHeading[]; className?: string }) {
  const current = useCurrentHeading(contents)
  if (contents.length === 0) return null

  return (
    <nav aria-label="On this page" className={cn('flex flex-col gap-3 text-sm', className)}>
      <p className="font-medium">On this page</p>
      <ul className="flex flex-col border-s">
        {contents.map((heading) => (
          <li key={heading.id}>
            <a
              href={`#${heading.id}`}
              aria-current={heading.id === current ? 'location' : undefined}
              className={cn(
                '-ms-px block border-s border-transparent py-1 ps-3 leading-snug text-muted-foreground hover:text-foreground',
                heading.level === 3 && 'ps-6',
                heading.id === current && 'border-foreground font-medium text-foreground',
              )}
            >
              {heading.text}
            </a>
          </li>
        ))}
      </ul>
    </nav>
  )
}

/* ---------------- docs layout ---------------- */

function DocsNavLink({
  href,
  isCurrent,
  onClick,
  className,
  children,
}: {
  href: string
  isCurrent: boolean
  onClick?: () => void
  className?: string
  children: ReactNode
}) {
  return (
    <Link
      href={href}
      onClick={onClick}
      aria-current={isCurrent ? 'page' : undefined}
      className={cn(
        'flex items-center gap-2 rounded-md px-2.5 py-1.5 text-sm text-muted-foreground transition-colors hover:bg-accent hover:text-foreground',
        isCurrent && 'bg-secondary font-medium text-foreground hover:bg-secondary',
        className,
      )}
    >
      {children}
    </Link>
  )
}

// The docs side navigation: the docs index, then each category of config/docs.yml with its pages
// in reading order. `current` is the key of the page shown (null on the index).
export function DocsNav({
  navigation,
  current,
  onNavigate,
}: {
  navigation: ContentDocNavCategory[]
  current: string | null
  onNavigate?: () => void
}) {
  return (
    <nav aria-label="Docs" className="flex flex-col gap-6">
      <DocsNavLink href={docsIndexPage().url} isCurrent={current === null} onClick={onNavigate}>
        <BookOpenIcon className="size-4" />
        All docs
      </DocsNavLink>
      {navigation.map((category) => (
        <div key={category.key} className="flex flex-col gap-0.5">
          <p className="flex items-center gap-2 px-2.5 pb-1 text-[13px] font-medium text-foreground">
            {category.title}
            {category.badge && <Badge variant="warning">{category.badge}</Badge>}
          </p>
          {category.pages.map((page) => (
            <DocsNavLink
              key={page.key}
              href={docsPage(page.key).url}
              isCurrent={page.key === current}
              onClick={onNavigate}
              className={cn(page.depth > 0 && 'ms-3')}
            >
              <span className="min-w-0 truncate">{page.title}</span>
            </DocsNavLink>
          ))}
        </div>
      ))}
    </nav>
  )
}

// The frame of the docs pages: the side navigation (a sheet behind a bar on phones and tablets),
// the page, and its contents list beside it on wide screens.
export function DocsLayout({
  navigation,
  current,
  trail,
  contents = [],
  children,
}: {
  navigation: ContentDocNavCategory[]
  current: string | null
  /** Where the page is, for the phone bar: its category and title. */
  trail: string[]
  contents?: ContentDocHeading[]
  children: ReactNode
}) {
  const [menuOpen, setMenuOpen] = useState(false)
  const closeMenu = useCallback(() => setMenuOpen(false), [])
  useEffect(() => router.on('start', closeMenu), [closeMenu])

  return (
    <>
      <div className="sticky top-16 z-30 border-b bg-background/90 backdrop-blur-md lg:hidden">
        <Container>
          <Dialog open={menuOpen} onOpenChange={setMenuOpen}>
            <DialogTrigger asChild>
              <button
                type="button"
                aria-label="Open the docs menu"
                className="flex h-12 w-full items-center gap-2 text-start text-sm"
              >
                <MenuIcon className="size-4 shrink-0 text-muted-foreground" />
                {['Docs', ...trail].map((part, index, parts) => (
                  <span
                    key={index}
                    className={cn(
                      'min-w-0 truncate',
                      index === parts.length - 1 ? 'font-medium' : 'shrink-0 text-muted-foreground',
                    )}
                  >
                    {index > 0 && <span className="me-2 text-muted-foreground/60">/</span>}
                    {part}
                  </span>
                ))}
                <ChevronDownIcon className="ms-auto size-4 shrink-0 text-muted-foreground" />
              </button>
            </DialogTrigger>
            <DialogContent side="bottom" className="overflow-y-auto bg-background px-5 pt-6 pb-8">
              <DialogTitle className="text-base">Docs</DialogTitle>
              <DialogDescription className="sr-only">The docs pages</DialogDescription>
              <DocsNav navigation={navigation} current={current} onNavigate={closeMenu} />
            </DialogContent>
          </Dialog>
        </Container>
      </div>

      <Container
        className={cn(
          'grid gap-10 lg:grid-cols-[220px_minmax(0,1fr)]',
          contents.length > 0 && 'xl:grid-cols-[220px_minmax(0,1fr)_200px] xl:gap-12',
        )}
      >
        <aside className="sticky top-16 hidden h-[calc(100vh-4rem)] overflow-y-auto py-8 pe-2 lg:block">
          <DocsNav navigation={navigation} current={current} />
        </aside>
        <div className="min-w-0 py-8 lg:py-12">
          {contents.length > 0 && (
            <details className="group mb-8 rounded-lg border px-4 py-3 xl:hidden">
              <summary className="flex cursor-pointer list-none items-center justify-between text-sm font-medium">
                On this page
                <ChevronDownIcon className="size-4 text-muted-foreground transition-transform group-open:rotate-180" />
              </summary>
              <DocContents contents={contents} className="mt-3 [&>p]:hidden" />
            </details>
          )}
          {children}
        </div>
        {contents.length > 0 && (
          <aside className="sticky top-16 hidden h-fit max-h-[calc(100vh-4rem)] overflow-y-auto py-12 xl:block">
            <DocContents contents={contents} />
          </aside>
        )}
      </Container>
    </>
  )
}
