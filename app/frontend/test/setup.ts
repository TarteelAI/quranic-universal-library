import { cleanup } from '@testing-library/react'
import { afterEach } from 'vitest'

afterEach(cleanup)

// jsdom has no ResizeObserver; Radix measures a checkbox inside a <form> with one.
globalThis.ResizeObserver ??= class {
  observe() {}
  unobserve() {}
  disconnect() {}
}

// jsdom has no IntersectionObserver; resource cards load their preview once on screen. This one
// never reports an element on screen (card-preview.test.tsx replaces it to say when).
globalThis.IntersectionObserver ??= class {
  root = null
  rootMargin = ''
  scrollMargin = ''
  thresholds = []
  observe() {}
  unobserve() {}
  disconnect() {}
  takeRecords() {
    return []
  }
}
