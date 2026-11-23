import react from '@vitejs/plugin-react'
import { defineConfig } from 'vitest/config'

// Component tests for app/frontend. Kept apart from vite.config.ts, whose Ruby plugin
// points Vite at the Rails asset pipeline.
export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: { '@/': new URL('./app/frontend/', import.meta.url).pathname },
  },
  test: {
    include: ['app/frontend/**/*.test.{ts,tsx}'],
    environment: 'jsdom',
    setupFiles: ['app/frontend/test/setup.ts'],
  },
})
