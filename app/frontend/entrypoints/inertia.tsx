import { createInertiaApp } from '@inertiajs/react'
import type { ComponentType } from 'react'

import '@fontsource-variable/geist-mono'
import '@fontsource-variable/host-grotesk'
import '@fontsource-variable/noto-naskh-arabic'

import { trackPageViews } from '../lib/analytics'
import { followSystemTheme } from '../lib/theme'
import '../styles/inertia.css'

// Page components without the tests next to them. The production image installs no
// devDependencies, so the build cannot resolve what a test file imports (Vitest, Testing Library).
const pages = import.meta.glob<{ default: ComponentType }>(['../pages/**/*.tsx', '!../pages/**/*.test.tsx'])

// The SSR bundle runs this file too; analytics and the theme belong to the browser only.
if (typeof window !== 'undefined') {
  trackPageViews()
  followSystemTheme()
}

void createInertiaApp({
  resolve: async (name) => {
    const page = pages[`../pages/${name}.tsx`]
    if (!page) throw new Error(`Page not found: ${name}`)

    return (await page()).default
  },
  serverHead: true,
  strictMode: true,
  // A form with a file goes as multipart. Rails reads `app[platforms][]` as an array, but the
  // Inertia default `app[platforms][0]` as a hash.
  defaults: { form: { forceIndicesArrayFormatInFormData: false } },
})
