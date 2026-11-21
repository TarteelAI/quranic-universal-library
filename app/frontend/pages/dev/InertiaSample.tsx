import { Deferred, router, useHttp, usePage } from '@inertiajs/react'
import {
  destroyUserSession,
  devInertiaSample,
  devInertiaSamples,
  newUserSession,
  pingDevInertiaSample,
  root,
} from '@/routes'
import { fillAuthenticityToken } from '@/lib/csrf'
import type { DevInertiaSamplesShow } from '@/types/serializers'

export default function InertiaSample({ heading, publishedResourceCount }: DevInertiaSamplesShow) {
  const { props, flash } = usePage()
  const ping = useHttp<Record<string, never>, { signedIn: boolean }>('get', pingDevInertiaSample().url, {})
  const signOut = destroyUserSession()

  return (
    <main className="mx-auto max-w-2xl space-y-6 p-6 font-sans text-slate-900">
      <h1 className="text-2xl font-semibold">{heading}</h1>
      <p data-testid="ssr-text">This text comes from a React page. The server renders it first.</p>

      {flash.notice && (
        <p role="status" className="rounded bg-emerald-50 p-3 text-emerald-900">
          {flash.notice}
        </p>
      )}

      <section className="space-y-2">
        <h2 className="text-lg font-medium">Deferred prop</h2>
        <Deferred data="publishedResourceCount" fallback={<p>Loading the resource count.</p>}>
          <p data-testid="resource-count">Published resources: {publishedResourceCount}</p>
        </Deferred>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">Requests</h2>
        <button
          type="button"
          className="rounded bg-slate-900 px-3 py-2 text-white"
          onClick={() => router.post(devInertiaSamples.create())}
        >
          Send a test form
        </button>{' '}
        <button
          type="button"
          className="rounded border border-slate-900 px-3 py-2"
          onClick={() => void ping.get(pingDevInertiaSample().url)}
        >
          Ask for JSON
        </button>
        {ping.response && <p data-testid="ping-result">Signed in: {String(ping.response.signedIn)}</p>}
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">Links</h2>
        <p>
          <a className="underline" href={root().url}>
            Go to the home page
          </a>
        </p>
        {props.auth.user ? (
          <form method="post" action={signOut.url} onSubmit={fillAuthenticityToken}>
            <input type="hidden" name="_method" value={signOut.method} />
            <input type="hidden" name="authenticity_token" />
            <button type="submit" className="underline">
              Sign out
            </button>
          </form>
        ) : (
          <p>
            <a className="underline" href={newUserSession({ query: { user_return_to: devInertiaSample().url } }).url}>
              Sign in
            </a>
          </p>
        )}
      </section>
    </main>
  )
}
