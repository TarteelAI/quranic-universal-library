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
    'tw-docs *'
  ]
};
