import inertia from '@inertiajs/vite'
import tailwindcss from '@tailwindcss/vite'
import react from '@vitejs/plugin-react'
import { defineConfig } from 'vite'
import RubyPlugin from 'vite-plugin-ruby'

// The production SSR server (public/vite-ssr/ssr.mjs) listens on the loopback interface only:
// Rails in the same container is its one client.
export default defineConfig({
  plugins: [
    RubyPlugin(),
    inertia({ ssr: { entry: 'entrypoints/inertia.tsx', host: '127.0.0.1' } }),
    react(),
    tailwindcss(),
  ],
})
