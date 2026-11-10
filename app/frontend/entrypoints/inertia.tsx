import { createInertiaApp } from '@inertiajs/react'
import type { ComponentType } from 'react'

import '../styles/inertia.css'

// Page components without the tests next to them. The production image installs no
// devDependencies, so the build cannot resolve what a test file imports (Vitest, Testing Library).
const pages = import.meta.glob<{ default: ComponentType }>(['../pages/**/*.tsx', '!../pages/**/*.test.tsx'])

void createInertiaApp({
  resolve: async (name) => {
    const page = pages[`../pages/${name}.tsx`]
    if (!page) throw new Error(`Page not found: ${name}`)

    return (await page()).default
  },
  serverHead: true,
  strictMode: true,
})
