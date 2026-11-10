import { createInertiaApp } from '@inertiajs/react'

import '../styles/inertia.css'

void createInertiaApp({
  pages: '../pages',
  serverHead: true,
  strictMode: true,
})
