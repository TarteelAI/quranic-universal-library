import type { FormEvent } from 'react'

// Plain form posts to Rails (sign-out) carry the token from the layout's csrf-token meta tag. It
// is read on submit, because the server render has no document to read it from.
export function fillAuthenticityToken(event: FormEvent<HTMLFormElement>) {
  const token = document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content ?? ''
  const input = event.currentTarget.elements.namedItem('authenticity_token')
  if (input instanceof HTMLInputElement) input.value = token
}
