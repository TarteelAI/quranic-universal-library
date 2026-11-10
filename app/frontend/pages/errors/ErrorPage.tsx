import { Container, SiteShell } from '@/components/layout'
import { resources, root } from '@/routes'
import type { ErrorPage as ErrorPageProps } from '@/types/serializers'

// Rendered by InertiaController for a page that does not exist (status 404).
export default function ErrorPage({ status }: ErrorPageProps) {
  return (
    <SiteShell>
      <Container className="flex flex-col gap-4 py-20">
        <p className="font-mono text-sm text-muted-foreground">{`Error ${status}`}</p>
        <h1 className="headline text-3xl sm:text-4xl">Page not found</h1>
        <p className="max-w-xl text-muted-foreground">
          This page does not exist. Check the address, or start again from the resources page.
        </p>
        <p className="flex gap-4 text-sm">
          <a href={resources.index().url} className="underline">
            Go to the resources
          </a>
          <a href={root().url} className="underline">
            Go to the home page
          </a>
        </p>
      </Container>
    </SiteShell>
  )
}
