# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require_relative 'config/application'

# vite_ruby adds its build to assets:precompile and, by default, a second `yarn install` with
# NODE_ENV=development (devDependencies: Cypress, Puppeteer). The Dockerfile already installs
# the dependencies Vite needs, so only the build is added.
ENV['VITE_RUBY_SKIP_ASSETS_PRECOMPILE_INSTALL'] ||= 'true'

Rails.application.load_tasks

# Load rake tasks for qul-scripts
Dir.glob(File.expand_path('qul-scripts/**/*.rake', __dir__)).sort.each { |task| load task }
