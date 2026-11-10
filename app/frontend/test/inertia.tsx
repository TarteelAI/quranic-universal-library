import type { FlashData, Page } from '@inertiajs/core'
import { App, createInertiaApp } from '@inertiajs/react'
import { act, render } from '@testing-library/react'
import type { ComponentType } from 'react'
import { hydrateRoot } from 'react-dom/client'
import { renderToString } from 'react-dom/server'
import { vi } from 'vitest'

import type { SharedProps } from '@/types/serializers'

import { sharedProps } from './shell'

type PageOptions<P> = {
  props: P
  shared?: Partial<SharedProps>
  url?: string
  flash?: FlashData
}

function pageFor<P extends object>({ props, shared, url = '/', flash = {} }: PageOptions<P>): Page<SharedProps> {
  return {
    component: 'PageUnderTest',
    props: { errors: {}, ...sharedProps, ...shared, ...props },
    url,
    version: null,
    flash,
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

// Renders a page component to HTML as the server does, then hydrates that HTML in the browser
// (jsdom), as the first page load does. Returns what React logged as errors, where it reports
// hydration mismatches.
export async function hydratePage<P extends object>(Component: ComponentType<P>, options: PageOptions<P>) {
  const page = pageFor(options)
  const app = <App initialPage={page} initialComponent={Component} resolveComponent={() => Component} />
  const container = document.createElement('div')
  container.innerHTML = renderToString(app)
  document.body.appendChild(container)

  const errors = vi.spyOn(console, 'error').mockImplementation(() => {})
  const recoverable: unknown[] = []
  const root = await act(async () =>
    hydrateRoot(container, app, { onRecoverableError: (error) => recoverable.push(error) }),
  )
  const logged = [...errors.mock.calls.map((call) => call.map(String).join(' ')), ...recoverable.map(String)]
  errors.mockRestore()

  return { container, logged, unmount: () => act(() => root.unmount()) }
}
