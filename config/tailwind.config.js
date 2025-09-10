const defaultTheme = require('tailwindcss/defaultTheme');

module.exports = {
  prefix: 'tw-',
  content: [
    './public/*.html',
    './app/helpers/**/*.rb',
    './app/javascript/**/*.js',
    './app/views/**/*.{erb,html}',
  ],
  theme: {
    extend: {
      fontFamily: {
        // sans: ['Inter var', ...defaultTheme.fontFamily.sans],
        sarina: ['Sarina', 'cursive'],
        inter: ['Inter', 'sans-serif'],
        title: ['Open Sauce Sans', 'sans-serif'],
      },
    },
  },
  plugins: [
    require('@tailwindcss/forms'),
    require('@tailwindcss/typography'),
    require('@tailwindcss/container-queries'),
  ],
  safelist: [
    'tw-bg-red-100',
    'tw-bg-blue-100',
    'tw-bg-orange-100',
    'tw-bg-green-100',
    'tw-bg-yellow-100',

    'tw-text-red-600',
    'tw-text-blue-600',
    'tw-text-orange-600',
    'tw-text-green-600',
    'tw-text-yellow-600',
    'tw-hidden',
    'tw-link-button',
    'tw-docs',
    'tw-docs *',
    
    // Bootstrap classes for migration
    'btn', 'btn-primary', 'btn-secondary', 'btn-success', 'btn-danger', 'btn-warning', 'btn-info', 'btn-light', 'btn-dark', 'btn-sm', 'btn-lg',
    'alert', 'alert-primary', 'alert-secondary', 'alert-success', 'alert-danger', 'alert-warning', 'alert-info', 'alert-light', 'alert-dark',
    'badge', 'badge-primary', 'badge-secondary', 'badge-success', 'badge-danger', 'badge-warning', 'badge-info', 'badge-light', 'badge-dark',
    'card', 'card-header', 'card-body', 'card-footer', 'card-title', 'card-text',
    'navbar', 'navbar-expand-lg', 'navbar-light', 'navbar-dark', 'navbar-brand', 'navbar-nav', 'nav-item', 'nav-link', 'navbar-toggler', 'navbar-toggler-icon', 'navbar-collapse',
    'dropdown', 'dropdown-toggle', 'dropdown-menu', 'dropdown-item',
    'modal', 'modal-dialog', 'modal-lg', 'modal-content', 'modal-header', 'modal-title', 'modal-body', 'modal-footer', 'modal-backdrop',
    'collapse',
    'container', 'container-fluid', 'row', 'col', 'col-1', 'col-2', 'col-3', 'col-4', 'col-5', 'col-6', 'col-7', 'col-8', 'col-9', 'col-10', 'col-11', 'col-12',
    'd-flex', 'd-inline-flex', 'd-block', 'd-inline-block', 'd-none', 'd-md-none', 'd-md-block', 'd-md-flex', 'd-lg-none', 'd-lg-block', 'd-lg-flex',
    'justify-content-start', 'justify-content-end', 'justify-content-center', 'justify-content-between', 'justify-content-around',
    'align-items-start', 'align-items-end', 'align-items-center', 'align-items-baseline', 'align-items-stretch',
    'flex-column', 'flex-row', 'flex-wrap', 'flex-nowrap',
    'me-auto', 'mb-2', 'mb-lg-0', 'mt-3', 'mb-3', 'p-3', 'p-4', 'px-3', 'py-2',
    'text-center', 'text-start', 'text-end', 'text-muted', 'text-primary', 'text-success', 'text-danger', 'text-warning', 'text-info',
    'form-control', 'form-label', 'form-floating',
    'w-100', 'h-100', 'rounded', 'shadow', 'shadow-sm', 'border', 'border-top', 'border-bottom',
    'bg-light', 'bg-white'
  ]
};
