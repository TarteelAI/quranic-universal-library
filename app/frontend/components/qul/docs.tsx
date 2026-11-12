import { CheckIcon, CopyIcon, PlayIcon, RotateCcwIcon } from 'lucide-react'
import { type ReactNode, useEffect, useState } from 'react'

import { Button } from '@/components/ui/button'
import { cn } from '@/lib/utils'
import type { ContentDocHeading, ContentDocSegment } from '@/types/serializers'

// A docs body (Content::DocPage): prose HTML the server sanitized, code blocks and runnable examples.
export function DocBody({ segments, className }: { segments: ContentDocSegment[]; className?: string }) {
  return (
    <div className={cn('docs-prose', className)}>
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

// "On this page": the h2 and h3 headings of a docs body, h3 indented.
export function DocContents({ contents, className }: { contents: ContentDocHeading[]; className?: string }) {
  if (contents.length === 0) return null

  return (
    <nav aria-label="On this page" className={cn('flex flex-col gap-2 text-sm', className)}>
      <p className="font-medium">On this page</p>
      <ul className="flex flex-col gap-1.5">
        {contents.map((heading) => (
          <li key={heading.id} className={cn(heading.level === 3 && 'ps-3')}>
            <a href={`#${heading.id}`} className="text-muted-foreground hover:text-foreground">
              {heading.text}
            </a>
          </li>
        ))}
      </ul>
    </nav>
  )
}
