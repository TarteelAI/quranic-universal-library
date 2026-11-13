import { ChevronDownIcon, LinkIcon } from 'lucide-react'
import { useEffect } from 'react'

import { Container, SiteShell } from '@/components/layout'
import { PageHeader } from '@/components/qul/page-header'
import type { ContentPagesFaq } from '@/types/serializers'

const ISSUES_URL = 'https://github.com/TarteelAI/quranic-universal-library/issues/new/choose'

// Opens the question the URL's hash names (`#faq-<id>`, the old page's anchors) and scrolls to it.
function openLinkedQuestion() {
  const item = document.getElementById(decodeURIComponent(window.location.hash.slice(1)))
  if (!(item instanceof HTMLDetailsElement)) return
  item.open = true
  item.scrollIntoView({ block: 'start' })
}

// /faq: the published FAQ items (Faq.published) in their order, each a question that opens its
// answer. The answers are editor HTML the server reduced to prose.
export default function FaqPage({ items }: ContentPagesFaq) {
  useEffect(() => {
    openLinkedQuestion()
    window.addEventListener('hashchange', openLinkedQuestion)
    return () => window.removeEventListener('hashchange', openLinkedQuestion)
  }, [])

  return (
    <SiteShell>
      <Container className="max-w-4xl pt-12 pb-16">
        <PageHeader
          title="Frequently asked questions"
          description={
            <>
              Answers to common questions about QUL: what it holds, how to use its resources and how to contribute. If
              your question is not here, open an issue on{' '}
              <a href={ISSUES_URL} className="underline underline-offset-4 hover:text-foreground">
                GitHub
              </a>
              .
            </>
          }
        />

        <div className="mt-10 divide-y border-y">
          {items.map((item) => (
            <details key={item.id} id={`faq-${item.id}`} className="group scroll-mt-24">
              <summary className="flex cursor-pointer list-none items-center gap-3 py-4 text-lg font-medium tracking-tight [&::-webkit-details-marker]:hidden">
                <span className="flex-1">{item.question}</span>
                <ChevronDownIcon
                  aria-hidden
                  className="size-5 shrink-0 text-muted-foreground transition-transform group-open:rotate-180"
                />
              </summary>
              <div className="flex flex-col gap-3 pb-6">
                <div className="docs-prose" dangerouslySetInnerHTML={{ __html: item.answer }} />
                <a
                  href={`#faq-${item.id}`}
                  className="inline-flex w-fit items-center gap-1.5 text-sm text-muted-foreground hover:text-foreground"
                >
                  <LinkIcon aria-hidden className="size-3.5" /> Link to this answer
                </a>
              </div>
            </details>
          ))}
        </div>
      </Container>
    </SiteShell>
  )
}
