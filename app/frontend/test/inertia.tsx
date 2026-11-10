import type { Page } from '@inertiajs/core'
import { App, createInertiaApp } from '@inertiajs/react'
import { render } from '@testing-library/react'
import type { ComponentType } from 'react'
import { renderToString } from 'react-dom/server'

import type { SharedProps } from '@/types/serializers'

type PageOptions<P> = {
  props: P
  shared?: Partial<SharedProps>
}

function pageFor<P extends object>({ props, shared }: PageOptions<P>): Page<SharedProps> {
  return {
    component: 'PageUnderTest',
    props: { errors: {}, signedIn: false, ...shared, ...props },
    url: '/',
    version: null,
    flash: {},
    rescuedProps: [],
    rememberedState: {},
  }
}

// Renders a page component inside the Inertia app, as the browser does.
export function renderPage<P extends object>(Component: ComponentType<P>, options: PageOptions<P>) {
  const page = pageFor(options)
  return render(<App initialPage={page} initialComponent={Component} resolveComponent={() => Component} />)
}

// Renders a page component the way the SSR bundle does (see public/vite-ssr after an SSR build).
// Throws when the page reads a browser global (window, document, localStorage) during render.
// Call it from a test file that runs in the node environment.
export async function renderPageOnServer<P extends object>(Component: ComponentType<P>, options: PageOptions<P>) {
  const renderOnServer = await createInertiaApp({ resolve: () => Component })
  if (!renderOnServer) throw new Error('createInertiaApp did not return a server renderer')

  return renderOnServer(pageFor(options), renderToString)
}
