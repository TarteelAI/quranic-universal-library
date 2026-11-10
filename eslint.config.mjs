// ESLint for the Inertia pages (app/frontend). The old app/javascript tree is not linted here.
// Browser globals read during render are caught by the SSR render tests (*.ssr.test.tsx).
import js from '@eslint/js'
import reactHooks from 'eslint-plugin-react-hooks'
import globals from 'globals'
import tseslint from 'typescript-eslint'

export default tseslint.config(
  { ignores: ['app/frontend/routes/**', 'app/frontend/types/serializers/**'] },
  {
    files: ['app/frontend/**/*.{ts,tsx}', 'vite.config.mts', 'vitest.config.mts'],
    extends: [js.configs.recommended, ...tseslint.configs.recommended, reactHooks.configs.flat.recommended],
    languageOptions: { globals: globals.browser },
  },
)
